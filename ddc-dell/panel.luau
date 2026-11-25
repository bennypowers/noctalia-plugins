--!nonstrict
-- Control panel: brightness/contrast/volume sliders, mute, colour preset,
-- display mode, input source, and the Dell-specific PIP/PBP section
-- (layout, sub-window input, video swap, experimental KVM USB switch).
-- Every choice is a settings-style row: label + helper on the left, the
-- control on the right. All writes go through the bundled ddc-dell backend,
-- which serializes the DDC traffic.

local model = require("./lib/model.luau")

local monitor = noctalia.getConfig("monitor") or ""
local kvmEnabled = noctalia.getConfig("kvmSwitch") ~= false

local backend = noctalia.pluginDir() and noctalia.pluginDir() .. "/ddc-dell" or nil

local state = nil -- latest monitor state (from the service or a refresh)
local pendingInput = nil -- input value awaiting the confirm step
local pendingSliders = {} -- key -> value while a slider drag is in flight
local busy = false
local monitorName = nil -- full DDC model name for the title (loaded async)

local function run(args, cb)
  if not backend then
    if cb then
      cb({ exitCode = 1, stdout = "", stderr = "backend script not found" })
    end
    return
  end
  local argv = { "sh", backend }
  if monitor ~= "" then
    argv[#argv + 1] = "--model"
    argv[#argv + 1] = monitor
  end
  for _, arg in ipairs(args) do
    argv[#argv + 1] = arg
  end
  if not noctalia.runAsync(argv, cb) and cb then
    cb({ exitCode = 1, stdout = "", stderr = "failed to launch backend" })
  end
end

local function onWriteFail(result, actionLabel)
  if result.exitCode == 0 then
    return nil
  end
  local detail = (result.stderr or ""):match("[^\n]+") or noctalia.tr("panel.write_failed_detail")
  noctalia.notifyError(actionLabel, detail)
  return detail
end

-- Re-reads the monitor after a write so the panel tracks what the firmware
-- actually applied (e.g. a video swap exchanges the main and sub inputs).
-- Failures are silent: the service poll corrects the state shortly.
local function refresh()
  run({ "state" }, function(result)
    if result.exitCode == 0 then
      local fresh = model.buildState(model.parseGetvcp(result.stdout))
      -- buildState has no kvm/swapped keys (neither reports state); keep
      -- the plugin-tracked positions across re-reads.
      fresh.kvm = state and state.kvm
      fresh.swapped = state and state.swapped
      state = fresh
      busy = false
      render()
    else
      busy = false
    end
  end)
end

local function write(code, value, label, thenRefresh)
  busy = true
  run({ "set", code, tostring(value) }, function(result)
    if onWriteFail(result, label) then
      busy = false
      render()
      return
    end
    if thenRefresh ~= false then
      refresh()
    else
      busy = false
    end
  end)
end

local function doAction(name, label, thenRefresh)
  busy = true
  run({ "action", name }, function(result)
    if onWriteFail(result, label) then
      busy = false
      render()
      return
    end
    if thenRefresh ~= false then
      refresh()
    else
      busy = false
    end
  end)
end

-- Loads the monitor's full DDC model name for the title (the `monitor`
-- setting is only a matching substring). Silent: the title keeps the
-- translated plugin name until this lands; failures keep the last name.
local function loadMonitorName()
  if not backend then
    return
  end
  run({ "model" }, function(result)
    if result.exitCode == 0 then
      local name = (result.stdout or ""):match("^([^\r\n]+)")
      if name and name ~= "" then
        monitorName = name
        render()
      end
    end
  end)
end

-- Chip grids for the PIP/PBP layouts: the OSD offers a whole family of
-- modes and the user should see them all at once. `columns` defaults to 2;
-- pass #options for a single row (the six PBP chips). The grid takes the
-- wider share of its settings row.
local function chipGrid(options, current, onPick, columns)
  local cols = columns or 2
  local rows = {}
  for first = 1, #options, cols do
    local cells = {}
    local last = math.min(first + cols - 1, #options)
    for index = first, last do
      local option = options[index]
      local props = {
        key = "pbp-" .. string.format("%02X", option.value),
        text = option.label,
        variant = "default",
        controlSize = "sm",
        flexGrow = 1,
        selected = current == option.value,
        enabled = not busy,
        tooltip = option.tooltip,
        onClick = (function(value)
          return function()
            onPick(value)
          end
        end)(option.value),
      }
      if option.glyph then
        props.glyph = option.glyph
      end
      cells[#cells + 1] = ui.button(props)
    end
    rows[#rows + 1] = ui.row({ gap = 6, justify = "start" }, cells)
  end
  return ui.column({ gap = 6, flexGrow = 2 }, rows)
end

local function labelsOf(options)
  local out = {}
  for index, option in ipairs(options) do
    out[index] = option.label
  end
  return out
end

-- Settings-style select row: label + helper on the left, the select on
-- the right. ui.select reports a 0-based index string.
local function selectSettingRow(key, label, help, options, value, onSelect, enabled)
  return ui.row({ justify = "space_between", align = "start", gap = 12 }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = label, fontSize = 14, fontWeight = "bold" }),
      ui.label({ text = help, fontSize = 12, color = "on_surface_variant" }),
    }),
    ui.select({
      key = "select-" .. key,
      options = labelsOf(options),
      selectedIndex = model.indexFor(options, value) or 0,
      width = 160,
      enabled = not busy and enabled ~= false,
      onChange = function(indexStr)
        local option = options[tonumber(indexStr) + 1]
        if option then
          onSelect(option.value)
        end
      end,
    }),
  })
end

-- Builds the whole panel top-to-bottom in visual order; every row is
-- written inline so a change to one row stays a local diff.
function render()
  local title = monitorName or noctalia.tr("panel.title")
  if not backend or not state or not state.ok then
    local text
    if not backend then
      text = noctalia.tr("panel.no_backend")
    elseif state and state.reason == "ddcutil" then
      text = noctalia.tr("panel.no_ddcutil")
    else
      text = noctalia.tr("panel.no_monitor")
    end
    panel.render(ui.column({ gap = 10 }, {
      ui.row({ align = "center", justify = "space_between" }, {
        ui.label({ text = title, fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
        ui.button({ glyph = "x", variant = "ghost", onClick = function()
          panel.close()
        end }),
      }),
      ui.label({ text = text, fontSize = 14, color = "on_surface_variant" }),
    }))
    return
  end

  local s = state
  local children = {}

  -- Header
  children[#children + 1] = ui.row({ align = "center", justify = "space_between" }, {
    ui.label({ text = title, fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
    ui.button({ glyph = "x", variant = "ghost", onClick = function()
      panel.close()
    end }),
  })

  -- Active input subtitle
  children[#children + 1] = ui.label({
    text = string.format("%s · %s", noctalia.tr("panel.input_short"), model.labelFor(model.inputs, s.input))
        .. (s.pbp > 0 and " · " .. noctalia.tr("panel.pip_pbp_on") or ""),
    fontSize = 12,
    color = "on_surface_variant",
  })

  children[#children + 1] = ui.separator({})

  -- Brightness
  if s.brightness >= 0 then
    children[#children + 1] = ui.row({ justify = "space_between", align = "center", gap = 12 }, {
      ui.column({ gap = 2 }, {
        ui.label({ text = noctalia.tr("panel.brightness"), fontSize = 14, fontWeight = "bold" }),
        ui.label({
          key = "value-brightness",
          text = string.format("%d%%", s.brightness),
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
      ui.slider({
        key = "slider-brightness",
        min = 0,
        max = 100,
        step = 1,
        value = s.brightness,
        flexGrow = 1,
        onChange = function(raw)
          pendingSliders.brightness = model.clampPercent(raw)
        end,
        onDragEnd = function()
          local v = pendingSliders.brightness
          pendingSliders.brightness = nil
          if v == nil or s.brightness == v then
            return
          end
          s.brightness = v
          render()
          write("10", v, noctalia.tr("panel.write_failed"))
        end,
      }),
    })
  end

  -- Contrast
  if s.contrast >= 0 then
    children[#children + 1] = ui.row({ justify = "space_between", align = "center", gap = 12 }, {
      ui.column({ gap = 2 }, {
        ui.label({ text = noctalia.tr("panel.contrast"), fontSize = 14, fontWeight = "bold" }),
        ui.label({
          key = "value-contrast",
          text = string.format("%d%%", s.contrast),
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
      ui.slider({
        key = "slider-contrast",
        min = 0,
        max = 100,
        step = 1,
        value = s.contrast,
        flexGrow = 1,
        onChange = function(raw)
          pendingSliders.contrast = model.clampPercent(raw)
        end,
        onDragEnd = function()
          local v = pendingSliders.contrast
          pendingSliders.contrast = nil
          if v == nil or s.contrast == v then
            return
          end
          s.contrast = v
          render()
          write("12", v, noctalia.tr("panel.write_failed"))
        end,
      }),
    })
  end

  -- Volume; the mute switch rides at the end of the row (a standalone row
  -- only if the monitor reports mute but no volume slider)
  if s.volume >= 0 or s.mute >= 0 then
    local cells = {
      ui.column({ gap = 2 }, {
        ui.label({
          text = s.volume >= 0 and noctalia.tr("panel.volume") or noctalia.tr("panel.mute"),
          fontSize = 14,
          fontWeight = "bold",
        }),
        ui.label({
          key = "value-volume",
          text = s.volume >= 0 and string.format("%d%%", s.volume) or noctalia.tr("panel.mute_help"),
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
    }
    if s.volume >= 0 then
      cells[#cells + 1] = ui.slider({
        key = "slider-volume",
        min = 0,
        max = 100,
        step = 1,
        value = s.volume,
        flexGrow = 1,
        onChange = function(raw)
          pendingSliders.volume = model.clampPercent(raw)
        end,
        onDragEnd = function()
          local v = pendingSliders.volume
          pendingSliders.volume = nil
          if v == nil or s.volume == v then
            return
          end
          s.volume = v
          render()
          write("62", v, noctalia.tr("panel.write_failed"))
        end,
      })
    end
    if s.mute >= 0 then
      cells[#cells + 1] = ui.toggle({
        key = "toggle-mute",
        checked = s.mute == 1,
        enabled = not busy,
        tooltip = noctalia.tr("panel.mute_help"),
        onChange = function(value)
          local muted = value == "true"
          if (s.mute == 1) == muted then
            return
          end
          s.mute = muted and 1 or 0
          render()
          write("8D", s.mute, noctalia.tr("panel.mute"))
        end,
      })
    end
    children[#children + 1] = ui.row({ justify = "space_between", align = "center", gap = 12 }, cells)
  end

  children[#children + 1] = ui.separator({})

  -- Colour preset
  if s.preset >= 0 then
    children[#children + 1] = selectSettingRow("preset", noctalia.tr("panel.preset"), noctalia.tr("panel.preset_help"), model.presets, s.preset, function(value)
      if value == s.preset then
        return
      end
      s.preset = value
      render()
      write("14", value, noctalia.tr("panel.preset"))
    end)
  end

  -- Display mode
  if s.mode >= 0 then
    children[#children + 1] = selectSettingRow("mode", noctalia.tr("panel.mode"), noctalia.tr("panel.mode_help"), model.modes, s.mode, function(value)
      if value == s.mode then
        return
      end
      s.mode = value
      render()
      write("DC", value, noctalia.tr("panel.mode"))
    end)
  end

  -- Input source (switching away from the current input asks for a confirm
  -- first — it blanks the screen)
  if s.input >= 0 then
    -- The select row stays visible while a switch is pending (it still
    -- shows the active input); the confirm block appears beneath it.
    children[#children + 1] = selectSettingRow("input", noctalia.tr("panel.input"), noctalia.tr("panel.input_help"), model.inputs, s.input, function(value)
      if value == s.input then
        return
      end
      pendingInput = value
      render()
    end)
    if pendingInput ~= nil then
      children[#children + 1] = ui.column({
        gap = 6,
        fill = "surface_variant/0.5",
        radius = 8,
        padding = 10,
      }, {
        ui.label({
          text = noctalia.tr("panel.input_confirm", { label = model.labelFor(model.inputs, pendingInput) }),
          fontSize = 13,
        }),
        ui.row({ gap = 8, justify = "end" }, {
          ui.button({
            text = noctalia.tr("panel.cancel"),
            variant = "ghost",
            controlSize = "sm",
            onClick = function()
              pendingInput = nil
              render()
            end,
          }),
          ui.button({
            text = noctalia.tr("panel.confirm"),
            variant = "primary",
            controlSize = "sm",
            onClick = function()
              local value = pendingInput
              pendingInput = nil
              s.input = value
              render()
              write("60", value, noctalia.tr("panel.input"))
            end,
          }),
        }),
      })
    end
  end

  children[#children + 1] = ui.separator({})

  -- No on/off toggle in the header: Off is a chip in the PBP row, so the
  -- whole section is driven by the chip grids and the sub-controls below.
  children[#children + 1] = ui.label({
    text = noctalia.tr("panel.pip_pbp"),
    fontSize = 14,
    fontWeight = "bold",
  })

  -- Layout pick shared by the two grids: layout changes re-hotplug the
  -- monitor and drop DDC briefly, so no immediate re-read; the poll
  -- recovers it.
  local function pickLayout(value)
    if value == s.pbp then
      return
    end
    s.pbp = value
    pendingInput = nil
    render()
    write("E9", value, noctalia.tr("panel.write_failed"), false)
  end

  -- Picture-By-Picture layout (six chips across in a single row)
  children[#children + 1] = ui.row({ justify = "space_between", align = "start", gap = 12 }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = noctalia.tr("panel.pbp_title"), fontSize = 14, fontWeight = "bold" }),
      ui.label({ text = noctalia.tr("panel.pbp_help"), fontSize = 12, color = "on_surface_variant" }),
    }),
    chipGrid(model.pbpOptions, s.pbp, pickLayout, #model.pbpOptions),
  })

  -- Picture-In-Picture position (2x2)
  children[#children + 1] = ui.row({ justify = "space_between", align = "start", gap = 12 }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = noctalia.tr("panel.pip_title"), fontSize = 14, fontWeight = "bold" }),
      ui.label({ text = noctalia.tr("panel.pip_help"), fontSize = 12, color = "on_surface_variant" }),
    }),
    chipGrid(model.pipPositions, s.pbp, pickLayout),
  })

  -- The sub-controls are always shown but disabled while PIP/PBP is off
  -- (they only apply to an active layout); the note below explains which
  -- state the section is in.
  local pbpEnabled = s.pbp > 0 and not busy

  -- Sub-window input
  children[#children + 1] = selectSettingRow("pbp-input", noctalia.tr("panel.sub_input"), noctalia.tr("panel.sub_input_help"), model.inputs, s.pbpInput, function(value)
    if value == s.pbpInput then
      return
    end
    s.pbpInput = value
    render()
    write("E8", value, noctalia.tr("panel.write_failed"))
  end, s.pbp > 0)

  -- Video swap: the crossed-or-not state is real but no VCP reports it, so
  -- like the KVM switch the plugin tracks the position in shared state and
  -- the switch reflects the last swap made here.
  children[#children + 1] = ui.row({ justify = "space_between", align = "center", gap = 12 }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = noctalia.tr("panel.video_swap"), fontSize = 14, fontWeight = "bold" }),
      ui.label({ text = noctalia.tr("panel.video_swap_help"), fontSize = 12, color = "on_surface_variant" }),
    }),
    ui.toggle({
      key = "toggle-swap",
      checked = s.swapped == true,
      enabled = pbpEnabled,
      tooltip = noctalia.tr("panel.video_swap_tooltip"),
      onChange = function(value)
        local swapped = value == "true"
        if (s.swapped == true) == swapped then
          return
        end
        s.swapped = swapped
        render()
        -- Publish the tracked position so the service's next poll carries
        -- it forward (it is not part of the monitor read).
        noctalia.state.set("ddc", s)
        doAction("swap", noctalia.tr("panel.video_swap"))
      end,
    }),
  })

  if kvmEnabled then
    -- The E7 register reports no state, so the label shows the output the
    -- plugin last set (Unknown before the first flip); the service carries
    -- the tracked position through its polls.
    local output = s.kvm == nil and noctalia.tr("panel.kvm_unknown") or model.kvmOutputs[s.kvm + 1]
    children[#children + 1] = ui.row({ justify = "space_between", align = "center", gap = 12 }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = noctalia.tr("panel.kvm_switch"), fontSize = 14, fontWeight = "bold" }),
        ui.label({
          text = noctalia.tr("panel.kvm_switch_help", { output = output }),
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
      ui.toggle({
        key = "toggle-kvm",
        checked = s.kvm == 1,
        enabled = pbpEnabled,
        tooltip = noctalia.tr("panel.kvm_tooltip"),
        onChange = function(value)
          local on = value == "true"
          if (s.kvm == 1) == on then
            return
          end
          s.kvm = on and 1 or 0
          render()
          -- Publish the tracked position so the service's next poll carries
          -- it forward (it is not part of the monitor read).
          noctalia.state.set("ddc", s)
          doAction("kvm", noctalia.tr("panel.kvm_switch"))
        end,
      }),
    })
  end

  panel.render(ui.scroll({ gap = 10, padding = 16 }, children))
end

-- A poll fails for a few seconds around a PBP transition (the monitor drops
-- DDC while it reconfigures). Keep the last good state so the panel does not
-- flash into its error view; only an entry that never had data shows the error.
noctalia.state.watch("ddc", function(value)
  if value and value.ok then
    state = value
    pendingInput = nil
  elseif state == nil then
    state = value
  end
  render()
end)

loadMonitorName()

function onOpen()
  local value = noctalia.state.get("ddc")
  if value and value.ok then
    state = value
  elseif state == nil then
    state = value
  end
  pendingInput = nil
  loadMonitorName()
  render()
end

function onClose()
  pendingSliders = {}
end

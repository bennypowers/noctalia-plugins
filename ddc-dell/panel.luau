--!nonstrict
-- Control panel: brightness/contrast/volume, mute, colour preset, display
-- mode, input source, and the Dell-specific PIP/PBP section (layout,
-- sub-window input, video swap, experimental KVM USB switch). All writes go
-- through the bundled ddc-dell backend, which serializes the DDC traffic.

local model = require("./lib/model.luau")

local monitor = noctalia.getConfig("monitor") or ""
local kvmEnabled = noctalia.getConfig("kvmSwitch") ~= false

local backend = noctalia.pluginDir() and noctalia.pluginDir() .. "/ddc-dell" or nil

local state = nil -- latest monitor state (from the service or a refresh)
local pendingInput = nil -- input value awaiting the confirm step
local pendingSliders = {} -- key -> value while a slider drag is in flight
local busy = false

-- Forward declaration: control callbacks defined below call back into the
-- current tree once the user commits a change.
local render

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
      state = model.buildState(model.parseGetvcp(result.stdout))
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

local function labelsOf(options)
  local out = {}
  for index, option in ipairs(options) do
    out[index] = option.label
  end
  return out
end

local function sliderRow(key, code, label, value)
  local row = {}
  row[1] = ui.row({ justify = "space_between", align = "center", gap = 8 }, {
    ui.label({ text = label, fontSize = 13 }),
    ui.label({
      key = "value-" .. key,
      text = string.format("%d%%", value),
      fontSize = 13,
      color = "on_surface_variant",
    }),
  })
  row[2] = ui.slider({
    key = "slider-" .. key,
    min = 0,
    max = 100,
    step = 1,
    value = value,
    onChange = function(raw)
      pendingSliders[key] = model.clampPercent(raw)
    end,
    onDragEnd = function()
      local v = pendingSliders[key]
      pendingSliders[key] = nil
      if v == nil or state[key] == v then
        return
      end
      state[key] = v
      render()
      write(code, v, noctalia.tr("panel.write_failed"))
    end,
  })
  return row
end

local function selectRow(key, label, options, value, onSelect)
  local index = model.indexFor(options, value)
  return ui.row({ justify = "space_between", align = "center", gap = 8 }, {
    ui.label({ text = label, fontSize = 13, width = 104 }),
    ui.select({
      key = "select-" .. key,
      options = labelsOf(options),
      selectedIndex = index or 0,
      flexGrow = 1,
      enabled = not busy,
      onChange = function(indexStr)
        local option = options[tonumber(indexStr) + 1]
        if option then
          onSelect(option.value)
        end
      end,
    }),
  })
end

local function header()
  return ui.row({ align = "center", justify = "space_between" }, {
    ui.label({
      text = noctalia.tr("panel.title"),
      fontSize = 18,
      fontWeight = "bold",
      flexGrow = 1,
    }),
    ui.button({ glyph = "x", variant = "ghost", onClick = function()
      panel.close()
    end }),
  })
end

local function errorBlock()
  local text
  if not backend then
    text = noctalia.tr("panel.no_backend")
  elseif state and state.reason == "ddcutil" then
    text = noctalia.tr("panel.no_ddcutil")
  else
    text = noctalia.tr("panel.no_monitor")
  end
  return ui.column({ gap = 10 }, {
    header(),
    ui.label({ text = text, fontSize = 14, color = "on_surface_variant" }),
  })
end

-- The layouts are chip grids rather than selects: the OSD offers a whole
-- family of PIP/PBP modes and the user should see them all at once.
local function chipGrid(options, current, onPick)
  local COLUMNS = 2
  local rows = {}
  for first = 1, #options, COLUMNS do
    local cells = {}
    local last = math.min(first + COLUMNS - 1, #options)
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
  return ui.column({ gap = 6 }, rows)
end

-- A layout card styled after the control center's device volume cards
-- (surface_container fill, 12px radius, 12px padding, 8px gap):
-- title row plus the group's chip grid.
local function layoutCard(title, options, current, onPick)
  return ui.column({
    fill = "surface_container",
    radius = 12,
    padding = 12,
    gap = 8,
    flexGrow = 1,
  }, {
    ui.label({ text = title, fontSize = 14, fontWeight = "bold" }),
    chipGrid(options, current, onPick),
  })
end

local function pickLayout(s, value)
  if value == s.pbp then
    return
  end
  s.pbp = value
  pendingInput = nil
  render()
  -- Layout changes re-hotplug the monitor and drop DDC briefly;
  -- the poll recovers it.
  write("E9", value, noctalia.tr("panel.write_failed"), false)
end

local function pipPbpSection(s)
  local active = s.pbp > 0
  local children = {}

  children[#children + 1] = ui.row({ align = "center", justify = "space_between" }, {
    ui.label({
      text = noctalia.tr("panel.pip_pbp"),
      fontSize = 14,
      fontWeight = "bold",
      flexGrow = 1,
    }),
    ui.toggle({
      key = "toggle-pip",
      checked = active,
      enabled = not busy,
      tooltip = noctalia.tr("panel.pip_switch_tooltip"),
      onChange = function(value)
        local on = value == "true"
        if on == active then
          return
        end
        pickLayout(s, on and model.PBP_DEFAULT or model.PBP_OFF)
      end,
    }),
  })

  -- Two side-by-side cards, like the volume panel's output/input cards.
  children[#children + 1] = ui.row({ align = "stretch", gap = 12 }, {
    layoutCard(noctalia.tr("panel.pbp_title"), model.pbpRatios, s.pbp, function(value)
      pickLayout(s, value)
    end),
    layoutCard(noctalia.tr("panel.pip_title"), model.pipPositions, s.pbp, function(value)
      pickLayout(s, value)
    end),
  })

  if s.pbp > 0 then
    children[#children + 1] = selectRow("pbp-input", noctalia.tr("panel.sub_input"), model.inputs, s.pbpInput, function(value)
      if value == s.pbpInput then
        return
      end
      s.pbpInput = value
      render()
      write("E8", value, noctalia.tr("panel.write_failed"))
    end)

    local buttons = {
      ui.button({
        glyph = "arrows-exchange",
        text = noctalia.tr("panel.video_swap"),
        variant = "secondary",
        controlSize = "sm",
        enabled = not busy,
        onClick = function()
          doAction("swap", noctalia.tr("panel.video_swap"))
        end,
      }),
    }
    if kvmEnabled then
      buttons[#buttons + 1] = ui.button({
        glyph = "usb",
        text = noctalia.tr("panel.kvm_switch"),
        variant = "secondary",
        controlSize = "sm",
        tooltip = noctalia.tr("panel.kvm_tooltip"),
        enabled = not busy,
        onClick = function()
          doAction("kvm", noctalia.tr("panel.kvm_switch"))
        end,
      })
    end
    children[#children + 1] = ui.row({ gap = 8, justify = "center" }, buttons)
    children[#children + 1] = ui.label({
      text = noctalia.tr("panel.pbp_note"),
      fontSize = 11,
      color = "on_surface_variant",
    })
  else
    children[#children + 1] = ui.label({
      text = noctalia.tr("panel.pbp_off_note"),
      fontSize = 11,
      color = "on_surface_variant",
    })
  end

  return children
end

function render()
  if not backend or not state or not state.ok then
    panel.render(errorBlock())
    return
  end

  local s = state
  local children = {}
  children[#children + 1] = header()

  children[#children + 1] = ui.label({
    text = string.format("%s · %s", noctalia.tr("panel.input_short"), model.labelFor(model.inputs, s.input))
        .. (s.pbp > 0 and " · " .. noctalia.tr("panel.pip_pbp_on") or ""),
    fontSize = 12,
    color = "on_surface_variant",
  })

  children[#children + 1] = ui.separator({})

  for _, spec in ipairs({
    { key = "brightness", code = "10", label = noctalia.tr("panel.brightness") },
    { key = "contrast", code = "12", label = noctalia.tr("panel.contrast") },
    { key = "volume", code = "62", label = noctalia.tr("panel.volume") },
  }) do
    if s[spec.key] >= 0 then
      for _, node in ipairs(sliderRow(spec.key, spec.code, spec.label, s[spec.key])) do
        children[#children + 1] = node
      end
    end
  end

  if s.mute >= 0 then
    children[#children + 1] = ui.row({ justify = "space_between", align = "center" }, {
      ui.label({ text = noctalia.tr("panel.mute"), fontSize = 13 }),
      ui.toggle({
        key = "toggle-mute",
        checked = s.mute == 1,
        enabled = not busy,
        onChange = function(value)
          local muted = value == "true"
          if (s.mute == 1) == muted then
            return
          end
          s.mute = muted and 1 or 0
          render()
          write("8D", s.mute, noctalia.tr("panel.mute"))
        end,
      }),
    })
  end

  children[#children + 1] = ui.separator({})

  if s.preset >= 0 then
    children[#children + 1] = selectRow("preset", noctalia.tr("panel.preset"), model.presets, s.preset, function(value)
      if value == s.preset then
        return
      end
      s.preset = value
      render()
      write("14", value, noctalia.tr("panel.preset"))
    end)
  end
  if s.mode >= 0 then
    children[#children + 1] = selectRow("mode", noctalia.tr("panel.mode"), model.modes, s.mode, function(value)
      if value == s.mode then
        return
      end
      s.mode = value
      render()
      write("DC", value, noctalia.tr("panel.mode"))
    end)
  end

  if s.input >= 0 then
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
    else
      children[#children + 1] = selectRow("input", noctalia.tr("panel.input"), model.inputs, s.input, function(value)
        if value == s.input then
          return
        end
        pendingInput = value
        render()
      end)
    end
  end

  children[#children + 1] = ui.separator({})

  for _, node in ipairs(pipPbpSection(s)) do
    children[#children + 1] = node
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

function onOpen()
  local value = noctalia.state.get("ddc")
  if value and value.ok then
    state = value
  elseif state == nil then
    state = value
  end
  pendingInput = nil
  render()
end

function onClose()
  pendingSliders = {}
end

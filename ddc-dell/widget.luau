--!nonstrict
-- Bar widget: monitor glyph with the current brightness; scroll adjusts
-- brightness; click opens the control panel.

local model = require("./lib/model.luau")

local PLUGIN = "bennypowers/ddc-dell"
local SCROLL_STEP = 5 -- percent per wheel detent

local monitor = noctalia.getConfig("monitor") or ""
local backend = noctalia.pluginDir() and noctalia.pluginDir() .. "/ddc-dell" or nil

-- Optimistic brightness while a write is in flight; the service's next poll
-- reconciles the shared state. A coalesced target absorbs wheel bursts so a
-- fast flick issues one write per completed write, not one per notch.
local brightnessOverride = nil
local pendingTarget = nil
local writing = false

local function render(state)
  if not state or not state.ok then
    barWidget.setVisible(false)
    return
  end

  local brightness = brightnessOverride or state.brightness
  barWidget.setGlyph("device-tv")
  barWidget.setText(brightness >= 0 and brightness .. "%" or "")
  barWidget.setVisible(true)

  local lines = {
    "DDC/CI " .. model.labelFor(model.inputs, state.input),
  }
  if state.pbp >= 0 then
    table.insert(lines, model.labelFor(model.pbpLayouts, state.pbp) == "Off" and "PIP/PBP off" or "PIP/PBP: " .. model.labelFor(model.pbpLayouts, state.pbp))
  end
  if state.pbp > 0 and state.pbpInput >= 0 then
    table.insert(lines, "Sub: " .. model.labelFor(model.inputs, state.pbpInput))
  end
  table.insert(lines, "Scroll to adjust brightness")
  table.insert(lines, "Click to open display controls")
  barWidget.setTooltip(lines)
end

local function writeBrightness(value)
  if not backend then
    return
  end
  writing = true
  local args = { "sh", backend }
  if monitor ~= "" then
    args[#args + 1] = "--model"
    args[#args + 1] = monitor
  end
  args[#args + 1] = "set"
  args[#args + 1] = "10"
  args[#args + 1] = tostring(value)
  local accepted = noctalia.runAsync(args, function(result)
    writing = false
    if result.exitCode == 0 then
      brightnessOverride = value
      local state = noctalia.state.get("ddc")
      if state and state.ok then
        render(state)
      end
    end
    -- Drain a coalesced follow-up step, if the wheel moved meanwhile.
    if pendingTarget ~= nil then
      local nextValue = pendingTarget
      pendingTarget = nil
      writeBrightness(nextValue)
    end
  end)
  if not accepted then
    writing = false
    pendingTarget = nil
  end
end

render(noctalia.state.get("ddc"))

noctalia.state.watch("ddc", function(state)
  -- A fresh poll is authoritative unless a write of our own is still in
  -- flight (the monitor applies VCP writes asynchronously).
  if not writing then
    brightnessOverride = nil
  end
  render(state)
end)

function onScroll(axis, steps)
  if axis ~= "vertical" then
    return
  end
  local state = noctalia.state.get("ddc")
  if not state or not state.ok or state.brightness < 0 then
    return
  end
  local base = pendingTarget or brightnessOverride or state.brightness
  local value = model.clampPercent(base - steps * SCROLL_STEP)
  if value == base then
    return
  end
  pendingTarget = value
  if not writing then
    pendingTarget = nil
    writeBrightness(value)
  end
end

function onClick()
  noctalia.togglePanel(PLUGIN .. ":control")
end

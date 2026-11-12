--!nonstrict
-- Bar widget: monitor glyph with the current brightness; click opens the
-- control panel.

local model = require("./lib/model.luau")

local PLUGIN = "bennypowers/ddc-dell"

local function render(state)
  if not state or not state.ok then
    barWidget.setVisible(false)
    return
  end

  barWidget.setGlyph("device-tv")
  barWidget.setText(state.brightness >= 0 and state.brightness .. "%" or "")
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
  table.insert(lines, "Click to open display controls")
  barWidget.setTooltip(lines)
end

render(noctalia.state.get("ddc"))

noctalia.state.watch("ddc", function(state)
  render(state)
end)

function onClick()
  noctalia.togglePanel(PLUGIN .. ":control")
end

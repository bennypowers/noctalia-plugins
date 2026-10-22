--!nonstrict
-- Per-core CPU load bars, drawn as the built-in sysmon gauge: thin rounded
-- stems with a dimmed track and a foreground-to-highlight gradient.

local color = require("./lib/color.luau")

local updateInterval = noctalia.getConfig("updateInterval") or 2000
local highlightRole = noctalia.getConfig("highlightColor") or "error"

local activityThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_activity_threshold")) or 50
local criticalThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_critical_threshold")) or 90

local STEM_WIDTH = 4
local STEM_HEIGHT = 17
local STEM_GAP = 4
local STEM_RADIUS = 2

local function palette()
  local base = noctalia.getColor("on_surface")
  if not base then
    base = noctalia.isDarkMode() and "#ffffff" or "#000000"
  end
  local highlight = noctalia.getColor(highlightRole) or noctalia.getColor("error") or "#ff0000"
  return color.parseHex(base), color.parseHex(highlight)
end

local function coreFill(usage, base, highlight)
  return color.formatHex(
    color.blend(base, highlight, color.gradientFactor(usage, activityThreshold, criticalThreshold))
  )
end

local function stem(index, usage, fill, track, vertical)
  local extent = STEM_HEIGHT * usage / 100
  if extent < 1 then extent = 0 end

  local child = {}
  if extent > 0 then
    if vertical then
      child = { ui.box({ width = extent, height = STEM_WIDTH, fill = fill, radius = STEM_RADIUS }) }
    else
      child = { ui.box({ width = STEM_WIDTH, height = extent, fill = fill, radius = STEM_RADIUS }) }
    end
  end

  local props = {
    key = "core-" .. index,
    fill = track,
    radius = STEM_RADIUS,
    align = "stretch",
    tooltip = string.format("Core %d\n%d%%", index, math.floor(usage + 0.5)),
  }

  if vertical then
    props.width = STEM_HEIGHT
    props.height = STEM_WIDTH
    props.justify = "start"
    return ui.row(props, child)
  end

  props.width = STEM_WIDTH
  props.height = STEM_HEIGHT
  props.justify = "end"
  return ui.column(props, child)
end

local function render(cores)
  if not cores or #cores == 0 then
    barWidget.setVisible(false)
    return
  end

  local base, highlight = palette()
  if not (base and highlight) then
    barWidget.setVisible(false)
    return
  end

  local vertical = barWidget.isVertical()
  local children = {}

  for index, raw in ipairs(cores) do
    local usage = math.max(0, math.min(100, raw or 0))
    local fill = coreFill(usage, base, highlight)
    children[#children + 1] = stem(index, usage, fill, color.withAlpha(fill, 0.3), vertical)
  end

  local container = vertical and ui.column or ui.row
  barWidget.render(container({ gap = STEM_GAP, align = "center" }, children))
  barWidget.setVisible(true)
end

local function refresh()
  render(noctalia.cpuCores())
end

noctalia.setUpdateInterval(updateInterval)
refresh()

function update()
  refresh()
end

--!nonstrict
-- Per-core CPU load bars, drawn as the built-in sysmon gauge: thin rounded
-- stems with a dimmed track and a foreground-to-highlight gradient.

local color = require("./lib/color.luau")
local animate = require("./lib/animate.luau")

local sampleInterval = noctalia.getConfig("updateInterval") or 2000
local highlightRole = noctalia.getConfig("highlightColor") or "error"

local activityThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_activity_threshold")) or 50
local criticalThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_critical_threshold")) or 90

local STEM_WIDTH = 4
local STEM_HEIGHT = 17
local STEM_GAP = 4
local STEM_RADIUS = 2

-- Bar widgets have no frame-tick API. Run a short interval while the bars are
-- easing, then fall back to the sampling interval once they settle.
local ANIMATION_TICK_MS = 50
local SMOOTHING_TAU_MS = 110

local targets = nil
local display = nil
local lastSampleAt = 0
local lastTickAt = 0
local currentTickMs = nil

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

local function setTick(ms)
  ms = math.max(16, math.floor(ms))
  if ms ~= currentTickMs then
    currentTickMs = ms
    noctalia.setUpdateInterval(ms)
  end
end

local function sample(now)
  -- The idle timer targets sampleInterval exactly; allow for a little timer
  -- jitter so an early wake-up does not push the next sample out another cycle.
  if targets and now - lastSampleAt < sampleInterval - ANIMATION_TICK_MS then return end

  local cores = noctalia.cpuCores()
  if cores and #cores > 0 then
    targets = {}
    for index, value in ipairs(cores) do
      targets[index] = math.max(0, math.min(100, value or 0))
    end
    lastSampleAt = now
  elseif targets then
    lastSampleAt = now
  end
end

local function tick()
  local now = noctalia.nowMs()
  sample(now)

  if not targets then
    barWidget.setVisible(false)
    setTick(ANIMATION_TICK_MS)
    return
  end

  if not display then
    display = {}
    for index, value in ipairs(targets) do display[index] = value end
    render(display)
    lastTickAt = now
    setTick(sampleInterval)
    return
  end

  -- After an idle gap the first frame needs an animation-sized delta, not the
  -- whole sampling interval, or the bars jump in one step.
  local elapsed = now - lastTickAt
  local dt = (lastTickAt == 0 or elapsed > ANIMATION_TICK_MS * 2) and ANIMATION_TICK_MS or elapsed
  lastTickAt = now

  local nextDisplay, moving = animate.smooth(display, targets, dt, SMOOTHING_TAU_MS)

  local changed = #nextDisplay ~= #display
  if not changed then
    for index, value in ipairs(nextDisplay) do
      if value ~= display[index] then
        changed = true
        break
      end
    end
  end

  display = nextDisplay
  if changed then render(display) end

  setTick(moving and ANIMATION_TICK_MS or sampleInterval)
end

setTick(ANIMATION_TICK_MS)
tick()

function update()
  tick()
end

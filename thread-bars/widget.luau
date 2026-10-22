--!nonstrict
-- Per-core CPU load bars, drawn as the built-in sysmon gauge: thin rounded
-- stems with a dimmed track and a foreground-to-highlight gradient.

local color = require("./lib/color.luau")
local animate = require("./lib/animate.luau")

local highlightRole = noctalia.getConfig("highlightColor") or "error"

local activityThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_activity_threshold")) or 50
local criticalThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_critical_threshold")) or 90

local STEM_WIDTH = 4
local STEM_HEIGHT = 17
local STEM_GAP = 2
local STEM_RADIUS = 2

-- Bar widgets have no frame-tick API. Tick while easing, then idle until the
-- sampler service publishes the next sample.
local ANIMATION_TICK_MS = 60
local IDLE_TICK_MS = 1000
local SMOOTHING_TAU_MS = 110

local targets = nil
local display = nil
local lastTickAt = 0
local currentTickMs = nil

-- The palette only changes on a theme switch, and usage is quantized to whole
-- percentages, so fill/track strings are cached instead of rebuilt per frame.
local fillCache = {}
local trackCache = {}
local cachedBaseHex = nil
local cachedHighlightHex = nil

local function palette()
  local baseHex = noctalia.getColor("on_surface")
  if not baseHex then
    baseHex = noctalia.isDarkMode() and "#ffffff" or "#000000"
  end
  local highlightHex = noctalia.getColor(highlightRole) or noctalia.getColor("error") or "#ff0000"
  return baseHex, highlightHex, color.parseHex(baseHex), color.parseHex(highlightHex)
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

  local baseHex, highlightHex, base, highlight = palette()
  if not (base and highlight) then
    barWidget.setVisible(false)
    return
  end

  if baseHex ~= cachedBaseHex or highlightHex ~= cachedHighlightHex then
    fillCache = {}
    trackCache = {}
    cachedBaseHex = baseHex
    cachedHighlightHex = highlightHex
  end

  local vertical = barWidget.isVertical()
  local children = {}

  for index, raw in ipairs(cores) do
    local usage = math.max(0, math.min(100, raw or 0))
    local usageKey = math.floor(usage + 0.5)
    local fill = fillCache[usageKey]
    if not fill then
      fill = coreFill(usageKey, base, highlight)
      fillCache[usageKey] = fill
      trackCache[fill] = color.withAlpha(fill, 0.3)
    end
    children[#children + 1] = stem(index, usage, fill, trackCache[fill], vertical)
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

local function applyCores(cores)
  if not cores or #cores == 0 then
    targets = nil
    barWidget.setVisible(false)
    setTick(IDLE_TICK_MS)
    return
  end

  local nextTargets = {}
  for index, value in ipairs(cores) do
    nextTargets[index] = math.max(0, math.min(100, value or 0))
  end

  local countChanged = not targets or #targets ~= #nextTargets
  targets = nextTargets

  if not display or countChanged then
    display = {}
    for index, value in ipairs(nextTargets) do display[index] = value end
    lastTickAt = noctalia.nowMs()
    render(display)
    setTick(IDLE_TICK_MS)
  else
    setTick(ANIMATION_TICK_MS)
  end
end

local function tick()
  if not targets or not display then
    setTick(IDLE_TICK_MS)
    return
  end

  local now = noctalia.nowMs()
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

  setTick(moving and ANIMATION_TICK_MS or IDLE_TICK_MS)
end

setTick(IDLE_TICK_MS)
applyCores(noctalia.state.get("cores"))

noctalia.state.watch("cores", function(cores)
  applyCores(cores)
end)

function update()
  tick()
end

function onClick()
  noctalia.togglePanel("bennypowers/thread-bars:details")
end

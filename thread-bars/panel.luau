--!nonstrict
-- Details panel: one overlaid line graph with every core color-coded, plus an
-- overall line and a compact legend. A single stacked layout would exhaust the
-- vertical axis on high-core-count machines.

local color = require("./lib/color.luau")
local palette = require("./lib/palette.luau")
local history = require("./lib/history.luau")

local GRAPH_HEIGHT = 260
local LEGEND_COLUMNS = 6
local ANIMATION_FRAME_MS = 33
local SCROLL_SUBDIVISIONS = 16
local MAX_SAMPLES = 30

local base = nil
local nextSample = nil
local pending = {}
local tree = nil
local graphSlots = {}
local overallSlot = nil
local denseCores = {}
local denseOverall = {}

local isOpen = false
local accumulatedMs = 0
local phaseStartAt = 0
local lastOffset = -1
local EMPTY = {}

local activityThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_activity_threshold")) or 50
local criticalThreshold =
  tonumber(noctalia.getSetting("system.monitor.cpu_usage_critical_threshold")) or 90

local function paletteColors(count)
  local seeds = {}
  for _, role in ipairs({ "primary", "secondary", "tertiary", "error" }) do
    local hex = noctalia.getColor(role)
    if hex then seeds[#seeds + 1] = hex end
  end
  return palette.derive(seeds, count, noctalia.isDarkMode())
end

local function fillFor(usage, baseColor, highlight)
  return color.formatHex(
    color.blend(baseColor, highlight, color.gradientFactor(usage, activityThreshold, criticalThreshold))
  )
end

local function latest(values)
  if not values or #values == 0 then return 0 end
  return values[#values]
end

local function average(values)
  if not values or #values == 0 then return 0 end
  local total = 0
  for _, value in ipairs(values) do total = total + value end
  return total / #values
end

local function peak(values)
  local highest = 0
  for _, value in ipairs(values or {}) do
    if value > highest then highest = value end
  end
  return highest
end

local function padded(values)
  return history.padLeft(values or {}, MAX_SAMPLES, 0)
end

local function rebuildDense()
  denseCores = {}
  local sameCores = nextSample and #nextSample.cores == #base.cores

  for index, values in ipairs(base.cores or {}) do
    local lead = nil
    if sameCores and nextSample.cores[index] then
      lead = latest(nextSample.cores[index])
    end
    denseCores[index] = history.densify(padded(values), SCROLL_SUBDIVISIONS, lead)
  end

  local overallLead = nextSample and sameCores and latest(nextSample.overall) or nil
  denseOverall = history.densify(padded(base.overall or {}), SCROLL_SUBDIVISIONS, overallLead)
end

-- Graph exposes two series per node, so pairs of cores share a layer. A
-- negative gap collapses the stacked layers onto the same origin; boxes cannot
-- carry declarative children, columns can.
local function layeredGraph(series, overallValues, overallColor)
  local layers = {}
  local index = 1
  while index <= #series do
    local first = series[index]
    local second = series[index + 1]
    local node = ui.graph({
      key = "layer-" .. (#layers + 1),
      values = first.values,
      color = first.color,
      values2 = second and second.values or {},
      color2 = second and second.color or nil,
      height = GRAPH_HEIGHT,
      lineWidth = 0.75,
      fillOpacity = 0,
    })
    graphSlots[#graphSlots + 1] = {
      node = node,
      first = first.index,
      second = second and second.index or nil,
    }
    layers[#layers + 1] = node
    index = index + 2
  end

  overallSlot = ui.graph({
    key = "overall",
    values = overallValues,
    color = overallColor,
    height = GRAPH_HEIGHT,
    lineWidth = 1.5,
    fillOpacity = 0,
  })
  layers[#layers + 1] = overallSlot

  return ui.column({
    height = GRAPH_HEIGHT,
    gap = -GRAPH_HEIGHT,
    align = "stretch",
    fill = "surface/0.25",
    radius = 8,
  }, layers)
end

local function legend(coreHistory, colors)
  local rows = {}
  for first = 1, #coreHistory, LEGEND_COLUMNS do
    local cells = {}
    local last = math.min(first + LEGEND_COLUMNS - 1, #coreHistory)
    for index = first, last do
      local usage = latest(coreHistory[index])
      cells[#cells + 1] = ui.row({
        key = "legend-" .. index,
        width = 74,
        gap = 4,
        align = "center",
      }, {
        ui.box({ width = 8, height = 8, radius = 2, fill = colors[index] }),
        ui.label({
          text = string.format("C%d %d%%", index - 1, math.floor(usage + 0.5)),
          fontSize = 10,
          color = "on_surface_variant",
          maxLines = 1,
        }),
      })
    end
    rows[#rows + 1] = ui.row({ gap = 4, justify = "space_between" }, cells)
  end
  return rows
end

-- Builds the full tree once per adopted sample. Frame ticks then repaint only
-- the graph node values, keeping the callback under its CPU budget.
local function buildTree()
  graphSlots = {}
  overallSlot = nil

  local children = {}

  table.insert(children, ui.row({ align = "center", justify = "space_between" }, {
    ui.label({
      text = noctalia.tr("panel.title"),
      fontSize = 18,
      fontWeight = "bold",
      flexGrow = 1,
    }),
    ui.button({ glyph = "x", variant = "ghost", onClick = "onClosePanel" }),
  }))

  local overallHistory = base.overall or {}
  local coreHistory = base.cores or {}

  if #overallHistory == 0 then
    table.insert(children, ui.label({
      text = noctalia.tr("panel.waiting"),
      fontSize = 13,
      color = "on_surface_variant",
    }))
    tree = ui.column({ gap = 12, padding = 16 }, children)
    return
  end

  local baseHex = noctalia.getColor("on_surface")
  local highlightHex = noctalia.getColor("error")
  local baseColor = baseHex and color.parseHex(baseHex) or nil
  local highlight = highlightHex and color.parseHex(highlightHex) or nil

  local overall = latest(overallHistory)
  local overallFill = baseColor and highlight and fillFor(overall, baseColor, highlight) or "primary"
  local overallLine = baseHex or "on_surface"
  local colors = paletteColors(#coreHistory)

  local hottestIndex = 0
  local hottestUsage = -1
  for index, values in ipairs(coreHistory) do
    local usage = latest(values)
    if usage > hottestUsage then
      hottestUsage = usage
      hottestIndex = index
    end
  end

  local series = {}
  for index, values in ipairs(coreHistory) do
    series[index] = {
      index = index,
      values = EMPTY,
      color = colors[index],
    }
  end

  local stats = {
    ui.label({
      text = string.format("%s %d%%", noctalia.tr("panel.peak"), math.floor(peak(overallHistory) + 0.5)),
      fontSize = 11,
      color = "on_surface_variant",
    }),
    ui.label({
      text = string.format("%s %d%%", noctalia.tr("panel.average"), math.floor(average(overallHistory) + 0.5)),
      fontSize = 11,
      color = "on_surface_variant",
    }),
  }
  if hottestIndex > 0 then
    table.insert(stats, ui.label({
      text = string.format(
        "%s C%d %d%%",
        noctalia.tr("panel.hottest"),
        hottestIndex - 1,
        math.floor(hottestUsage + 0.5)
      ),
      fontSize = 11,
      color = colors[hottestIndex] or "on_surface_variant",
    }))
  end
  table.insert(stats, ui.label({
    text = string.format("%d %s", #coreHistory, noctalia.tr("panel.threads")),
    fontSize = 11,
    color = "on_surface_variant",
  }))

  local legendRows = legend(coreHistory, colors)

  table.insert(children, ui.column({
    fill = "surface_variant/0.5",
    radius = 12,
    border = "outline/0.2",
    borderWidth = 1,
    padding = 12,
    gap = 10,
  }, {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.column({ gap = 0 }, {
        ui.label({
          text = noctalia.tr("panel.overall"),
          fontSize = 11,
          color = "on_surface_variant",
        }),
        ui.label({
          text = string.format("%d%%", math.floor(overall + 0.5)),
          fontSize = 28,
          fontWeight = "bold",
          color = overallFill,
        }),
      }),
      ui.column({ gap = 3, align = "end" }, stats),
    }),
    layeredGraph(series, EMPTY, overallLine),
    ui.row({ justify = "space_between" }, {
      ui.label({
        text = noctalia.tr("panel.history_caption"),
        fontSize = 10,
        color = "on_surface_variant",
      }),
      ui.label({
        text = noctalia.tr("panel.overall_line"),
        fontSize = 10,
        color = "on_surface_variant",
      }),
    }),
    ui.column({ gap = 4 }, legendRows),
  }))

  tree = ui.scroll({ gap = 10, padding = 16 }, children)
end

local overallValues = {}

local function paint(offset)
  if not tree then return end

  for _, slot in ipairs(graphSlots) do
    slot.values = slot.values or {}
    history.fillWindow(slot.values, denseCores[slot.first] or {}, SCROLL_SUBDIVISIONS, offset)
    slot.node.props.values = slot.values

    if slot.second then
      slot.values2 = slot.values2 or {}
      history.fillWindow(slot.values2, denseCores[slot.second] or {}, SCROLL_SUBDIVISIONS, offset)
      slot.node.props.values2 = slot.values2
    else
      slot.node.props.values2 = EMPTY
      slot.node.props.color2 = nil
    end
  end

  if overallSlot then
    history.fillWindow(overallValues, denseOverall, SCROLL_SUBDIVISIONS, offset)
    overallSlot.props.values = overallValues
  end

  panel.render(tree)
end

local function intervalMs()
  return base and base.intervalMs and base.intervalMs > 0 and base.intervalMs or 1000
end

local function currentProgress()
  return math.max(0, math.min(1, (noctalia.nowMs() - phaseStartAt) / intervalMs()))
end

local function startPhase(snapshot)
  nextSample = snapshot
  phaseStartAt = noctalia.nowMs()
  lastOffset = 0
  rebuildDense()
  if not tree then buildTree() end
  paint(0)
end

local function adoptBase(snapshot)
  base = snapshot
  nextSample = table.remove(pending, 1)
  if base and nextSample and #base.cores ~= #nextSample.cores then
    -- A core went offline/online: skip the seam rather than guess a lead.
    base = nextSample
    nextSample = table.remove(pending, 1)
  end
  lastOffset = 0
  rebuildDense()
  buildTree()
  if nextSample then phaseStartAt = noctalia.nowMs() end
  paint(0)
end

local function acceptSample(value)
  value = value or { cores = {}, overall = {} }

  if not base or #(base.cores or {}) == 0 then
    base = value
    nextSample = nil
    rebuildDense()
    buildTree()
    paint(0)
    return
  end

  if not nextSample then
    startPhase(value)
    return
  end

  pending[#pending + 1] = value
  if #pending > 4 then table.remove(pending, 1) end
end

noctalia.state.watch("history", function(value)
  if isOpen then acceptSample(value) end
end)

function onOpen()
  isOpen = true
  pending = {}
  nextSample = nil
  base = noctalia.state.get("history") or { cores = {}, overall = {} }
  rebuildDense()
  buildTree()
  lastOffset = 0
  paint(0)
  panel.setNeedsFrameTick(true)
end

function onFrameTick(deltaMs)
  if not isOpen or not base or not nextSample then return end

  accumulatedMs = accumulatedMs + (deltaMs or 0)
  if accumulatedMs < ANIMATION_FRAME_MS then return end
  accumulatedMs = 0

  local current = currentProgress()
  if current >= 1 then
    if lastOffset < SCROLL_SUBDIVISIONS then
      lastOffset = SCROLL_SUBDIVISIONS
      paint(SCROLL_SUBDIVISIONS)
      return
    end
    adoptBase(nextSample)
    return
  end

  local offset = math.floor(current * SCROLL_SUBDIVISIONS + 0.5)
  if offset ~= lastOffset then
    lastOffset = offset
    paint(offset)
  end
end

function onClose()
  isOpen = false
  pending = {}
  nextSample = nil
  accumulatedMs = 0
  panel.setNeedsFrameTick(false)
end

function onClosePanel()
  panel.close()
end

--!nonstrict
-- Schedule panel: stop details plus every upcoming arrival inside the
-- monitoring window.

local transit = require("./lib/transit.luau")

local MAX_ROWS = 40

local state = nil
local open = false
local lastTickMinute = -1

local function etaLabel(eta)
  if eta <= 0 then
    return noctalia.tr("common.now")
  end
  return noctalia.tr("common.eta", { count = eta })
end

local function etaColor(eta)
  if eta <= 3 then
    return "primary"
  end
  if eta <= 10 then
    return "on_surface"
  end
  return "tertiary"
end

local function arrivalRows(arrivals)
  local rows = {}
  local count = #arrivals
  if count > MAX_ROWS then
    count = MAX_ROWS
  end
  for index = 1, count do
    local arr = arrivals[index]
    local subParts = {}
    if arr.origin ~= "" then
      table.insert(subParts, arr.origin)
    end
    if arr.plate ~= "" then
      table.insert(subParts, arr.plate)
    end
    table.insert(rows, ui.row({
      key = "arrival-" .. index,
      gap = 10,
      padding = 10,
      fill = "surface_container",
      radius = 8,
      align = "center",
    }, {
      ui.label({ text = arr.route, fontSize = 16, fontWeight = "bold", width = 52 }),
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = arr.destination, fontSize = 13, maxLines = 1 }),
        ui.label({
          text = table.concat(subParts, " · "),
          fontSize = 11,
          color = "tertiary",
          maxLines = 1,
        }),
      }),
      ui.label({
        text = etaLabel(arr.eta),
        fontSize = 14,
        fontWeight = "bold",
        color = etaColor(arr.eta),
      }),
    }))
  end
  return rows
end

local function errorBody(errorReason, detail)
  local bodyKey = "panel.errorParse"
  if errorReason == "no_stop" then
    bodyKey = "panel.noStop"
  elseif errorReason == "network" then
    bodyKey = "panel.errorNetwork"
  end
  local body = noctalia.tr(bodyKey)
  if detail ~= nil and detail ~= "" then
    body = body .. " (" .. detail .. ")"
  end
  return body
end

local function errorView(errorReason, detail)
  local action
  if errorReason == "no_stop" then
    action = ui.button({
      text = noctalia.tr("panel.openSettings"),
      variant = "primary",
      onClick = "openSettings",
    })
  else
    action = ui.button({
      text = noctalia.tr("panel.retry"),
      variant = "primary",
      onClick = "refresh",
    })
  end
  panel.render(ui.column({ gap = 12, padding = 24, align = "center" }, {
    ui.glyph({ name = "alert-triangle", size = 24, color = "error" }),
    ui.label({ text = errorBody(errorReason, detail), maxLines = 4 }),
    action,
  }))
end

-- Stale banner shown above the last known arrivals; it disappears as soon as
-- the service publishes a successful fetch.
local function staleBanner(text)
  return ui.row({
    gap = 8,
    padding = 8,
    align = "center",
    fill = "error/0.12",
    radius = 8,
  }, {
    ui.glyph({ name = "alert-triangle", size = 16, color = "error" }),
    ui.label({ text = text, fontSize = 12, color = "error", flexGrow = 1, maxLines = 3 }),
    ui.button({ glyph = "refresh", variant = "ghost", onClick = "refresh" }),
  })
end

local function render()
  if not open then
    return
  end
  lastTickMinute = math.floor(noctalia.nowMs() / 60000)

  if state == nil then
    panel.setWantsSecondTicks(false)
    panel.render(ui.column({ padding = 24, align = "center" }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "tertiary" }),
    }))
    return
  end

  local stale = state.ok == false
  local arrivals
  local warning = nil
  if stale then
    arrivals = transit.liveArrivals(state.arrivals, state.updatedAtMs, noctalia.nowMs())
    if #arrivals == 0 then
      panel.setWantsSecondTicks(false)
      errorView(state.error or "", state.detail or "")
      return
    end
    warning = errorBody(state.error or "", state.detail or "")
      .. " "
      .. noctalia.tr("panel.stale")
  else
    arrivals = state.arrivals
  end
  -- Age stale ETAs once a minute while the panel is open.
  panel.setWantsSecondTicks(stale)

  local stop = state.stop
  local subParts = {}
  if stop.street ~= "" then
    table.insert(subParts, stop.street)
  end
  if stop.city ~= "" then
    table.insert(subParts, stop.city)
  end
  if stop.code ~= "" then
    table.insert(subParts, noctalia.tr("panel.stop", { code = stop.code }))
  end

  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "bus", size = 18, color = "primary" }),
      ui.label({
        text = stop.name,
        fontSize = 16,
        fontWeight = "bold",
        flexGrow = 1,
        maxLines = 1,
      }),
      ui.button({ glyph = "settings", variant = "ghost", onClick = "openSettings" }),
      ui.button({ glyph = "refresh", variant = "ghost", onClick = "refresh" }),
    }),
    ui.label({
      text = table.concat(subParts, " · "),
      fontSize = 12,
      color = "tertiary",
    }),
  }

  if warning ~= nil then
    table.insert(children, staleBanner(warning))
  end

  if #arrivals == 0 then
    table.insert(children, ui.label({
      text = noctalia.tr("panel.noArrivals"),
      color = "tertiary",
    }))
  else
    table.insert(children, ui.scroll({ flexGrow = 1, gap = 6 }, arrivalRows(arrivals)))
    table.insert(children, ui.label({
      text = noctalia.tr("panel.updated", {
        time = noctalia.formatTime("{:%H:%M}", math.floor(state.updatedAtMs / 1000)),
      }),
      fontSize = 11,
      color = "tertiary",
    }))
  end

  panel.render(ui.column({ gap = 10, padding = 12 }, children))
end

function update()
  if not open or state == nil or state.ok ~= false then
    return
  end
  local minute = math.floor(noctalia.nowMs() / 60000)
  if minute ~= lastTickMinute then
    lastTickMinute = minute
    render()
  end
end

function refresh()
  noctalia.state.set("transit-refresh", noctalia.nowMs())
end

function openSettings()
  noctalia.openSettings()
end

function onOpen()
  open = true
  render()
  refresh()
end

function onClose()
  open = false
end

state = noctalia.state.get("transit")
noctalia.state.watch("transit", function(value)
  state = value
  render()
end)

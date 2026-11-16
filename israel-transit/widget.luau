--!nonstrict
-- Bar widget: soonest arrival at the configured stop. Click opens the
-- schedule panel, right-click opens the plugin settings. On a failed fetch,
-- arrivals from the last success that have not departed are still shown with
-- a warning glyph.

local transit = require("./lib/transit.luau")

local PANEL_ID = "bennypowers/israel-transit:schedule"

-- Publish this instance's stop override to the fetcher service. An empty
-- value means "use the plugin-level stop".
noctalia.state.set("transit-stop", noctalia.getConfig("stopCode") or "")

local current = nil

local function etaLabel(eta)
  if eta <= 0 then
    return noctalia.tr("common.now")
  end
  return noctalia.tr("common.eta", { count = eta })
end

local function stopLabel(stop)
  if not stop then
    return ""
  end
  local label = stop.name or ""
  if stop.city ~= nil and stop.city ~= "" then
    label = label .. " (" .. stop.city .. ")"
  end
  return label
end

local function errorLabel(state)
  local key = state.error == "no_stop" and "widget.noStop" or "widget.error"
  local label = noctalia.tr(key)
  if state.detail ~= nil and state.detail ~= "" then
    label = label .. " (" .. state.detail .. ")"
  end
  return label
end

local function liveArrivals(state)
  return transit.liveArrivals(state.arrivals, state.updatedAtMs, noctalia.nowMs())
end

local function apply(state)
  current = state
  if state == nil then
    barWidget.setGlyph("bus")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("widget.idle"))
    return
  end

  if state.ok == false then
    barWidget.setGlyph("alert-triangle")
    local arrivals = liveArrivals(state)
    if #arrivals > 0 then
      local nextArrival = arrivals[1]
      barWidget.setText(nextArrival.route .. " · " .. etaLabel(nextArrival.eta))
      barWidget.setTooltip({
        { noctalia.tr("widget.stale"), errorLabel(state) },
        { "Stop", stopLabel(state.stop) },
        {
          "Next",
          nextArrival.route .. " → " .. nextArrival.destination .. " · " .. etaLabel(nextArrival.eta),
        },
      })
    else
      local label = errorLabel(state)
      barWidget.setText(label)
      barWidget.setTooltip(label)
    end
    return
  end

  barWidget.setGlyph("bus")
  local nextArrival = state.arrivals[1]
  if nextArrival then
    barWidget.setText(nextArrival.route .. " · " .. etaLabel(nextArrival.eta))
  else
    barWidget.setText(noctalia.tr("widget.noBus"))
  end

  local rows = { { "Stop", stopLabel(state.stop) } }
  if nextArrival then
    table.insert(rows, {
      "Next",
      nextArrival.route .. " → " .. nextArrival.destination .. " · " .. etaLabel(nextArrival.eta),
    })
  end
  barWidget.setTooltip(rows)
end

-- Re-render while a stale window ages, so ETAs tick down and expired rows
-- drop out even while the service keeps failing.
noctalia.setUpdateInterval(30000)

function update()
  if current ~= nil then
    apply(current)
  end
end

apply(noctalia.state.get("transit"))
noctalia.state.watch("transit", apply)

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  noctalia.openSettings()
end

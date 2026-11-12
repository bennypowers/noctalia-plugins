--!nonstrict
-- Bar widget: soonest arrival at the configured stop. Click opens the
-- schedule panel, right-click opens the plugin settings.

local PANEL_ID = "bennypowers/israel-transit:schedule"

-- Publish this instance's stop override to the fetcher service. An empty
-- value means "use the plugin-level stop".
noctalia.state.set("transit-stop", noctalia.getConfig("stopCode") or "")

local function etaLabel(eta)
  if eta <= 0 then
    return noctalia.tr("common.now")
  end
  return noctalia.tr("common.eta", { count = eta })
end

local function stopLabel(stop)
  local label = stop.name
  if stop.city ~= "" then
    label = label .. " (" .. stop.city .. ")"
  end
  return label
end

local function apply(state)
  if state == nil then
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("widget.idle"))
    return
  end
  if state.ok == false then
    local key
    if state.error == "no_stop" then
      key = "widget.noStop"
    else
      key = "widget.error"
    end
    barWidget.setText(noctalia.tr(key))
    barWidget.setTooltip(noctalia.tr(key))
    return
  end

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

barWidget.setGlyph("bus")
apply(noctalia.state.get("transit"))
noctalia.state.watch("transit", apply)

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  noctalia.openSettings()
end

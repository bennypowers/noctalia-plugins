--!nonstrict
-- Headless poller: fetches real-time arrivals for the configured stop from
-- the Israel transit API and publishes them for the widget and the panel.

local transit = require("./lib/transit.luau")

local DEFAULT_API = "https://api.ginzburg.io/il_transport"

local stopCode = noctalia.getConfig("stopCode") or ""
local apiUrl = noctalia.getConfig("apiUrl") or ""
local refreshSeconds = noctalia.getConfig("refreshInterval") or 30
local monitoringMinutes = noctalia.getConfig("monitoringInterval") or 30

-- A widget instance can override the plugin-level stop via its own setting;
-- the last published non-empty value wins.
local widgetStop = noctalia.state.get("transit-stop") or ""

local fetching = false

-- The widget-level stop wins when set; otherwise the plugin-level one.
local function effectiveStop()
  if widgetStop ~= "" then
    return widgetStop
  end
  return stopCode
end

local function endpoint()
  local base = apiUrl
  if base == "" then
    base = DEFAULT_API
  end
  return base:gsub("/+$", "")
    .. "/siri/get_routes_for_stop/" .. noctalia.string.urlEncode(effectiveStop())
    .. "?monitoring_interval=" .. tostring(monitoringMinutes)
end

local function publish(value)
  noctalia.state.set("transit", value)
end

local function fail(reason, detail)
  publish({ ok = false, error = reason, detail = detail or "" })
end

local function fetch()
  if fetching then
    return
  end
  if effectiveStop() == "" then
    fail("no_stop")
    return
  end
  fetching = true
  local started = noctalia.http({ url = endpoint() }, function(response)
    fetching = false
    if not response.ok or response.status ~= 200 then
      fail("network", tostring(response.status or ""))
      return
    end
    local decoded, err = noctalia.json.decode(response.body)
    if not decoded or not transit.isValidPayload(decoded) then
      fail("parse", err or "")
      return
    end
    publish({
      ok = true,
      stop = transit.normalizeStop(decoded.stop_info),
      arrivals = transit.normalizeArrivals(decoded.incoming_routes),
      updatedAtMs = noctalia.nowMs(),
    })
  end)
  if not started then
    fetching = false
    fail("network", "request not started")
  end
end

noctalia.setUpdateInterval(refreshSeconds * 1000)
fetch()

function update()
  fetch()
end

-- The panel asks for an immediate fetch when it opens.
noctalia.state.watch("transit-refresh", function()
  fetch()
end)

-- Widget instances publish their stop override here.
noctalia.state.watch("transit-stop", function(value)
  widgetStop = value or ""
  fetch()
end)

function onConfigChanged()
  stopCode = noctalia.getConfig("stopCode") or ""
  apiUrl = noctalia.getConfig("apiUrl") or ""
  refreshSeconds = noctalia.getConfig("refreshInterval") or 30
  monitoringMinutes = noctalia.getConfig("monitoringInterval") or 30
  noctalia.setUpdateInterval(refreshSeconds * 1000)
  fetch()
end

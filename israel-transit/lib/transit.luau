--!nonstrict
-- Pure helpers for the Israel transit plugin: validates the API payload,
-- normalizes stops and arrivals into plain display data. Kept free of
-- noctalia.* calls so the test suite can load it directly.

local M = {}

-- The payload is valid when it carries both a stop and a route list.
function M.isValidPayload(decoded)
  return type(decoded) == "table"
    and type(decoded.stop_info) == "table"
    and type(decoded.incoming_routes) == "table"
end

-- Normalizes stop_info into { code, name, city, street }.
function M.normalizeStop(stop)
  local result = { code = "", name = "", city = "", street = "" }
  if type(stop) ~= "table" then
    return result
  end
  if stop.code ~= nil then
    result.code = tostring(stop.code)
  end
  if type(stop.name) == "string" then
    result.name = stop.name
  end
  if type(stop.city) == "string" then
    result.city = stop.city
  end
  if type(stop.street) == "string" then
    result.street = stop.street
  end
  return result
end

-- Normalizes incoming_routes into rows sorted by ascending ETA:
-- { route, destination, origin, agency, plate, eta }.
-- Malformed entries (missing route table or non-numeric eta) are dropped.
function M.normalizeArrivals(routes)
  local rows = {}
  if type(routes) ~= "table" then
    return rows
  end
  for _, item in ipairs(routes) do
    if type(item) == "table" and type(item.route) == "table" then
      local route = item.route
      local eta = tonumber(item.eta)
      if eta ~= nil then
        local agency = ""
        if type(route.agency) == "table" and type(route.agency.name) == "string" then
          agency = route.agency.name
        end
        table.insert(rows, {
          route = route.short_name ~= nil and tostring(route.short_name) or "?",
          destination = type(route.to_stop_name) == "string" and route.to_stop_name or "",
          origin = type(route.from_stop_name) == "string" and route.from_stop_name or "",
          agency = agency,
          plate = type(item.plate_number) == "string" and item.plate_number or "",
          eta = math.floor(eta),
        })
      end
    end
  end
  table.sort(rows, function(a, b)
    return a.eta < b.eta
  end)
  return rows
end

-- Arrivals from a previous successful fetch that are still relevant at
-- `nowMs`. ETAs are relative to the fetch time, so they are aged here; a
-- departure gets one minute of grace so a bus due "now" does not vanish the
-- instant the next poll fails.
function M.liveArrivals(arrivals, updatedAtMs, nowMs)
  local rows = {}
  if type(arrivals) ~= "table" or type(updatedAtMs) ~= "number" then
    return rows
  end
  local elapsed = (tonumber(nowMs) or updatedAtMs) - updatedAtMs
  for _, arrival in ipairs(arrivals) do
    local eta = tonumber(arrival.eta)
    if eta ~= nil then
      local remainingMs = eta * 60000 - elapsed
      if remainingMs > -60000 then
        local copy = {}
        for key, value in pairs(arrival) do
          copy[key] = value
        end
        copy.eta = math.max(0, math.ceil(remainingMs / 60000))
        rows[#rows + 1] = copy
      end
    end
  end
  return rows
end

return M

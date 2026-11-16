-- Pure-Lua tests for israel-transit/lib/transit.luau.
-- Run from the repository root: lua tests/test_transit.lua

local chunk, loadErr = loadfile("israel-transit/lib/transit.luau")
assert(chunk, loadErr)

local transit = chunk()
assert(type(transit) == "table", "transit module must return a table")

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write("FAIL: " .. name .. "\n  " .. tostring(err) .. "\n")
  end
end

local function eq(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function deepEq(actual, expected, label)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    eq(actual, expected, label)
    return
  end
  for key, value in pairs(expected) do
    deepEq(actual[key], value, (label or "value") .. "." .. tostring(key))
  end
  for key, _ in pairs(actual) do
    if expected[key] == nil then
      error((label or "value") .. " has unexpected key " .. tostring(key), 2)
    end
  end
end

-- A trimmed copy of a real /siri/get_routes_for_stop/5200 response.
local samplePayload = {
  response_time = "2026-11-12T10:08:27.636397",
  stop_info = {
    id = 10846,
    code = 5200,
    name = "שדרות שז''ר/בנייני האומה",
    city = "ירושלים",
    street = "שדרות שז''ר",
  },
  incoming_routes = {
    {
      eta = 4,
      plate_number = "23375802",
      route = {
        short_name = "15",
        to_stop_name = "תחנת רקל''ה קריית הממשלה",
        from_stop_name = "תחנה תפעולית/חניון תלפיות",
        agency = { id = 3, name = "אגד" },
      },
    },
    {
      eta = 1,
      plate_number = "17771603",
      route = {
        short_name = "541",
        to_stop_name = "עטרות/יציאה",
        from_stop_name = "חניון הלאום",
        agency = { id = 38, name = "אקסטרה ירושלים" },
      },
    },
    {
      eta = 4,
      -- malformed: no route table; must be dropped
    },
    {
      eta = "soon",
      plate_number = "1",
      route = { short_name = "9" },
      -- malformed: non-numeric eta; must be dropped
    },
  },
}

test("accepts a valid payload", function()
  eq(transit.isValidPayload(samplePayload), true, "valid payload")
end)

test("rejects missing or wrong payload shapes", function()
  eq(transit.isValidPayload(nil), false, "nil")
  eq(transit.isValidPayload({}), false, "empty table")
  eq(transit.isValidPayload({ stop_info = {} }), false, "missing routes")
  eq(transit.isValidPayload({ incoming_routes = {} }), false, "missing stop")
  eq(transit.isValidPayload("string"), false, "non-table")
end)

test("normalizes the stop", function()
  deepEq(transit.normalizeStop(samplePayload.stop_info), {
    code = "5200",
    name = "שדרות שז''ר/בנייני האומה",
    city = "ירושלים",
    street = "שדרות שז''ר",
  }, "stop")
end)

test("normalizes a missing stop into empty fields", function()
  deepEq(transit.normalizeStop(nil), { code = "", name = "", city = "", street = "" }, "nil stop")
  deepEq(transit.normalizeStop({ name = 42, code = 7 }), {
    code = "7",
    name = "",
    city = "",
    street = "",
  }, "partial stop")
end)

test("sorts arrivals by ascending eta", function()
  local rows = transit.normalizeArrivals(samplePayload.incoming_routes)
  eq(#rows, 2, "row count after dropping malformed entries")
  eq(rows[1].route, "541", "first route")
  eq(rows[1].eta, 1, "first eta")
  eq(rows[2].route, "15", "second route")
  eq(rows[2].eta, 4, "second eta")
end)

test("keeps arrival fields", function()
  local rows = transit.normalizeArrivals(samplePayload.incoming_routes)
  deepEq(rows[1], {
    route = "541",
    destination = "עטרות/יציאה",
    origin = "חניון הלאום",
    agency = "אקסטרה ירושלים",
    plate = "17771603",
    eta = 1,
  }, "first row")
end)

test("tolerates missing arrival fields", function()
  local rows = transit.normalizeArrivals({
    { eta = 2, route = {} },
  })
  eq(#rows, 1, "row count")
  eq(rows[1].route, "?", "missing short_name")
  eq(rows[1].destination, "", "missing destination")
  eq(rows[1].origin, "", "missing origin")
  eq(rows[1].agency, "", "missing agency")
  eq(rows[1].plate, "", "missing plate")
  eq(rows[1].eta, 2, "eta")
end)

test("floors fractional etas", function()
  local rows = transit.normalizeArrivals({
    { eta = 3.7, route = { short_name = "1" } },
  })
  eq(rows[1].eta, 3, "floored eta")
end)

test("returns empty list for non-table input", function()
  eq(#transit.normalizeArrivals(nil), 0, "nil")
  eq(#transit.normalizeArrivals("x"), 0, "string")
end)

test("live arrivals drop past departures and age remaining etas", function()
  local updated = 1000000
  local rows = transit.liveArrivals({
    { route = "1", eta = 5 },
    { route = "2", eta = 1 },
  }, updated, updated + 120000)
  eq(#rows, 1, "only the future departure survives")
  eq(rows[1].route, "1", "kept route")
  eq(rows[1].eta, 3, "remaining eta")
end)

test("live arrivals keep a departure in its grace minute", function()
  local updated = 1000000
  local rows = transit.liveArrivals({ { route = "1", eta = 0 } }, updated, updated + 30000)
  eq(#rows, 1, "grace keeps it")
  eq(rows[1].eta, 0, "shows now")
  eq(#transit.liveArrivals({ { route = "1", eta = 0 } }, updated, updated + 120000), 0, "grace expires")
end)

test("live arrivals do not mutate the source", function()
  local source = { { route = "1", eta = 5 } }
  transit.liveArrivals(source, 0, 60000)
  eq(source[1].eta, 5, "source eta")
end)

test("live arrivals handle missing inputs", function()
  eq(#transit.liveArrivals(nil, 0, 0), 0, "nil arrivals")
  eq(#transit.liveArrivals({ { route = "1", eta = 5 } }, nil, 0), 0, "nil timestamp")
end)

io.stdout:write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)

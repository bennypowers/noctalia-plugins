-- Pure-Lua tests for thread-bars/lib/history.luau.
-- Run from the repository root: lua tests/test_history.lua

local chunk, loadErr = loadfile("thread-bars/lib/history.luau")
assert(chunk, loadErr)

local history = chunk()
assert(type(history) == "table", "history module must return a table")

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

local function near(actual, expected, epsilon, label)
  if math.abs(actual - expected) > (epsilon or 0.001) then
    error((label or "value") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

test("appends a sample", function()
  local nextHistory = history.push({ 10, 20 }, 30, 5)
  eq(#nextHistory, 3, "count")
  eq(nextHistory[1], 10, "first")
  eq(nextHistory[3], 30, "last")
end)

test("drops the oldest sample at capacity", function()
  local nextHistory = history.push({ 1, 2, 3 }, 4, 3)
  eq(#nextHistory, 3, "count")
  eq(nextHistory[1], 2, "first")
  eq(nextHistory[3], 4, "last")
end)

test("averages cores", function()
  eq(history.average({ 10, 20, 30 }), 20, "average")
  eq(history.average({}), 0, "empty average")
end)

test("pushes one sample per core", function()
  local histories = { { 10 }, { 20 } }
  local nextHistories = history.pushCores(histories, { 15, 25 }, 3)
  eq(#nextHistories, 2, "cores")
  eq(#nextHistories[1], 2, "first count")
  eq(nextHistories[1][2], 15, "first last")
  eq(nextHistories[2][2], 25, "second last")
end)

test("resets on core count change", function()
  local histories = { { 1, 2 }, { 3, 4 } }
  local nextHistories = history.pushCores(histories, { 10, 20, 30 }, 60)
  eq(#nextHistories, 3, "cores")
  eq(#nextHistories[1], 1, "first count")
  eq(nextHistories[1][1], 10, "first")
  eq(nextHistories[3][1], 30, "third")
end)

test("densify accepts a real next sample as the lead", function()
  local dense = history.densify({ 10, 20, 30 }, 2, 40)
  near(dense[7], 0.40, 0.001, "explicit lead")
end)

test("isFlat detects a constant window", function()
  eq(history.isFlat({ 0, 0, 0 }, 0), true, "all zero")
  eq(history.isFlat({ 12, 12, 12 }, nil), true, "no lead")
  eq(history.isFlat({ 12, 12, 12 }, 12), true, "matching lead")
end)

test("isFlat rejects a varying window or lead", function()
  eq(history.isFlat({ 0, 0, 1 }, 0), false, "varying samples")
  eq(history.isFlat({ 12, 12, 12 }, 13), false, "lead changes the line")
  eq(history.isFlat({}, 0), false, "empty window")
end)

test("tail keeps the newest samples", function()
  local recent = history.tail({ 1, 2, 3, 4, 5 }, 3)
  eq(#recent, 3, "count")
  eq(recent[1], 3, "first")
  eq(recent[3], 5, "last")
end)

test("tail returns a short history unchanged", function()
  local recent = history.tail({ 1, 2 }, 4)
  eq(#recent, 2, "count")
  eq(recent[1], 1, "first")
  eq(recent[2], 2, "last")
end)

test("tail of an empty history is empty", function()
  eq(#history.tail({}, 3), 0, "count")
  eq(#history.tail(nil, 3), 0, "nil count")
end)

test("pads short history on the left", function()
  local padded = history.padLeft({ 10, 20 }, 4, 0)
  eq(#padded, 4, "count")
  eq(padded[1], 0, "first pad")
  eq(padded[2], 0, "second pad")
  eq(padded[3], 10, "first sample")
  eq(padded[4], 20, "second sample")
end)

test("does not pad a full history", function()
  local padded = history.padLeft({ 1, 2, 3 }, 2, 0)
  eq(#padded, 3, "count")
  eq(padded[1], 1, "first")
end)

test("densifies history onto a finer grid", function()
  local dense = history.densify({ 10, 20, 30 }, 2)
  eq(#dense, 7, "count")
  near(dense[1], 0.10, 0.001, "sample 1")
  near(dense[2], 0.14375, 0.001, "smoothed midpoint 1")
  near(dense[3], 0.20, 0.001, "sample 2")
  near(dense[5], 0.30, 0.001, "sample 3")
  near(dense[7], 0.35, 0.001, "extrapolated lead")
end)

test("dense window slices the grid at an integer offset", function()
  local dense = history.densify({ 10, 20, 30 }, 2)
  local points = history.denseWindow(dense, 2, 0)
  eq(#points, 5, "count")
  near(points[1], 0.10, 0.001, "first")
  near(points[3], 0.20, 0.001, "middle")
  near(points[5], 0.30, 0.001, "last")
end)

test("dense window is a rigid translation", function()
  local dense = history.densify({ 10, 20, 30 }, 2)
  local before = history.denseWindow(dense, 2, 0)
  local after = history.denseWindow(dense, 2, 1)
  for index = 1, #before - 1 do
    near(after[index], before[index + 1], 0.0001, "point " .. index)
  end
  near(after[#after], 0.33125, 0.001, "next grid point")
end)

test("fill window reuses and trims the target table", function()
  local dense = history.densify({ 10, 20, 30 }, 2)
  local target = { 9, 9, 9, 9, 9, 9, 9 }
  local points = history.fillWindow(target, dense, 2, 0)
  eq(points, target, "same table")
  eq(#points, 5, "trimmed")
  near(points[1], 0.10, 0.001, "first")
  near(points[5], 0.30, 0.001, "last")
end)

test("roll appends one sample worth of grid points to a densified history", function()
  local before = { 10, 20, 30, 40, 50 }
  local after = { 20, 30, 40, 50, 60 }
  local dense = history.densify(before, 4, 55)
  local rolled = history.roll(dense, after, 4, 65)
  local fresh = history.densify(after, 4, 65)
  eq(#rolled, #fresh, "count")
  for index = 1, #fresh do
    near(rolled[index], fresh[index], 0.0001, "point " .. index)
  end
end)

test("roll rejects a history that did not shift by exactly one sample", function()
  local before = { 10, 20, 30, 40, 50 }
  local dense = history.densify(before, 4, 55)
  eq(history.roll(dense, { 10, 20, 30, 40, 50 }, 4, 55, before), nil, "unshifted")
  eq(history.roll(dense, { 30, 40, 50, 60, 70 }, 4, 75, before), nil, "skipped a sample")
end)

test("roll falls back when the history length changed", function()
  local dense = history.densify({ 10, 20, 30 }, 2, 35)
  eq(history.roll(dense, { 20, 30, 40, 50 }, 2, 55), nil, "mismatched count")
end)

test("roll matches densify for a short padded history", function()
  local dense = history.densify({ 0, 0, 10 }, 3, 20)
  local rolled = history.roll(dense, { 0, 10, 20 }, 3, 30)
  local fresh = history.densify({ 0, 10, 20 }, 3, 30)
  for index = 1, #fresh do
    near(rolled[index], fresh[index], 0.0001, "point " .. index)
  end
end)

test("dense window handles a single sample", function()
  local dense = history.densify({ 40 }, 2)
  eq(#dense, 3, "dense count")
  local points = history.denseWindow(dense, 2, 1)
  eq(#points, 2, "count")
  near(points[1], 0.4, 0.001, "first")
  near(points[2], 0.4, 0.001, "second")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end

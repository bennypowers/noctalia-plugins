-- Pure-Lua tests for thread-bars/lib/animate.luau.
-- Run from the repository root: lua tests/test_animate.lua

local chunk, loadErr = loadfile("thread-bars/lib/animate.luau")
assert(chunk, loadErr)

local animate = chunk()
assert(type(animate) == "table", "animate module must return a table")

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

local function near(actual, expected, epsilon, label)
  if math.abs(actual - expected) > (epsilon or 0.01) then
    error((label or "value") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function eq(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

test("eases toward the target", function()
  local display, moving = animate.smooth({ 0 }, { 100 }, 100, 100)
  near(display[1], 63.21, 0.01, "first step")
  eq(moving, true, "moving")
end)

test("keeps easing over successive frames", function()
  local display = { 0 }
  for _ = 1, 20 do
    display = animate.smooth(display, { 100 }, 100, 100)
  end
  near(display[1], 100, 0.5, "settled")
end)

test("snaps when the remaining distance is tiny", function()
  local display, moving = animate.smooth({ 99.99 }, { 100 }, 100, 100)
  eq(display[1], 100, "snapped")
  eq(moving, false, "not moving")
end)

test("resets when the core count changes", function()
  local display, moving = animate.smooth({ 50 }, { 10, 20 }, 100, 100)
  eq(#display, 2, "count")
  eq(display[1], 10, "first")
  eq(display[2], 20, "second")
  eq(moving, false, "not moving")
end)

test("clamps absurd frame deltas", function()
  local slow = animate.smooth({ 0 }, { 100 }, 10000, 100)[1]
  local clamped = animate.smooth({ 0 }, { 100 }, 250, 100)[1]
  near(slow, clamped, 0.001, "delta clamp")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end

-- Pure-Lua tests for thread-bars/lib/color.luau.
-- Run from the repository root: lua tests/test_color.lua

local chunk, loadErr = loadfile("thread-bars/lib/color.luau")
assert(chunk, loadErr)

local color = chunk()
assert(type(color) == "table", "color module must return a table")

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
  if math.abs(actual - expected) > (epsilon or 0.01) then
    error((label or "value") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

test("parses opaque hex", function()
  local c = color.parseHex("#ff8000")
  near(c.r, 1.0, 0.001, "r")
  near(c.g, 128 / 255, 0.001, "g")
  near(c.b, 0.0, 0.001, "b")
  near(c.a, 1.0, 0.001, "a")
end)

test("parses hex with alpha", function()
  local c = color.parseHex("#ff80004d")
  near(c.a, 77 / 255, 0.001, "a")
end)

test("formats opaque hex", function()
  eq(color.formatHex({ r = 1, g = 0, b = 0, a = 1 }), "#ff0000", "hex")
end)

test("formats translucent hex", function()
  eq(color.formatHex({ r = 1, g = 0, b = 0, a = 0.3 }), "#ff00004d", "hex")
end)

test("applies sysmon gradient thresholds", function()
  eq(color.gradientFactor(0, 50, 90), 0.0, "idle")
  eq(color.gradientFactor(50, 50, 90), 0.0, "at activity threshold")
  near(color.gradientFactor(70, 50, 90), 0.625, 0.001, "midpoint")
  eq(color.gradientFactor(90, 50, 90), 1.0, "at critical threshold")
  eq(color.gradientFactor(100, 50, 90), 1.0, "above critical")
end)

test("blends foreground to highlight", function()
  local base = color.parseHex("#ffffff")
  local highlight = color.parseHex("#ff0000")
  eq(color.formatHex(color.blend(base, highlight, 0)), "#ffffff", "t=0")
  eq(color.formatHex(color.blend(base, highlight, 1)), "#ff0000", "t=1")
  eq(color.formatHex(color.blend(base, highlight, 0.5)), "#ff8080", "t=0.5")
end)

test("dims track to 30 percent", function()
  eq(color.withAlpha("#ff8000", 0.3), "#ff80004d", "track")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end

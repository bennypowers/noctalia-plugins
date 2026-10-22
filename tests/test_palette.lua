-- Pure-Lua tests for thread-bars/lib/palette.luau.
-- Run from the repository root: lua tests/test_palette.lua

package.preload["./color.luau"] = function()
  return loadfile("thread-bars/lib/color.luau")()
end

local chunk, loadErr = loadfile("thread-bars/lib/palette.luau")
assert(chunk, loadErr)

local palette = chunk()
assert(type(palette) == "table", "palette module must return a table")

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

local seeds = { "#cba6f7", "#89b4fa", "#94e2d5", "#f38ba8" }

test("derives one valid color per core", function()
  local colors = palette.derive(seeds, 48, true)
  eq(#colors, 48, "count")
  for index, hex in ipairs(colors) do
    if not hex:match("^#%x%x%x%x%x%x$") then
      error("color " .. index .. " is not #rrggbb: " .. hex, 2)
    end
  end
end)

test("keeps colors distinct across many cores", function()
  local colors = palette.derive(seeds, 48, true)
  local seen = {}
  for _, hex in ipairs(colors) do
    eq(seen[hex], nil, "duplicate " .. hex)
    seen[hex] = true
  end
end)

test("is deterministic", function()
  local first = palette.derive(seeds, 48, true)
  local second = palette.derive(seeds, 48, true)
  for index = 1, #first do
    eq(second[index], first[index], "color " .. index)
  end
end)

test("uses lighter colors in dark mode", function()
  local dark = palette.derive(seeds, 8, true)
  local light = palette.derive(seeds, 8, false)
  for index = 1, #dark do
    if dark[index] == light[index] then
      error("color " .. index .. " did not adapt to theme mode", 2)
    end
  end
end)

test("falls back when the theme has no accents", function()
  local colors = palette.derive({}, 4, true)
  eq(#colors, 4, "count")
  eq(colors[1]:match("^#%x%x%x%x%x%x$") ~= nil, true, "valid hex")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end

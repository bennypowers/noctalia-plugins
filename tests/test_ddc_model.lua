-- Pure-Lua tests for ddc-dell/lib/model.luau.
-- Run from the repository root: lua tests/test_ddc_model.lua

local chunk, loadErr = loadfile("ddc-dell/lib/model.luau")
assert(chunk, loadErr)

local model = chunk()
assert(type(model) == "table", "model module must return a table")

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

test("parses continuous, simple and complex terse lines", function()
  local output = table.concat({
    "VCP 10 C 48 100",
    "VCP 12 C 75 100",
    "VCP 14 SNC x05",
    "VCP 60 SNC x0f",
    "VCP 62 C 74 100",
    "VCP 8D SNC x00",
    "VCP DC SNC x00",
    "VCP E8 CNC xff xff x00 x19",
    "VCP E9 CNC x00 xff x00 x00",
  }, "\n")
  local values = model.parseGetvcp(output)
  eq(values["10"], 48, "brightness")
  eq(values["12"], 75, "contrast")
  eq(values["14"], 5, "preset")
  eq(values["60"], 15, "input")
  eq(values["62"], 74, "volume")
  eq(values["8d"], 0, "mute")
  eq(values["dc"], 0, "mode")
  eq(values["e8"], 0x19, "pbp sub input (complex low byte)")
  eq(values["e9"], 0, "pbp mode")
end)

test("complex value lives in the sl field, not ml", function()
  local values = model.parseGetvcp("VCP E9 CNC x00 xff x00 x24")
  eq(values["e9"], 0x24, "pbp layout")
end)

test("ignores unsupported-feature notes and error lines", function()
  local output = table.concat({
    "VCP 87 (unsupported)",
    "DDC communication failed",
    "No monitor detected",
    "VCP 10 C 20 100",
  }, "\n")
  local values = model.parseGetvcp(output)
  local count = 0
  for _ in pairs(values) do
    count = count + 1
  end
  eq(count, 1, "only the good line counts")
  eq(values["10"], 20, "brightness")
  eq(values["87"], nil, "unsupported feature ignored")
end)

test("tolerates empty and nil output", function()
  for _, name in ipairs({ "empty", "nil" }) do
    local values = model.parseGetvcp(name == "nil" and nil or "")
    for _ in pairs(values) do
      error(name .. ": expected no values")
    end
  end
end)

test("parses hex tokens with and without the x prefix", function()
  eq(model.fromHex("x05"), 5, "x prefix")
  eq(model.fromHex("19"), 25, "bare hex")
  eq(model.fromHex("x"), nil, "prefix only")
  eq(model.fromHex("nope"), nil, "non-hex")
  eq(model.fromHex(nil), nil, "nil")
end)

test("buildState maps codes to keys and fills -1 for absent features", function()
  local state = model.buildState(model.parseGetvcp("VCP 10 C 48 100\nVCP E9 CNC x00 xff x00 x24"))
  eq(state.ok, true, "ok flag")
  eq(state.brightness, 48, "brightness")
  eq(state.pbp, 0x24, "pbp")
  eq(state.contrast, -1, "absent contrast")
  eq(state.pbpInput, -1, "absent pbp input")
  eq(state.kvm, nil, "kvm is plugin-tracked, never read from the monitor")
end)

test("kvm outputs map the two tracked switch positions", function()
  eq(model.kvmOutputs[1], "USB-C", "off position")
  eq(model.kvmOutputs[2], "Thunderbolt", "on position")
  eq(#model.kvmOutputs, 2, "binary control")
end)

test("labelFor resolves known values and falls back to hex", function()
  eq(model.labelFor(model.inputs, 0x19), "Thunderbolt", "tb input")
  eq(model.labelFor(model.pbpLayouts, 0x24), "50/50", "pbp layout (tooltip fallback)")
  eq(model.labelFor(model.presets, 0x05), "6500K", "preset")
  eq(model.labelFor(model.inputs, 0x42), "0x42", "unknown value")
  eq(model.labelFor(model.inputs, -1), "?", "absent value")
end)

test("indexFor is 0-based and nil for absent values", function()
  eq(model.indexFor(model.inputs, 0x0F), 0, "dp")
  eq(model.indexFor(model.inputs, 0x11), 1, "hdmi")
  eq(model.indexFor(model.inputs, 0x19), 2, "tb")
  eq(model.indexFor(model.pbpLayouts, 0x00), 0, "off")
  eq(model.indexFor(model.pbpLayouts, 0x24), 3, "pbp 50/50")
  eq(model.indexFor(model.pbpLayouts, 0x27), 1, "pbp 20/80")
  eq(model.indexFor(model.pbpLayouts, 0x2A), 4, "pbp 75/25")
  eq(model.indexFor(model.pbpLayouts, 0x21), 6, "pip variant")
end)

test("pbp layout labels match the user-confirmed ratios", function()
  eq(model.labelFor(model.pbpLayouts, 0x24), "50/50", "50/50")
  eq(model.labelFor(model.pbpLayouts, 0x27), "20/80", "20/80")
  eq(model.labelFor(model.pbpLayouts, 0x28), "80/20", "80/20")
  eq(model.labelFor(model.pbpLayouts, 0x29), "¼", "25/75 chip label")
  eq(model.labelFor(model.pbpLayouts, 0x2A), "¾", "75/25 chip label")
end)

test("pip layout labels and glyphs", function()
  eq(model.labelFor(model.pbpLayouts, 0x21), "Top Right (small)", "pip tr confirmed")
  eq(model.labelFor(model.pbpLayouts, 0x22), "Bottom Right (small)", "pip br assumed")
  eq(model.labelFor(model.pbpLayouts, 0x01), "Bottom Left", "pip bl label")
  eq(model.labelFor(model.pbpLayouts, 0x02), "Top Left", "pip tl label")
  local byValue = {}
  for _, option in ipairs(model.pbpLayouts) do
    byValue[option.value] = option
  end
  eq(byValue[0x21].glyph, "picture-in-picture-top", "tr glyph")
  eq(byValue[0x22].glyph, "picture-in-picture", "br glyph")
  eq(byValue[0x01].glyph, nil, "bl has no glyph")
  eq(byValue[0x02].glyph, nil, "tl has no glyph")
  eq(byValue[0x01].tooltip, "Bottom Left (small)", "bl tooltip carries the size")
  eq(byValue[0x02].tooltip, "Top Left (small)", "tl tooltip carries the size")
  eq(model.indexFor(model.inputs, 0x42), nil, "unknown")
end)

test("pbp/pip split tables feed the two panel sections", function()
  eq(#model.pbpRatios, 5, "five pbp ratios")
  eq(#model.pipPositions, 4, "four pip positions")
  eq(#model.pbpLayouts, 10, "merged lookup size")
  eq(model.pbpLayouts[1].value, 0x00, "off leads the merged table")
  eq(model.labelFor(model.pbpLayouts, 0x00), "Off", "off label")
  eq(model.PBP_OFF, 0x00, "off constant")
  -- The merged table is Off plus both groups, in order.
  local i = 2
  for _, option in ipairs(model.pbpRatios) do
    assert(model.pbpLayouts[i] == option, "merged pbp entry " .. i)
    i = i + 1
  end
  for _, option in ipairs(model.pipPositions) do
    assert(model.pbpLayouts[i] == option, "merged pip entry " .. i)
    i = i + 1
  end
end)

test("pbp options are Off plus the five ratios, for the panel's chip row", function()
  eq(#model.pbpOptions, 6, "off plus five ratios")
  eq(model.pbpOptions[1].value, 0x00, "off leads")
  eq(model.pbpOptions[1].label, "Off", "off label")
  for i = 2, #model.pbpOptions do
    assert(model.pbpOptions[i] == model.pbpRatios[i - 1], "pbp option " .. i)
  end
end)

test("clampPercent clamps and rounds to whole percentages", function()
  eq(model.clampPercent(42.4), 42, "round down")
  eq(model.clampPercent(42.6), 43, "round up")
  eq(model.clampPercent(-3), 0, "below range")
  eq(model.clampPercent(150), 100, "above range")
  eq(model.clampPercent("27"), 27, "string number")
  eq(model.clampPercent(nil), 0, "nil")
  eq(model.clampPercent("abc"), 0, "garbage")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)

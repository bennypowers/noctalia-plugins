-- Pure-Lua tests for background-apps/lib/detect.luau.
-- Run from the repository root: lua tests/test_detect.lua

local chunk, loadErr = loadfile("background-apps/lib/detect.luau")
assert(chunk, loadErr)

local detect = chunk()
assert(type(detect) == "table", "detect module must return a table")

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

test("parses gdbus portal output", function()
  local output = "([({'app_id': <'org.example.One'>, 'message': <'Syncing'>}, {'app_id': <'org.example.Two'>, 'message': <''>})],)"
  local apps = detect.parsePortalOutput(output)
  eq(#apps, 2, "count")
  eq(apps[1].appId, "org.example.One", "first app id")
  eq(apps[1].message, "Syncing", "first message")
  eq(apps[2].appId, "org.example.Two", "second app id")
  eq(apps[2].message, "", "empty message")
end)

test("ignores empty gdbus portal output", function()
  local apps = detect.parsePortalOutput("(<@aa{sv} []>,)")
  eq(#apps, 0, "count")
end)

test("parses busctl portal output", function()
  local output = 'a(ss) 2 "org.example.One" "Syncing" "org.example.Two" ""\n'
  local apps = detect.parsePortalOutput(output)
  eq(#apps, 2, "count")
  eq(apps[1].appId, "org.example.One", "first app id")
  eq(apps[1].message, "Syncing", "first message")
  eq(apps[2].appId, "org.example.Two", "second app id")
end)

test("parses flatpak ps application column", function()
  local output = "3945625987\t56049\tapp.zen_browser.zen\torg.freedesktop.Platform\n"
      .. "1479724804\t2860\tde.schmidhuberj.Flare\torg.gnome.Platform\n"
  local ids = detect.parseFlatpakPs(output)
  eq(#ids, 2, "count")
  eq(ids[1], "app.zen_browser.zen", "first id")
  eq(ids[2], "de.schmidhuberj.Flare", "second id")
end)

test("parses and dedupes niri windows", function()
  local output = 'Window ID 1:\n  App ID: "app.zen_browser.zen"\n\n'
      .. 'Window ID 2:\n  App ID: "app.zen_browser.zen"\n\n'
      .. 'Window ID 3:\n  App ID: "kitty"\n'
  local ids = detect.parseNiriWindows(output)
  eq(#ids, 2, "count")
  eq(ids[1], "app.zen_browser.zen", "first id")
  eq(ids[2], "kitty", "second id")
end)

test("subtracts windowed apps from running flatpaks", function()
  local apps = detect.backgroundApps(
    { "app.zen_browser.zen", "de.schmidhuberj.Flare", "org.gnome.World.PikaBackup" },
    { "app.zen_browser.zen" }
  )
  eq(#apps, 2, "count")
  eq(apps[1].appId, "de.schmidhuberj.Flare", "first background app")
  eq(apps[2].appId, "org.gnome.World.PikaBackup", "second background app")
end)

test("parses the unlocalized Name from a desktop entry", function()
  local content = "[Desktop Entry]\nName[de]=Flare\nName=Flare\nIcon=de.schmidhuberj.Flare\n"
  eq(detect.parseDesktopName(content), "Flare", "name")
end)

test("falls back to app id when Name is missing", function()
  eq(detect.parseDesktopName("[Desktop Entry]\nIcon=x\n"), nil, "name")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end

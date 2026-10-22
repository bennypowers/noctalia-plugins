--!nonstrict
-- Detects Freedesktop background apps and publishes them to the plugin's
-- shared state. The widget and panel are pure consumers, so detection runs
-- once even when both are open.

local detect = require("./lib/detect.luau")

local updateInterval = noctalia.getConfig("updateInterval") or 3000

local desktopDirs = {
  "/usr/share/applications/",
  "/var/lib/flatpak/exports/share/applications/",
  noctalia.expandPath("~/.local/share/applications/") .. "/",
  noctalia.expandPath("~/.local/share/flatpak/exports/share/applications/") .. "/",
}

local nameCache = {}
local iconCache = {}
local lastSignature = nil

local function lookupName(appId)
  local cached = nameCache[appId]
  if cached ~= nil then return cached end

  local filename = appId .. ".desktop"
  for _, dir in ipairs(desktopDirs) do
    local name = detect.parseDesktopName(noctalia.readFile(dir .. filename))
    if name and name ~= "" then
      nameCache[appId] = name
      return name
    end
  end

  nameCache[appId] = appId
  return appId
end

local function lookupIcon(appId)
  local cached = iconCache[appId]
  if cached ~= nil then return cached or nil end

  local path = noctalia.appIconPath(appId, 32)
  if path == "" then path = nil end
  iconCache[appId] = path or false
  return path
end

local function publish(list)
  local apps = {}
  for _, app in ipairs(list) do
    local name = lookupName(app.appId)
    local message = app.message or ""
    local tooltip = name
    if message ~= "" then
      tooltip = tooltip .. "\n" .. message
    end
    table.insert(apps, {
      appId = app.appId,
      message = message,
      name = name,
      iconPath = lookupIcon(app.appId),
      tooltip = tooltip,
    })
  end

  table.sort(apps, function(a, b)
    return (a.name or a.appId) < (b.name or b.appId)
  end)

  local parts = {}
  for _, app in ipairs(apps) do
    parts[#parts + 1] = app.appId .. "\1" .. app.message .. "\1" .. (app.iconPath or "")
  end
  local signature = table.concat(parts, "\2")
  if signature == lastSignature then return end
  lastSignature = signature

  noctalia.state.set("apps", apps)
end

local portalArgv = {
  "gdbus", "call", "--session",
  "--dest", "org.freedesktop.background.Monitor",
  "--object-path", "/org/freedesktop/background/monitor",
  "--method", "org.freedesktop.DBus.Properties.Get",
  "org.freedesktop.background.Monitor", "BackgroundApps",
}

-- Calls back with a non-empty list when the portal has apps to report.
local function readPortal(callback)
  if not noctalia.commandExists("gdbus") then
    callback(nil)
    return
  end

  noctalia.runAsync(portalArgv, function(result)
    if result.exitCode ~= 0 then
      callback(nil)
      return
    end
    local apps = detect.parsePortalOutput(result.stdout)
    callback(#apps > 0 and apps or nil)
  end)
end

local function fallbackDetect()
  if not noctalia.commandExists("flatpak") then
    publish({})
    return
  end

  noctalia.runAsync(
    { "flatpak", "ps", "--columns=instance,pid,application,runtime" },
    function(flatpakResult)
      local flatpaks = {}
      if flatpakResult.exitCode == 0 then
        flatpaks = detect.parseFlatpakPs(flatpakResult.stdout)
      end

      if #flatpaks == 0 or not noctalia.commandExists("niri") then
        publish({})
        return
      end

      noctalia.runAsync({ "niri", "msg", "windows" }, function(niriResult)
        local windowed = {}
        if niriResult.exitCode == 0 then
          windowed = detect.parseNiriWindows(niriResult.stdout)
        end
        publish(detect.backgroundApps(flatpaks, windowed))
      end)
    end
  )
end

local function refresh()
  readPortal(function(apps)
    if apps then
      publish(apps)
    else
      fallbackDetect()
    end
  end)
end

noctalia.setUpdateInterval(updateInterval)
publish({})
refresh()

function update()
  refresh()
end

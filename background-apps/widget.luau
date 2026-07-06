local updateInterval = noctalia.getConfig("updateInterval")
local portalWorked = false
local apps = {}

local function parsePortalOutput(output)
  local result = {}
  for block in output:gmatch("{[^}]+}") do
    local appId = block:match("'app_id':%s*<'([^']*)'")
    local message = block:match("'message':%s*<'([^']*)'") or ""
    if appId and appId ~= "" then
      table.insert(result, { appId = appId, message = message })
    end
  end
  return result
end

local function parseFlatpakPs(output)
  local result = {}
  for line in output:gmatch("[^\n]+") do
    local parts = {}
    for p in line:gmatch("%S+") do table.insert(parts, p) end
    if #parts >= 3 then
      table.insert(result, parts[3])
    end
  end
  return result
end

local function parseNiriWindows(output)
  local seen = {}
  local result = {}
  for appId in output:gmatch('App ID:%s*"([^"]+)"') do
    if not seen[appId] then
      seen[appId] = true
      table.insert(result, appId)
    end
  end
  return result
end

local function updateDisplay()
  local count = #apps
  barWidget.setVisible(count > 0)
  if count > 0 then
    barWidget.setGlyph("apps")
    barWidget.setText(tostring(count))
    local tooltip = count .. " background app" .. (count ~= 1 and "s" or "")
    barWidget.setTooltip(tooltip)
  end
  noctalia.state.set("apps", apps)
end

local function fallbackDetect()
  noctalia.runAsync("flatpak ps --columns=instance,pid,application,runtime", function(fpResult)
    local flatpaks = {}
    if fpResult.exitCode == 0 then
      flatpaks = parseFlatpakPs(fpResult.stdout)
    end

    noctalia.runAsync("niri msg windows", function(nResult)
      local windowed = {}
      if nResult.exitCode == 0 then
        windowed = parseNiriWindows(nResult.stdout)
      end

      local windowSet = {}
      for _, id in ipairs(windowed) do windowSet[id] = true end

      apps = {}
      for _, id in ipairs(flatpaks) do
        if not windowSet[id] then
          table.insert(apps, { appId = id, message = "" })
        end
      end
      updateDisplay()
    end)
  end)
end

local function refresh()
  if portalWorked then
    noctalia.runAsync("gdbus call --session --dest org.freedesktop.background.Monitor --object-path /org/freedesktop/background/monitor --method org.freedesktop.DBus.Properties.Get org.freedesktop.background.Monitor BackgroundApps", function(result)
      if result.exitCode == 0 and result.stdout ~= "" then
        local parsed = parsePortalOutput(result.stdout)
        if #parsed > 0 then
          apps = parsed
          updateDisplay()
          return
        end
      end
      portalWorked = false
      fallbackDetect()
    end)
  else
    fallbackDetect()
  end
end

local function initialDetect()
  noctalia.runAsync("gdbus call --session --dest org.freedesktop.background.Monitor --object-path /org/freedesktop/background/monitor --method org.freedesktop.DBus.Properties.Get org.freedesktop.background.Monitor BackgroundApps", function(result)
    if result.exitCode == 0 and result.stdout ~= "" then
      local parsed = parsePortalOutput(result.stdout)
      if #parsed > 0 then
        portalWorked = true
        apps = parsed
        updateDisplay()
        return
      end
    end
    fallbackDetect()
  end)
end

barWidget.setGlyph("apps")
barWidget.setVisible(false)
initialDetect()

function update()
  noctalia.setUpdateInterval(updateInterval)
  refresh()
end

function onClick()
  noctalia.togglePanel("bennypowers/background-apps:list")
end

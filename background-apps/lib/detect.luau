--!nonstrict
-- Pure parsing helpers for the background-apps detector. Kept free of the
-- noctalia/ui globals so they can be exercised by tests/test_detect.lua.

local M = {}

local function trim(value)
  if value == nil then return nil end
  if type(value) == "string" then
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
  end
  return value
end

local function addUnique(list, seen, value)
  if value and value ~= "" and not seen[value] then
    seen[value] = true
    table.insert(list, value)
  end
end

-- Parses the result of either
--   gdbus call ... org.freedesktop.background.Monitor BackgroundApps
-- or
--   busctl --user get-property ... BackgroundApps
-- Both serialize an `a(ss)` of (app_id, message) pairs.
function M.parsePortalOutput(output)
  local result = {}
  local seen = {}

  for block in output:gmatch("{[^}]+}") do
    local appId = block:match("'app_id':%s*<'([^']*)'") or block:match('"app_id":%s*"([^"]*)"')
    local message = block:match("'message':%s*<'([^']*)'") or block:match('"message":%s*"([^"]*)"') or ""
    if appId and appId ~= "" and not seen[appId] then
      seen[appId] = true
      table.insert(result, { appId = appId, message = message })
    end
  end

  if #result == 0 then
    local body = output:match("^a%(ss%)%s*%d+%s*(.*)$") or output:match("^a%(ss%)%s*(.*)$")
    if body then
      for appId, message in body:gmatch('"([^"]*)"%s+"([^"]*)"') do
        if appId ~= "" and not seen[appId] then
          seen[appId] = true
          table.insert(result, { appId = appId, message = message })
        end
      end
    end
  end

  return result
end

function M.parseFlatpakPs(output)
  local result = {}
  local seen = {}
  for line in output:gmatch("[^\r\n]+") do
    local parts = {}
    for part in line:gmatch("%S+") do table.insert(parts, part) end
    local appId = parts[3]
    if appId ~= "application" then
      addUnique(result, seen, appId)
    end
  end
  return result
end

function M.parseNiriWindows(output)
  local result = {}
  local seen = {}
  for appId in output:gmatch('App ID:%s*"([^"]+)"') do
    addUnique(result, seen, appId)
  end
  return result
end

-- Apps running as Flatpaks without a window are background apps.
function M.backgroundApps(flatpaks, windowed)
  local windowSet = {}
  for _, appId in ipairs(windowed) do windowSet[appId] = true end

  local apps = {}
  local seen = {}
  for _, appId in ipairs(flatpaks) do
    if not windowSet[appId] and appId ~= "" and not seen[appId] then
      seen[appId] = true
      table.insert(apps, { appId = appId, message = "" })
    end
  end
  return apps
end

-- Returns the unlocalized `Name=` value from a desktop entry, or nil.
function M.parseDesktopName(content)
  if not content then return nil end
  local normalized = "\n" .. content:gsub("\r\n", "\n")
  local name = normalized:match("\nName=([^\r\n]+)")
  return trim(name)
end

return M

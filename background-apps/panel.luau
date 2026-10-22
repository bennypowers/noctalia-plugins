local desktopDirs = {
  "/usr/share/applications/",
  "/var/lib/flatpak/exports/share/applications/",
  noctalia.expandPath("~/.local/share/applications/"),
  noctalia.expandPath("~/.local/share/flatpak/exports/share/applications/"),
}

local nameCache = {}

local function lookupAppName(appId)
  if nameCache[appId] then return nameCache[appId] end

  local filename = appId .. ".desktop"
  for _, dir in ipairs(desktopDirs) do
    local content = noctalia.readFile(dir .. filename)
    if content then
      local name = content:match("\nName=([^\n]+)")
      if name then
        nameCache[appId] = noctalia.string.trim(name)
        return nameCache[appId]
      end
    end
  end

  nameCache[appId] = appId
  return appId
end

local function activateApp(appId)
  noctalia.runAsync("gtk-launch '" .. appId:gsub("'", "'\\''") .. "'")
end

local function toArray(t)
  if not t then return {} end
  if #t > 0 then return t end
  local arr = {}
  for _, v in pairs(t) do
    if type(v) == "table" then table.insert(arr, v) end
  end
  return arr
end

local function render(rawApps)
  local apps = toArray(rawApps)
  local children = {}

  table.insert(children, ui.row({ align = "center", justify = "space_between" }, {
    ui.label({ text = "Background Apps", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
    ui.button({ glyph = "x", variant = "ghost", onClick = "onClosePanel" }),
  }))

  if #apps == 0 then
    table.insert(children, ui.label({
      text = "No background apps running",
      fontSize = 14,
      color = "on_surface_variant",
    }))
    panel.render(ui.column({ gap = 12, padding = 16 }, children))
    return
  end

  for i, app in ipairs(apps) do
    local appId = app.appId or app["appId"] or ""
    local msg = app.message or app["message"] or ""
    local name = lookupAppName(appId)

    table.insert(children, ui.row({ gap = 10, align = "center", padding = 4 }, {
      ui.glyph({ name = "app-window", size = 20, color = "on_surface" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = name, fontSize = 14 }),
        msg ~= "" and ui.label({
          text = msg,
          fontSize = 12,
          color = "on_surface_variant",
        }) or ui.spacer({ height = 0 }),
      }),
      ui.button({ glyph = "external-link", variant = "ghost", onClick = "activate_" .. i }),
    }))
  end

  panel.render(ui.scroll({ gap = 8, padding = 16 }, children))
end

noctalia.state.watch("apps", function(apps)
  render(apps)
end)

function onOpen()
  render(noctalia.state.get("apps"))
end

function onClosePanel()
  panel.close()
end

local function activateByIndex(index)
  local apps = noctalia.state.get("apps")
  if apps and apps[index] then
    activateApp(apps[index].appId)
  end
end

function activate_1() activateByIndex(1) end
function activate_2() activateByIndex(2) end
function activate_3() activateByIndex(3) end
function activate_4() activateByIndex(4) end
function activate_5() activateByIndex(5) end
function activate_6() activateByIndex(6) end
function activate_7() activateByIndex(7) end
function activate_8() activateByIndex(8) end
function activate_9() activateByIndex(9) end
function activate_10() activateByIndex(10) end
function activate_11() activateByIndex(11) end
function activate_12() activateByIndex(12) end
function activate_13() activateByIndex(13) end
function activate_14() activateByIndex(14) end
function activate_15() activateByIndex(15) end
function activate_16() activateByIndex(16) end
function activate_17() activateByIndex(17) end
function activate_18() activateByIndex(18) end
function activate_19() activateByIndex(19) end
function activate_20() activateByIndex(20) end

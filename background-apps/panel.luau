--!nonstrict
-- Panel listing background apps, fed by the detector service's shared state.

local apps = {}

local function activate(appId)
  panel.close()
  noctalia.runAsync({ "gtk-launch", appId }, function(result)
    if result.exitCode ~= 0 then
      noctalia.runAsync({ "flatpak", "run", appId })
    end
  end)
end

local function render()
  local children = {}

  table.insert(children, ui.row({ align = "center", justify = "space_between" }, {
    ui.label({
      text = noctalia.tr("title"),
      fontSize = 18,
      fontWeight = "bold",
      flexGrow = 1,
    }),
    ui.button({ glyph = "x", variant = "ghost", onClick = "onClosePanel" }),
  }))

  if #apps == 0 then
    table.insert(children, ui.label({
      text = noctalia.tr("empty"),
      fontSize = 14,
      color = "on_surface_variant",
    }))
    panel.render(ui.column({ gap = 12, padding = 16 }, children))
    return
  end

  for _, app in ipairs(apps) do
    local icon
    if app.iconPath then
      icon = ui.image({
        path = app.iconPath,
        width = 24,
        height = 24,
        fit = "contain",
      })
    else
      icon = ui.glyph({ name = "app-window", size = 20, color = "on_surface" })
    end

    local lines = {
      ui.label({ text = app.name or app.appId, fontSize = 14 }),
    }
    if app.message and app.message ~= "" then
      table.insert(lines, ui.label({
        text = app.message,
        fontSize = 12,
        color = "on_surface_variant",
      }))
    end

    table.insert(children, ui.row({
      key = app.appId,
      gap = 10,
      align = "center",
      padding = 4,
      radius = 8,
      tooltip = app.tooltip or app.name or app.appId,
      onClick = function() activate(app.appId) end,
    }, {
      icon,
      ui.column({ gap = 2, flexGrow = 1 }, lines),
      ui.glyph({ name = "external-link", size = 16, color = "on_surface_variant" }),
    }))
  end

  panel.render(ui.scroll({ gap = 8, padding = 16 }, children))
end

noctalia.state.watch("apps", function(value)
  apps = value or {}
  render()
end)

function onOpen()
  apps = noctalia.state.get("apps") or {}
  render()
end

function onClosePanel()
  panel.close()
end

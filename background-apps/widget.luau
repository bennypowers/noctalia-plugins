--!nonstrict
-- Renders one tray-sized icon per background app. Noctalia's tray widget is
-- SNI-only, and the plugin API cannot register StatusNotifierItems, so this
-- widget mirrors the tray's metrics instead: 16px icons, 4px gaps, one capsule.

local apps = noctalia.state.get("apps") or {}
local hovered = nil
local render

local function openPanel()
  noctalia.togglePanel("bennypowers/background-apps:list")
end

local function item(app)
  local icon
  if app.iconPath then
    icon = ui.image({
      path = app.iconPath,
      width = 16,
      height = 16,
      fit = "contain",
    })
  else
    icon = ui.glyph({ name = "app-window", size = 16 })
  end

  return ui.row({
    key = app.appId,
    width = 16,
    height = 16,
    align = "center",
    justify = "center",
    radius = 4,
    fill = hovered == app.appId and "on_surface/0.12" or nil,
    tooltip = app.tooltip or app.name or app.appId,
    onClick = openPanel,
    onHover = function(state)
      hovered = state == "true" and app.appId or nil
      render()
    end,
  }, { icon })
end

function render()
  if #apps == 0 then
    barWidget.setVisible(false)
    return
  end

  local children = {}
  for _, app in ipairs(apps) do
    table.insert(children, item(app))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 4, align = "center" }, children))
  barWidget.setVisible(true)
end

noctalia.state.watch("apps", function(value)
  apps = value or {}
  hovered = nil
  render()
end)

render()

function onClick()
  openPanel()
end

--!nonstrict
-- Schedule panel: stop details plus every upcoming arrival inside the
-- monitoring window.

local MAX_ROWS = 40

local state = nil
local open = false

local function etaLabel(eta)
  if eta <= 0 then
    return noctalia.tr("common.now")
  end
  return noctalia.tr("common.eta", { count = eta })
end

local function etaColor(eta)
  if eta <= 3 then
    return "primary"
  end
  if eta <= 10 then
    return "on_surface"
  end
  return "tertiary"
end

local function arrivalRows()
  local rows = {}
  local count = #state.arrivals
  if count > MAX_ROWS then
    count = MAX_ROWS
  end
  for index = 1, count do
    local arr = state.arrivals[index]
    local subParts = {}
    if arr.origin ~= "" then
      table.insert(subParts, arr.origin)
    end
    if arr.plate ~= "" then
      table.insert(subParts, arr.plate)
    end
    table.insert(rows, ui.row({
      key = "arrival-" .. index,
      gap = 10,
      padding = 10,
      fill = "surface_container",
      radius = 8,
      align = "center",
    }, {
      ui.label({ text = arr.route, fontSize = 16, fontWeight = "bold", width = 52 }),
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = arr.destination, fontSize = 13, maxLines = 1 }),
        ui.label({
          text = table.concat(subParts, " · "),
          fontSize = 11,
          color = "tertiary",
          maxLines = 1,
        }),
      }),
      ui.label({
        text = etaLabel(arr.eta),
        fontSize = 14,
        fontWeight = "bold",
        color = etaColor(arr.eta),
      }),
    }))
  end
  return rows
end

local function errorView(errorReason, detail)
  local bodyKey
  local action
  if errorReason == "no_stop" then
    bodyKey = "panel.noStop"
    action = ui.button({
      text = noctalia.tr("panel.openSettings"),
      variant = "primary",
      onClick = "openSettings",
    })
  elseif errorReason == "network" then
    bodyKey = "panel.errorNetwork"
    action = ui.button({
      text = noctalia.tr("panel.retry"),
      variant = "primary",
      onClick = "refresh",
    })
  else
    bodyKey = "panel.errorParse"
    action = ui.button({
      text = noctalia.tr("panel.retry"),
      variant = "primary",
      onClick = "refresh",
    })
  end
  local body = noctalia.tr(bodyKey)
  if detail ~= "" then
    body = body .. " (" .. detail .. ")"
  end
  panel.render(ui.column({ gap = 12, padding = 24, align = "center" }, {
    ui.glyph({ name = "bus", size = 24, color = "tertiary" }),
    ui.label({ text = body, maxLines = 4 }),
    action,
  }))
end

local function render()
  if not open then
    return
  end
  if state == nil then
    panel.render(ui.column({ padding = 24, align = "center" }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "tertiary" }),
    }))
    return
  end
  if state.ok == false then
    errorView(state.error or "", state.detail or "")
    return
  end

  local stop = state.stop
  local subParts = {}
  if stop.street ~= "" then
    table.insert(subParts, stop.street)
  end
  if stop.city ~= "" then
    table.insert(subParts, stop.city)
  end
  if stop.code ~= "" then
    table.insert(subParts, noctalia.tr("panel.stop", { code = stop.code }))
  end

  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "bus", size = 18, color = "primary" }),
      ui.label({
        text = stop.name,
        fontSize = 16,
        fontWeight = "bold",
        flexGrow = 1,
        maxLines = 1,
      }),
      ui.button({ glyph = "settings", variant = "ghost", onClick = "openSettings" }),
      ui.button({ glyph = "refresh", variant = "ghost", onClick = "refresh" }),
    }),
    ui.label({
      text = table.concat(subParts, " · "),
      fontSize = 12,
      color = "tertiary",
    }),
  }

  if #state.arrivals == 0 then
    table.insert(children, ui.label({
      text = noctalia.tr("panel.noArrivals"),
      color = "tertiary",
    }))
  else
    table.insert(children, ui.scroll({ flexGrow = 1, gap = 6 }, arrivalRows()))
    table.insert(children, ui.label({
      text = noctalia.tr("panel.updated", {
        time = noctalia.formatTime("{:%H:%M}", math.floor(state.updatedAtMs / 1000)),
      }),
      fontSize = 11,
      color = "tertiary",
    }))
  end

  panel.render(ui.column({ gap = 10, padding = 12 }, children))
end

function refresh()
  noctalia.state.set("transit-refresh", noctalia.nowMs())
end

function openSettings()
  noctalia.openSettings()
end

function onOpen()
  open = true
  render()
  refresh()
end

function onClose()
  open = false
end

state = noctalia.state.get("transit")
noctalia.state.watch("transit", function(value)
  state = value
  render()
end)

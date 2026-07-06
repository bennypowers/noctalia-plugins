local function statusText(data)
  if not data then return "Unknown" end
  local s = data.status or ""
  local text = "Unknown"
  if s:find("OL") then text = "Online"
  elseif s:find("OB") then text = "On Battery"
  end
  if s:find("CHRG") then text = text .. " (Charging)" end
  if s:find("LB") then text = text .. " - LOW" end
  return text
end

local function statusColor(data)
  if not data then return "on_surface_variant" end
  local s = data.status or ""
  if s:find("OB") then return "tertiary" end
  return "primary"
end

local function chargeColor(charge)
  if charge <= 20 then return "error" end
  if charge <= 40 then return "tertiary" end
  return "on_surface"
end

local function infoRow(label, value, color)
  return ui.row({ justify = "space_between" }, {
    ui.label({ text = label, fontSize = 14 }),
    ui.label({ text = value, fontSize = 14, color = color }),
  })
end

local function render(data)
  local children = {}

  table.insert(children, ui.row({ align = "center", justify = "space_between" }, {
    ui.label({ text = "UPS Status", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
    ui.button({ glyph = "x", variant = "ghost", onClick = "onClosePanel" }),
  }))

  if not data then
    table.insert(children, ui.label({
      text = "No UPS data available",
      fontSize = 14,
      color = "on_surface_variant",
    }))
    panel.render(ui.column({ gap = 12, padding = 16 }, children))
    return
  end

  local name = noctalia.getConfig("upsName")
  if name == "" then name = nil end
  if not name then
    name = noctalia.state.get("upsName")
  end
  if name then
    table.insert(children, ui.label({
      text = name,
      fontSize = 12,
      color = "on_surface_variant",
    }))
  end

  local modelParts = {}
  if data.mfr and data.mfr ~= "" then table.insert(modelParts, data.mfr) end
  if data.model and data.model ~= "" then table.insert(modelParts, data.model) end
  if #modelParts > 0 then
    table.insert(children, ui.label({
      text = table.concat(modelParts, " "),
      fontSize = 12,
      color = "on_surface_variant",
    }))
  end

  table.insert(children, ui.separator({}))

  table.insert(children, infoRow("Status", statusText(data), statusColor(data)))

  if data.charge >= 0 then
    table.insert(children, infoRow("Battery", data.charge .. "%", chargeColor(data.charge)))
    table.insert(children, ui.progress({
      progress = data.charge / 100,
      fill = chargeColor(data.charge),
      height = 6,
      radius = 3,
    }))
  end

  if data.load >= 0 then
    table.insert(children, infoRow("Load", string.format("%.0f%%", data.load), "on_surface"))
    table.insert(children, ui.progress({
      progress = data.load / 100,
      height = 6,
      radius = 3,
    }))
  end

  if data.powerDraw >= 0 then
    local prefix = data.powerDrawEstimated and "~" or ""
    table.insert(children, infoRow(
      "Power Draw",
      prefix .. string.format("%.0f", data.powerDraw) .. " W",
      "on_surface"
    ))
  end

  table.insert(children, ui.separator({}))

  if data.inputVoltage >= 0 then
    table.insert(children, infoRow("Input Voltage", string.format("%.1f V", data.inputVoltage), "on_surface"))
  end
  if data.outputVoltage >= 0 then
    table.insert(children, infoRow("Output Voltage", string.format("%.1f V", data.outputVoltage), "on_surface"))
  end
  if data.batteryVoltage >= 0 then
    table.insert(children, infoRow("Battery Voltage", string.format("%.1f V", data.batteryVoltage), "on_surface"))
  end
  if data.temperature >= 0 then
    table.insert(children, infoRow("Temperature", string.format("%.1f \u{00B0}C", data.temperature), "on_surface"))
  end

  panel.render(ui.column({ gap = 10, padding = 16 }, children))
end

noctalia.state.watch("ups", function(data)
  render(data)
end)

function onOpen()
  render(noctalia.state.get("ups"))
end

function onClosePanel()
  panel.close()
end

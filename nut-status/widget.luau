local upsName = noctalia.getConfig("upsName")
local updateInterval = noctalia.getConfig("updateInterval")
local showPowerDraw = noctalia.getConfig("showPowerDraw")
local showBatteryOnlyOnBattery = noctalia.getConfig("showBatteryOnlyOnBattery")
local batteryColor = noctalia.getConfig("batteryColor")
local powerFactor = noctalia.getConfig("powerFactor")

local detectedName = ""
local available = false

local function parseUpsOutput(output)
  local data = {
    charge = -1,
    status = "",
    model = "",
    mfr = "",
    load = -1,
    inputVoltage = -1,
    outputVoltage = -1,
    batteryVoltage = -1,
    temperature = -1,
    powerDraw = -1,
    powerDrawEstimated = false,
  }

  local loadPercent = -1
  local outVoltage = 0
  local outCurrentNominal = 0

  for line in output:gmatch("[^\n]+") do
    local key, value = line:match("^(.-):%s*(.+)$")
    if key and value then
      key = noctalia.string.trim(key)
      value = noctalia.string.trim(value)

      if key == "battery.charge" then
        data.charge = tonumber(value) or -1
      elseif key == "ups.status" then
        data.status = value
      elseif key == "ups.model" then
        data.model = value
      elseif key == "ups.mfr" then
        data.mfr = value
      elseif key == "ups.load" then
        data.load = tonumber(value) or -1
        loadPercent = data.load
      elseif key == "input.voltage" then
        data.inputVoltage = tonumber(value) or -1
      elseif key == "output.voltage" then
        local v = tonumber(value) or -1
        data.outputVoltage = v
        outVoltage = v
      elseif key == "battery.voltage" then
        data.batteryVoltage = tonumber(value) or -1
      elseif key == "ups.temperature" then
        data.temperature = tonumber(value) or -1
      elseif key == "ups.realpower" and data.powerDraw < 0 then
        data.powerDraw = tonumber(value) or -1
      elseif key == "input.realpower" and data.powerDraw < 0 then
        data.powerDraw = tonumber(value) or -1
      elseif key == "output.current.nominal" then
        outCurrentNominal = tonumber(value) or 0
      end
    end
  end

  if data.powerDraw < 0 and loadPercent >= 0 and outVoltage > 0 and outCurrentNominal > 0 then
    local maxVA = outVoltage * outCurrentNominal
    local maxWatts = maxVA * powerFactor
    data.powerDraw = (loadPercent / 100) * maxWatts
    data.powerDrawEstimated = true
  end

  return data
end

local function isOnline(status)
  return status:find("OL") ~= nil
end

local function isOnBattery(status)
  return status:find("OB") ~= nil
end

local function isLowBattery(status)
  return status:find("LB") ~= nil
end

local function isCharging(status)
  return status:find("CHRG") ~= nil
end

local function getBatteryIcon(data)
  if not available then return "battery-off" end
  if isLowBattery(data.status) then return "battery-exclamation" end
  if data.charge < 0 then return "battery-off" end
  if isCharging(data.status) then return "battery-charging" end
  if data.charge <= 20 then return "battery-1" end
  if data.charge <= 40 then return "battery-2" end
  if data.charge <= 60 then return "battery-3" end
  if data.charge <= 80 then return "battery-4" end
  return "battery"
end

local function getStatusColor(data)
  if not available then return "on_surface_variant" end
  if isLowBattery(data.status) then return "error" end
  if isOnBattery(data.status) then
    if batteryColor == "auto" or batteryColor == "tertiary" then return "tertiary" end
    if batteryColor == "warning" then return "#ffb300" end
    if batteryColor == "error" then return "error" end
    if batteryColor == "primary" then return "primary" end
    if batteryColor == "onsurface" then return "on_surface" end
    return "tertiary"
  end
  if data.charge >= 0 and data.charge <= 20 then return "error" end
  if data.charge >= 0 and data.charge <= 40 then return "tertiary" end
  return "on_surface"
end

local function updateDisplay(data)
  local color = getStatusColor(data)
  barWidget.setGlyph(getBatteryIcon(data))
  barWidget.setGlyphColor(color)
  barWidget.setColor(color)

  local parts = {}

  local showCharge = data.charge >= 0
  if showBatteryOnlyOnBattery then
    showCharge = showCharge and isOnBattery(data.status)
  end
  if showCharge then
    table.insert(parts, data.charge .. "%")
  end

  if showPowerDraw and data.powerDraw >= 0 then
    local prefix = data.powerDrawEstimated and "~" or ""
    table.insert(parts, prefix .. string.format("%.0f", data.powerDraw) .. "W")
  end

  if isOnBattery(data.status) and not isCharging(data.status) then
    table.insert(parts, "\u{26A1}")
  end

  barWidget.setText(table.concat(parts, " "))
  barWidget.setVisible(available)

  local tooltip = "UPS: " .. (upsName ~= "" and upsName or detectedName)
  if data.charge >= 0 then
    tooltip = tooltip .. "\nCharge: " .. data.charge .. "%"
  end
  if data.powerDraw >= 0 then
    local prefix = data.powerDrawEstimated and "~" or ""
    tooltip = tooltip .. "\nPower: " .. prefix .. string.format("%.0f", data.powerDraw) .. "W"
  end
  if isOnline(data.status) then
    tooltip = tooltip .. "\nStatus: Online (AC Power)"
  elseif isOnBattery(data.status) then
    tooltip = tooltip .. "\nStatus: On Battery"
  end
  if isCharging(data.status) then
    tooltip = tooltip .. " (Charging)"
  end
  if isLowBattery(data.status) then
    tooltip = tooltip .. "\nLow Battery!"
  end
  barWidget.setTooltip(tooltip)

  noctalia.state.set("ups", data)
end

local function queryUps()
  local name = upsName ~= "" and upsName or detectedName
  if name == "" then return end

  noctalia.runAsync("upsc '" .. name:gsub("'", "'\\''") .. "'", function(result)
    if result.exitCode == 0 and result.stdout ~= "" then
      available = true
      noctalia.state.set("upsName", name)
      updateDisplay(parseUpsOutput(result.stdout))
    else
      available = false
      barWidget.setVisible(false)
    end
  end)
end

local function detectUps()
  noctalia.runAsync("upsc -l", function(result)
    if result.exitCode == 0 and result.stdout ~= "" then
      local firstLine = result.stdout:match("([^\n]+)")
      if firstLine then
        detectedName = noctalia.string.trim(firstLine)
        queryUps()
      end
    end
  end)
end

barWidget.setGlyph("battery-off")
barWidget.setVisible(false)

if upsName == "" then
  detectUps()
else
  queryUps()
end

function update()
  noctalia.setUpdateInterval(updateInterval)
  queryUps()
end

function onClick()
  noctalia.togglePanel("bennypowers/nut-status:details")
end

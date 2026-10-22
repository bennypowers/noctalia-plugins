--!nonstrict
-- Color helpers for the thread-bars widget. These mirror the built-in sysmon
-- gauge: a foreground-to-highlight HSV blend driven by activity/critical
-- thresholds, with a 30% alpha track.

local M = {}

local function clamp01(value)
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

-- Parses #rgb, #rrggbb, or #rrggbbaa into channels in the 0-1 range.
function M.parseHex(hex)
  if type(hex) ~= "string" then return nil end
  hex = hex:gsub("^#", "")
  if #hex == 3 then
    hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  end
  if #hex ~= 6 and #hex ~= 8 then return nil end

  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not (r and g and b) then return nil end

  local a = 1
  if #hex == 8 then
    local alpha = tonumber(hex:sub(7, 8), 16)
    if not alpha then return nil end
    a = alpha / 255
  end

  return { r = r / 255, g = g / 255, b = b / 255, a = a }
end

local function channelHex(value)
  return string.format("%02x", math.floor(clamp01(value) * 255 + 0.5))
end

function M.formatHex(color)
  local alpha = color.a or 1
  if alpha >= 1 then
    return "#" .. channelHex(color.r) .. channelHex(color.g) .. channelHex(color.b)
  end
  return "#"
      .. channelHex(color.r)
      .. channelHex(color.g)
      .. channelHex(color.b)
      .. channelHex(alpha)
end

function M.withAlpha(hex, alpha)
  local color = M.parseHex(hex)
  if not color then return hex end
  color.a = clamp01(alpha)
  return M.formatHex(color)
end

-- Port of the built-in sysmon gradient: no tint at or below the activity
-- threshold, a 25% jump there, then a linear ramp to the highlight at critical.
function M.gradientFactor(value, activityThreshold, criticalThreshold)
  local clamped = math.max(value or 0, 0)
  local critical = math.max(criticalThreshold or 0, 0)
  if critical <= 0 or clamped <= 0 then return 0 end

  local activity = math.min(math.max(activityThreshold or 0, 0), critical)
  if clamped <= activity then return 0 end
  if clamped >= critical then return 1 end

  local t = (clamped - activity) / (critical - activity)
  return 0.25 + 0.75 * t
end

local function rgbToHsv(color)
  local maxChannel = math.max(color.r, color.g, color.b)
  local minChannel = math.min(color.r, color.g, color.b)
  local delta = maxChannel - minChannel

  local v = maxChannel
  if maxChannel <= 1e-6 then
    return 0, 0, 0
  end

  local s = delta / maxChannel
  if delta <= 1e-6 then
    return 0, s, v
  end

  local h
  if maxChannel == color.r then
    h = (color.g - color.b) / delta + (color.g < color.b and 6 or 0)
  elseif maxChannel == color.g then
    h = (color.b - color.r) / delta + 2
  else
    h = (color.r - color.g) / delta + 4
  end

  h = h / 6
  h = h - math.floor(h)
  return h, s, v
end

local function hsvToRgb(h, s, v, a)
  local sector = math.floor(h * 6)
  local f = h * 6 - sector
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)

  sector = sector % 6
  local r, g, b
  if sector == 0 then
    r, g, b = v, t, p
  elseif sector == 1 then
    r, g, b = q, v, p
  elseif sector == 2 then
    r, g, b = p, v, t
  elseif sector == 3 then
    r, g, b = p, q, v
  elseif sector == 4 then
    r, g, b = t, p, v
  else
    r, g, b = v, p, q
  end

  return { r = r, g = g, b = b, a = a }
end

function M.toHsv(color)
  local h, s, v = rgbToHsv(color)
  return { h = h, s = s, v = v, a = color.a or 1 }
end

function M.fromHsv(h, s, v, a)
  return hsvToRgb(h, s, v, a or 1)
end

-- Port of lerpHsvChromaWeighted: low-chroma hues get proportionally less
-- influence, so a near-grey foreground does not drag the highlight's hue.
function M.blend(from, to, t)
  t = clamp01(t)
  local h0, s0, v0 = rgbToHsv(from)
  local h1, s1, v1 = rgbToHsv(to)

  local hDelta = h1 - h0
  if hDelta > 0.5 then
    hDelta = hDelta - 1
  elseif hDelta < -0.5 then
    hDelta = hDelta + 1
  end

  local fromHueWeight = (1 - t) * s0 * v0
  local toHueWeight = t * s1 * v1
  local hueWeightSum = fromHueWeight + toHueWeight
  local hueT = hueWeightSum > 0 and toHueWeight / hueWeightSum or t

  return hsvToRgb(
    h0 + hDelta * hueT,
    s0 + (s1 - s0) * t,
    v0 + (v1 - v0) * t,
    (from.a or 1) + ((to.a or 1) - (from.a or 1)) * t
  )
end

return M

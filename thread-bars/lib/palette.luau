--!nonstrict
-- Derives a large categorical palette from the active theme's accent colors.
-- Golden-angle hue rotation keeps neighboring cores far apart on the wheel;
-- saturation/value cycles keep the sequence readable when the hue wraps.

local color = require("./color.luau")

local M = {}

local GOLDEN_ANGLE = 0.618033988749895

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

-- `seeds` are hex colors from the theme palette. `count` cores get distinct
-- colors; `dark` selects a value range that reads on the current surface.
function M.derive(seeds, count, dark)
  local anchors = {}
  for _, hex in ipairs(seeds or {}) do
    local parsed = color.parseHex(hex)
    if parsed then anchors[#anchors + 1] = color.toHsv(parsed) end
  end

  local baseHue = anchors[1] and anchors[1].h or 0.58
  local saturation = 0.65
  local value = dark and 0.9 or 0.55

  if #anchors > 0 then
    local saturationSum, valueSum = 0, 0
    for _, anchor in ipairs(anchors) do
      saturationSum = saturationSum + anchor.s
      valueSum = valueSum + anchor.v
    end
    saturation = saturationSum / #anchors
    value = valueSum / #anchors
  end

  local saturationMin = dark and 0.5 or 0.45
  local saturationMax = dark and 0.95 or 0.92
  local valueMin = dark and 0.7 or 0.4
  local valueMax = dark and 1.0 or 0.72

  local colors = {}
  for index = 1, math.max(0, math.floor(count or 0)) do
    local hue = (baseHue + (index - 1) * GOLDEN_ANGLE) % 1
    local s = clamp(saturation + (((index - 1) % 5) - 2) * 0.05, saturationMin, saturationMax)
    local v = clamp(value + (((index - 1) % 3) - 1) * 0.06, valueMin, valueMax)
    colors[index] = color.formatHex(color.fromHsv(hue, s, v, 1))
  end

  return colors
end

return M

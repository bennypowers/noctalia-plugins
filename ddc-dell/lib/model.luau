--!nonstrict
-- Option tables and parsers for the U4025QW's DDC/CI features. The E5/E7/E8/
-- E9 codes are Dell-specific and mostly undocumented; the values below are the
-- ones verified on this model (see RESEARCH.md), so unverified layouts are not
-- offered rather than mislabelled.

local M = {}

-- 0x60 / 0xE8 input source. The U4025QW's TB4 upstream reports as 0x19
-- (non-standard; ddcutil prints "Unrecognized value" for it in capabilities).
M.inputs = {
  { value = 0x0F, label = "DisplayPort" },
  { value = 0x11, label = "HDMI" },
  { value = 0x19, label = "Thunderbolt" },
}

M.presets = {
  { value = 0x01, label = "sRGB" },
  { value = 0x04, label = "5000K" },
  { value = 0x05, label = "6500K" },
  { value = 0x06, label = "7500K" },
  { value = 0x08, label = "9300K" },
  { value = 0x09, label = "10000K" },
  { value = 0x0B, label = "User 1" },
  { value = 0x0C, label = "User 2" },
}

M.modes = {
  { value = 0x00, label = "Standard" },
  { value = 0x03, label = "Movie" },
  { value = 0x05, label = "Game" },
}

-- 0xE7 KVM/USB upstream. The control is binary: the momentary action write
-- `E7 0xFF00` toggles the keyboard/mouse between the monitor's two upstream
-- outputs. The register reports no usable state (the value byte stays 0x00,
-- never the advertised 02/03), so the plugin tracks the position in the
-- `ddc` state's `kvm` key instead: 0 or 1, nil until first flipped.
-- Switch semantics (user-specified 2026-11-24): ON = USB routed to
-- Thunderbolt, OFF = USB-C. The key holds the index of the active output
-- in this table, so the switch reads `kvm == 1` (Thunderbolt) as on.
M.kvmOutputs = { "USB-C", "Thunderbolt" }

-- 0xE9 PIP/PBP layout. The firmware advertises ten values; on this model
-- 00/21/24/27/28/29/2A accept writes. 50/50 (0x24) and 20/80 (0x27) are
-- confirmed by a before/after VCP scan on another U4025QW (rabfulton/
-- Dell_U4025QW_Controller); the remaining ratios and 0x21 (PIP top-right,
-- small) were confirmed by the user watching the screen during the
-- 2026-11-05 probe.
--
-- PIP positions: 0x22/0x01/0x02 are advertised but were refused on earlier
-- probes (the ratio refusals of the same session turned out to be transient,
-- so these may still work). Labels follow the user's assumed mapping - small
-- positions continue in code order (BR, BL, TL); the large variants the user
-- expects are not among the advertised values. Verify by clicking and
-- watching the screen.
--
-- Glyphs are Tabler icons (Noctalia's bundled set): the two right corners and
-- the bottom-left have real picture-in-picture icons; the top-left corner only
-- has a corner-arrow icon in the set.
-- PBP split ratios (the OSD's five PBP modes). Every option carries a
-- label (the panel's chips render it next to the glyph); the quarter ratios
-- have no fitting icon in the bundled set, so the ratios read as fraction
-- characters.
M.pbpRatios = {
  { value = 0x27, label = "⅕",  glyph = "layout-sidebar" },
  { value = 0x29, label = "¼", },
  { value = 0x24, label = "½",  glyph = "columns-2" },
  { value = 0x2A, label = "¾", },
  { value = 0x28, label = "⅘",  glyph = "layout-sidebar-right" },
}

-- PIP positions (small inset window). Labels are corner-only so they fit
-- the chips; the tooltips carry the full "(small)" text.
M.pipPositions = {
  { value = 0x21, label = "Top Right", tooltip = "Top Right (small)", glyph = "picture-in-picture-top" },
  { value = 0x22, label = "Bottom Right", tooltip = "Bottom Right (small)", glyph = "picture-in-picture" },
  { value = 0x01, label = "Bottom Left", tooltip = "Bottom Left (small)" },
  { value = 0x02, label = "Top Left", tooltip = "Top Left (small)" },
}

-- The PBP layout that means "PIP/PBP off".
M.PBP_OFF = 0x00

-- The video swap (the `swap` backend action) exchanges the main (0x60) and
-- sub (0xE8) inputs; no VCP reports the resulting orientation, so the panel
-- tracks the position in the shared `ddc` state's `swapped` key (bool) and
-- the service carries it through polls, exactly like the KVM position.

-- Off plus both groups: the full lookup for labelFor/indexFor.
M.pbpLayouts = { { value = M.PBP_OFF, label = "Off" } }
for _, option in ipairs(M.pbpRatios) do
  M.pbpLayouts[#M.pbpLayouts + 1] = option
end
for _, option in ipairs(M.pipPositions) do
  M.pbpLayouts[#M.pbpLayouts + 1] = option
end

-- The panel's PBP chip row: Off plus the five ratios, one row (the section
-- header no longer carries an on/off toggle, so Off is a chip).
M.pbpOptions = { M.pbpLayouts[1] }
for _, option in ipairs(M.pbpRatios) do
  M.pbpOptions[#M.pbpOptions + 1] = option
end

-- VCP code -> state key, in the order the backend's `state` may report them.
M.stateKeys = {
  { code = "10", key = "brightness" },
  { code = "12", key = "contrast" },
  { code = "14", key = "preset" },
  { code = "60", key = "input" },
  { code = "62", key = "volume" },
  { code = "8d", key = "mute" },
  { code = "dc", key = "mode" },
  { code = "e8", key = "pbpInput" },
  { code = "e9", key = "pbp" },
}

-- Label for a value in an options table (falling back to its tooltip text);
-- raw hex when unknown, "?" for -1.
function M.labelFor(options, value)
  for _, option in ipairs(options or {}) do
    if option.value == value then
      return option.label or option.tooltip
    end
  end
  if value == nil then
    return "?"
  end
  return value < 0 and "?" or string.format("0x%02X", value)
end

-- 0-based index of a value in an options table, or nil when absent.
function M.indexFor(options, value)
  for index, option in ipairs(options or {}) do
    if option.value == value then
      return index - 1
    end
  end
  return nil
end

-- Clamp a slider value to a whole percentage.
function M.clampPercent(value)
  local n = tonumber(value)
  if not n or n ~= n then
    return 0
  end
  return math.max(0, math.min(100, math.floor(n + 0.5)))
end

-- Parse an "x05"/"05" hex token (as printed by ddcutil --terse).
function M.fromHex(token)
  local hex = tostring(token or ""):match("^x?([%x]+)$")
  if not hex or hex == "" then
    return nil
  end
  return tonumber(hex, 16)
end

-- Parse `ddcutil --terse getvcp` output into { [lowercase code] = value }:
--   "VCP 10 C 48 100"          continuous: current max
--   "VCP 14 SNC x05"           simple non-continuous: value
--   "VCP E9 CNC x00 xff x00 x00" complex: mh ml sh sl -- the value lives in sl
-- Anything else (unsupported-feature notes, errors) is ignored.
function M.parseGetvcp(output)
  local values = {}
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local tokens = {}
    for token in line:gmatch("%S+") do
      tokens[#tokens + 1] = token
    end
    if tokens[1] == "VCP" and tokens[2] and tokens[3] then
      local value
      if tokens[3] == "C" then
        value = tonumber(tokens[4])
      elseif tokens[3] == "SNC" then
        value = M.fromHex(tokens[4])
      elseif tokens[3] == "CNC" then
        value = M.fromHex(tokens[7])
      end
      if value ~= nil then
        values[tokens[2]:lower()] = value
      end
    end
  end
  return values
end

-- Turn parsed VCP values into the state table the entries consume; absent
-- features read as -1.
function M.buildState(values)
  local state = { ok = true }
  for _, entry in ipairs(M.stateKeys) do
    state[entry.key] = values[entry.code] or -1
  end
  return state
end

return M

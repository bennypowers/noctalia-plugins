local template = noctalia.getConfig("template")
local city = noctalia.getConfig("city")
local israeli = noctalia.getConfig("israeli")
local language = noctalia.getConfig("language")

local hebrewDay = ""
local hebrewMonth = ""
local hebrewYear = ""
local hebrewWeekday = ""

local ones = {"א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"}
local tens = {"י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"}

local monthToHebrew = {
  Nisan = "ניסן", Iyyar = "אייר", Sivan = "סיוון", Tammuz = "תמוז",
  Av = "אב", Elul = "אלול", Tishrei = "תשרי", Cheshvan = "חשוון",
  Kislev = "כסלו", Tevet = "טבת", Shvat = "שבט", Adar = "אדר",
  Adar1 = "אדר א׳", Adar2 = "אדר ב׳",
}

local weekdayToHebrew = {
  Sun = "א", Mon = "ב", Tue = "ג", Wed = "ד", Thu = "ה", Fri = "ו", Sat = "שבת",
}

local function toHebrewNumeral(num)
  if num < 1 then return "" end
  if num == 15 then return "ט״ו" end
  if num == 16 then return "ט״ז" end

  local result = ""
  local h = math.floor(num / 100) * 100
  while h >= 100 do
    if h >= 400 then result = result .. "ת"; h = h - 400
    elseif h >= 300 then result = result .. "ש"; h = h - 300
    elseif h >= 200 then result = result .. "ר"; h = h - 200
    else result = result .. "ק"; h = h - 100 end
  end

  local t = math.floor((num % 100) / 10)
  local o = num % 10
  if t > 0 and t <= #tens then result = result .. tens[t] end
  if o > 0 and o <= #ones then result = result .. ones[o] end

  local len = utf8.len(result) or 0
  if len == 1 then
    result = result .. "׳"
  elseif len > 1 then
    local chars = {}
    for _, c in utf8.codes(result) do table.insert(chars, utf8.char(c)) end
    local last = table.remove(chars)
    table.insert(chars, "״")
    table.insert(chars, last)
    result = table.concat(chars)
  end

  return result
end

local function yearToHebrew(yearNum)
  return "ה׳" .. yearNum
end

local function hasHebrew(str)
  for _, c in utf8.codes(str) do
    if c >= 0x0590 and c <= 0x05FF then return true end
  end
  return false
end

local function parseHebrewDate(output)
  if hasHebrew(output) then
    local parts = {}
    for part in output:gmatch("%S+") do table.insert(parts, part) end
    if #parts >= 4 then
      local weekdayEn = parts[1]:gsub(",", "")
      hebrewWeekday = weekdayToHebrew[weekdayEn] or weekdayEn
      hebrewDay = parts[2]
      hebrewMonth = parts[3]
      hebrewYear = parts[4]
    end
  else
    local wd, day, month, year = output:match("(%w+),%s+(%d+)%w*%s+of%s+(%w+%s*%w*),%s+(%d+)")
    if wd and day and month and year then
      hebrewWeekday = weekdayToHebrew[wd] or wd
      hebrewDay = toHebrewNumeral(tonumber(day))
      hebrewMonth = monthToHebrew[noctalia.string.trim(month)] or noctalia.string.trim(month)
      hebrewYear = yearToHebrew(year)
    end
  end
end

local function formatDate()
  local result = template
  result = result:gsub("{day}", hebrewDay)
  result = result:gsub("{month}", hebrewMonth)
  result = result:gsub("{year}", hebrewYear)
  result = result:gsub("{weekday}", hebrewWeekday)
  return result
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function buildCommand()
  local cmd = "hebcal --lang " .. language
  if city and city ~= "" then
    cmd = cmd .. " --city " .. shellQuote(city)
  end
  if israeli then cmd = cmd .. " -i" end
  cmd = cmd .. " -w -T | head -1"
  return cmd
end

local function refresh()
  noctalia.runAsync(buildCommand(), function(result)
    if result.exitCode == 0 and result.stdout ~= "" then
      local line = noctalia.string.trim(result.stdout:match("[^\n]+") or "")
      if line ~= "" then
        parseHebrewDate(line)
        barWidget.setText(formatDate())
        barWidget.setTooltip(hebrewDay .. " " .. hebrewMonth .. " " .. hebrewYear)
      end
    end
  end)
end

barWidget.setGlyph("calendar")
refresh()

function update()
  noctalia.setUpdateInterval(3600000)
  refresh()
end

function onClick()
  noctalia.togglePanel("bennypowers/hebrew-calendar:calendar")
end

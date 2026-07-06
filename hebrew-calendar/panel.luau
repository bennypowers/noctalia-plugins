local city = noctalia.getConfig("city")
local israeli = noctalia.getConfig("israeli")
local language = noctalia.getConfig("language")

local currentDay = 1
local currentMonth = ""
local currentYear = 0
local currentWeekday = ""
local monthLength = 29
local firstDayOfWeek = 0
local omerDay = 0
local dafYomi = ""
local zmanimList = {}
local parsha = ""
local candleLighting = ""
local havdalah = ""
local pendingLoads = 0

local ones = {"א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"}
local tens = {"י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"}

local monthLengths = {
  ["ניסן"] = 30, ["אייר"] = 29, ["סיוון"] = 30, ["תמוז"] = 29,
  ["אב"] = 30, ["אלול"] = 29, ["תשרי"] = 30, ["חשוון"] = 29,
  ["כסלו"] = 30, ["טבת"] = 29, ["שבט"] = 30, ["אדר"] = 29,
}

local monthOrder = {
  "ניסן", "אייר", "סיוון", "תמוז", "אב", "אלול",
  "תשרי", "חשוון", "כסלו", "טבת", "שבט", "אדר",
}

local weekdayNames = {
  ["א"] = "ראשון", ["ב"] = "שני", ["ג"] = "שלישי",
  ["ד"] = "רביעי", ["ה"] = "חמישי", ["ו"] = "שישי", ["ש"] = "שבת",
}

local weekdayMap = { Sun = 0, Mon = 1, Tue = 2, Wed = 3, Thu = 4, Fri = 5, Sat = 6 }
local weekdayHebMap = { Sun = "א", Mon = "ב", Tue = "ג", Wed = "ד", Thu = "ה", Fri = "ו", Sat = "ש" }

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

local function hebrewNumeralToInt(numeral)
  local cleaned = numeral:gsub("[׳״]", "")
  local onesMap = { ["א"]=1,["ב"]=2,["ג"]=3,["ד"]=4,["ה"]=5,["ו"]=6,["ז"]=7,["ח"]=8,["ט"]=9 }
  local tensMap = { ["י"]=10,["כ"]=20,["ל"]=30,["מ"]=40,["נ"]=50,["ס"]=60,["ע"]=70,["פ"]=80,["צ"]=90 }
  local hundredsMap = { ["ק"]=100,["ר"]=200,["ש"]=300,["ת"]=400 }
  local total = 0
  for _, c in utf8.codes(cleaned) do
    local ch = utf8.char(c)
    total = total + (hundredsMap[ch] or tensMap[ch] or onesMap[ch] or 0)
  end
  return total > 0 and total or 1
end

local function prevMonthLength(month)
  for i, m in ipairs(monthOrder) do
    if m == month then
      local prev = ((i - 2) % #monthOrder) + 1
      return monthLengths[monthOrder[prev]] or 29
    end
  end
  return 29
end

local function parseCurrentDate(output)
  for line in output:gmatch("[^\n]+") do
    line = noctalia.string.trim(line)
    if line:find("עומר") or line:find("Omer") then
      for part in line:gmatch("%S+") do
        if part == "בעומר" then break end
        omerDay = hebrewNumeralToInt(part)
      end
      local m = line:match("(%d+)%w*%s+day%s+of%s+the%s+Omer")
      if m then omerDay = tonumber(m) or 0 end
    else
      local parts = {}
      for p in line:gmatch("%S+") do table.insert(parts, p) end
      if #parts >= 4 then
        local wd = parts[1]:gsub(",", "")
        local dow = weekdayMap[wd] or 0
        currentWeekday = weekdayHebMap[wd] or "א"
        local dayStr = parts[2]:gsub(",", "")
        currentDay = hebrewNumeralToInt(dayStr)
        currentMonth = parts[3]
        currentYear = hebrewNumeralToInt(parts[4])
        monthLength = monthLengths[currentMonth] or 29
        firstDayOfWeek = (dow - (currentDay - 1) % 7 + 7) % 7
      end
    end
  end
end

local function parseZmanim(output)
  zmanimList = {}
  local nowMinutes = tonumber(noctalia.formatTime("%H")) * 60 + tonumber(noctalia.formatTime("%M"))
  for line in output:gmatch("[^\n]+") do
    line = noctalia.string.trim(line)
    local dateEnd = line:find(" ")
    if dateEnd then
      local content = line:sub(dateEnd + 1)
      local colonIdx = content:find(":")
      if colonIdx then
        local name = content:sub(1, colonIdx - 1)
        local time = noctalia.string.trim(content:sub(colonIdx + 1))
        local h, m = time:match("(%d+):(%d+)")
        local mins = 0
        if h and m then mins = tonumber(h) * 60 + tonumber(m) end
        table.insert(zmanimList, { name = name, time = time, minutes = mins })
      end
    end
  end

  local nextIdx = -1
  for i, z in ipairs(zmanimList) do
    if z.minutes > nowMinutes then nextIdx = i; break end
  end
  for i, z in ipairs(zmanimList) do
    if nextIdx == -1 or i < nextIdx then z.status = "passed"
    elseif i == nextIdx then z.status = "next"
    else z.status = "upcoming" end
  end
end

local function parseDafYomi(output)
  for line in output:gmatch("[^\n]+") do
    line = noctalia.string.trim(line)
    if line:find("דף") then
      local dateEnd = line:find(" ")
      if dateEnd then dafYomi = line:sub(dateEnd + 1) end
      return
    end
  end
end

local function parseWeeklyData(output)
  parsha = ""
  candleLighting = ""
  havdalah = ""
  local today = noctalia.formatTime("%m/%d/%Y")
  local todayM, todayD, todayY = today:match("(%d+)/(%d+)/(%d+)")
  local todayNum = (tonumber(todayY) or 0) * 10000 + (tonumber(todayM) or 0) * 100 + (tonumber(todayD) or 0)

  for line in output:gmatch("[^\n]+") do
    line = noctalia.string.trim(line)
    local lm, ld, ly = line:match("^(%d+)/(%d+)/(%d+)")
    if lm and ld and ly then
      local lineNum = (tonumber(ly) or 0) * 10000 + (tonumber(lm) or 0) * 100 + (tonumber(ld) or 0)
      if lineNum >= todayNum then
        if candleLighting == "" and line:find("הדלקת נרות") then
          local parts = {}
          for p in line:gmatch("[^:]+") do table.insert(parts, p) end
          if #parts >= 2 then
            candleLighting = noctalia.string.trim(parts[#parts - 1] .. ":" .. parts[#parts])
          end
        end
        if parsha == "" and line:find("פרשת") then
          local idx = line:find("פרשת")
          if idx then parsha = line:sub(idx) end
        end
        if havdalah == "" and line:find("הבדלה") then
          local parts = {}
          for p in line:gmatch("[^:]+") do table.insert(parts, p) end
          if #parts >= 2 then
            havdalah = noctalia.string.trim(parts[#parts - 1] .. ":" .. parts[#parts])
          end
        end
      end
    end
  end
end

local function omerText()
  if omerDay <= 0 then return "" end
  local text = toHebrewNumeral(omerDay) .. " לעומר"
  local weeks = math.floor(omerDay / 7)
  local days = omerDay % 7
  if weeks > 0 then
    text = text .. "  \u{00B7}  "
    text = text .. toHebrewNumeral(weeks) .. " " .. (weeks == 1 and "שבוע" or "שבועות")
    if days > 0 then
      text = text .. " ו" .. toHebrewNumeral(days) .. " " .. (days == 1 and "יום" or "ימים")
    end
  end
  return text
end

local function buildHeaderSection()
  local headerChildren = {}

  table.insert(headerChildren, ui.row({ align = "center", gap = 8 }, {
    ui.label({
      text = toHebrewNumeral(currentDay),
      fontSize = 36,
      fontWeight = "bold",
      color = "on_primary",
    }),
    ui.column({ gap = 0 }, {
      ui.row({ gap = 6 }, {
        ui.label({
          text = currentMonth,
          fontSize = 20,
          fontWeight = "bold",
          color = "on_primary",
        }),
        ui.label({
          text = toHebrewNumeral(currentYear % 1000),
          fontSize = 14,
          fontWeight = "bold",
          color = "on_primary",
          opacity = 0.7,
        }),
      }),
      ui.row({ gap = 6 }, {
        ui.label({
          text = "יום " .. (weekdayNames[currentWeekday] or currentWeekday),
          fontSize = 14,
          color = "on_primary",
        }),
        dafYomi ~= "" and ui.label({
          text = dafYomi,
          fontSize = 11,
          color = "on_primary",
          opacity = 0.7,
        }) or ui.spacer({ width = 0 }),
      }),
    }),
    ui.spacer({ flexGrow = 1 }),
  }))

  if omerDay > 0 then
    table.insert(headerChildren, ui.label({
      text = omerText(),
      fontSize = 12,
      color = "on_primary",
      opacity = 0.85,
    }))
  end

  return ui.column({
    gap = 4,
    padding = 16,
    fill = "primary",
    radius = 12,
  }, headerChildren)
end

local function buildCalendarSection()
  local children = {}

  table.insert(children, ui.row({ gap = 4, align = "center" }, {
    ui.label({
      text = currentMonth .. " " .. toHebrewNumeral(currentYear % 1000),
      fontSize = 14,
      fontWeight = "bold",
    }),
    ui.spacer({ flexGrow = 1 }),
  }))

  local dayNames = {"ש", "ו", "ה", "ד", "ג", "ב", "א"}
  local dayLabels = {}
  for _, d in ipairs(dayNames) do
    table.insert(dayLabels, ui.label({
      text = d,
      fontSize = 12,
      fontWeight = "bold",
      color = "primary",
      width = 36,
      textAlign = "center",
    }))
  end
  table.insert(children, ui.row({ gap = 2, justify = "space_between" }, dayLabels))

  local days = {}
  local prevLen = prevMonthLength(currentMonth)
  for i = firstDayOfWeek - 1, 0, -1 do
    table.insert(days, { day = prevLen - i, current = false, today = false })
  end
  for d = 1, monthLength do
    table.insert(days, { day = d, current = true, today = (d == currentDay) })
  end
  local leftover = #days % 7
  if leftover > 0 then
    for d = 1, 7 - leftover do
      table.insert(days, { day = d, current = false, today = false })
    end
  end

  for week = 0, math.floor((#days - 1) / 7) do
    local cells = {}
    for col = 6, 0, -1 do
      local idx = week * 7 + col + 1
      local d = days[idx]
      if d then
        local color = "on_surface"
        local bg = nil
        if d.today then color = "on_secondary"; bg = "secondary" end
        if not d.current then color = "on_surface_variant" end
        local opacity = d.current and 1.0 or 0.4

        table.insert(cells, ui.box({
          width = 36, height = 32, radius = 8,
          fill = bg,
          onClick = nil,
        }, {
          ui.label({
            text = toHebrewNumeral(d.day),
            fontSize = 13,
            fontWeight = d.today and "bold" or "medium",
            color = color,
            opacity = opacity,
            textAlign = "center",
          }),
        }))
      end
    end
    table.insert(children, ui.row({ gap = 2, justify = "space_between" }, cells))
  end

  return ui.column({ gap = 4, padding = 12, fill = "surface_variant", radius = 12 }, children)
end

local function buildZmanimSection()
  if #zmanimList == 0 then return nil end
  local children = {}
  table.insert(children, ui.label({
    text = "זמנים",
    fontSize = 14,
    fontWeight = "bold",
  }))

  for i, z in ipairs(zmanimList) do
    local color = "on_surface"
    local opacity = 1.0
    if z.status == "passed" then opacity = 0.5
    elseif z.status == "next" then color = "primary" end

    local bg = (i % 2 == 0) and "surface_variant" or nil
    table.insert(children, ui.row({
      justify = "space_between",
      padding = 4,
      fill = bg,
      radius = 4,
    }, {
      ui.label({ text = z.name, fontSize = 13, color = color, opacity = opacity }),
      ui.label({ text = z.time, fontSize = 13, color = color, opacity = opacity }),
    }))
  end

  return ui.scroll({ gap = 2, maxHeight = 200, radius = 8 }, children)
end

local function buildShabbatSection()
  if parsha == "" and candleLighting == "" then return nil end
  local children = {}

  table.insert(children, ui.row({ gap = 6, align = "center" }, {
    ui.label({ text = "\u{1F56F}\u{FE0F}", fontSize = 16 }),
    ui.label({
      text = "שבת שלום",
      fontSize = 14,
      fontWeight = "bold",
    }),
  }))

  if parsha ~= "" then
    table.insert(children, ui.label({ text = parsha, fontSize = 13, color = "on_surface" }))
  end
  if candleLighting ~= "" then
    table.insert(children, ui.row({ justify = "space_between" }, {
      ui.label({ text = "הדלקת נרות", fontSize = 13 }),
      ui.label({ text = candleLighting, fontSize = 13, color = "primary" }),
    }))
  end
  if havdalah ~= "" then
    table.insert(children, ui.row({ justify = "space_between" }, {
      ui.label({ text = "הבדלה", fontSize = 13 }),
      ui.label({ text = havdalah, fontSize = 13, color = "primary" }),
    }))
  end

  return ui.column({ gap = 6, padding = 12, fill = "surface_variant", radius = 12 }, children)
end

local function render()
  local sections = {}

  table.insert(sections, ui.row({ justify = "space_between", align = "center" }, {
    ui.spacer({ flexGrow = 1 }),
    ui.button({ glyph = "x", variant = "ghost", onClick = "onClosePanel" }),
  }))

  table.insert(sections, buildHeaderSection())
  table.insert(sections, buildCalendarSection())

  local zmanim = buildZmanimSection()
  if zmanim then table.insert(sections, zmanim) end

  local shabbat = buildShabbatSection()
  if shabbat then table.insert(sections, shabbat) end

  panel.render(ui.scroll({ gap = 12, padding = 12 }, sections))
end

local function maybeRender()
  pendingLoads = pendingLoads - 1
  if pendingLoads <= 0 then render() end
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function loadData()
  pendingLoads = 4

  local baseCmd = "hebcal --lang " .. language
  local cityFlag = ""
  if city and city ~= "" then cityFlag = " --city " .. shellQuote(city) end
  local iFlag = israeli and " -i" or ""

  noctalia.runAsync(baseCmd .. " -o -T -w", function(r)
    if r.exitCode == 0 then parseCurrentDate(r.stdout) end
    maybeRender()
  end)

  noctalia.runAsync(baseCmd .. cityFlag .. iFlag .. " -c -Z --24hour --today", function(r)
    if r.exitCode == 0 then parseZmanim(r.stdout) end
    maybeRender()
  end)

  noctalia.runAsync(baseCmd .. " -F --today", function(r)
    if r.exitCode == 0 then parseDafYomi(r.stdout) end
    maybeRender()
  end)

  noctalia.runAsync(baseCmd .. cityFlag .. iFlag .. " -c -s | head -30", function(r)
    if r.exitCode == 0 then parseWeeklyData(r.stdout) end
    maybeRender()
  end)
end

function onOpen()
  pendingLoads = 0
  panel.render(ui.column({ padding = 16, align = "center" }, {
    ui.label({ text = "Loading...", fontSize = 14, color = "on_surface_variant" }),
  }))
  loadData()
end

function onClosePanel()
  panel.close()
end

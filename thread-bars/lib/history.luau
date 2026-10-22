--!nonstrict
-- Rolling per-core sample history for the details graph.

local M = {}

-- Returns a copy with `value` appended, dropping the oldest point at capacity.
function M.push(values, value, capacity)
  capacity = math.max(1, math.floor(capacity or 1))
  local out = {}
  local first = #values + 1 > capacity and #values + 2 - capacity or 1
  for index = first, #values do
    out[#out + 1] = values[index]
  end
  out[#out + 1] = value
  return out
end

function M.average(values)
  if not values or #values == 0 then return 0 end
  local total = 0
  for _, value in ipairs(values) do total = total + value end
  return total / #values
end

-- True when a window and its lead describe a horizontal line, so scrolling it
-- cannot change any pixel.
function M.isFlat(values, lead)
  if not values or #values == 0 then return false end
  local first = values[1]
  for index = 2, #values do
    if values[index] ~= first then return false end
  end
  return lead == nil or lead == first
end

-- Returns a copy of the newest `length` samples. Retained histories can carry
-- a safety margin beyond the visible window; the graph only draws the tail.
function M.tail(values, length)
  values = values or {}
  length = math.max(0, math.floor(length or 0))
  local count = #values
  local first = count > length and count - length + 1 or 1
  local out = {}
  for index = first, count do out[#out + 1] = values[index] end
  return out
end

-- Pads a short history on the left so the graph's x-axis keeps a fixed span
-- while the buffer fills.
function M.padLeft(values, length, fill)
  local out = {}
  local missing = (length or 0) - #(values or {})
  if missing > 0 then
    for index = 1, missing do out[index] = fill or 0 end
  end
  for _, value in ipairs(values or {}) do out[#out + 1] = value end
  return out
end

local timeCache = {}

local function timeSamples(subdivisions)
  local cached = timeCache[subdivisions]
  if cached then return cached end

  local t1, t2, t3 = {}, {}, {}
  for step = 1, subdivisions do
    local t = (step - 1) / subdivisions
    t1[step] = t
    t2[step] = t * t
    t3[step] = t * t * t
  end
  cached = { t1, t2, t3 }
  timeCache[subdivisions] = cached
  return cached
end

-- Expands a percentage history onto a finer, smoothed grid, appending one
-- extrapolated lead sample. Catmull-Rom passes through every sample while
-- rounding the corners between them; the output is normalized 0-1 so the paint
-- path can copy windows with table.move instead of reshaping values.
function M.densify(values, subdivisions, lead)
  subdivisions = math.max(1, math.floor(subdivisions or 1))
  if not values or #values == 0 then return {} end

  local count = #values
  if count == 1 then
    local value = math.max(0, math.min(100, values[1])) * 0.01
    local out = {}
    for index = 1, subdivisions + 1 do out[index] = value end
    return out
  end

  local newest = values[count]
  local previous = values[count - 1]
  lead = math.max(0, math.min(100, lead or (newest + (newest - previous) * 0.5)))

  local samples = timeSamples(subdivisions)
  local t1, t2, t3 = samples[1], samples[2], samples[3]

  local out = {}
  local length = 0
  for index = 1, count - 1 do
    local p0 = values[index - 1] or values[index]
    local p1 = values[index]
    local p2 = values[index + 1]
    local p3 = values[index + 2] or p2

    -- Hoisted Catmull-Rom coefficients for this segment.
    local a = 2 * p1
    local b = -p0 + p2
    local c = 2 * p0 - 5 * p1 + 4 * p2 - p3
    local d = -p0 + 3 * p1 - 3 * p2 + p3

    for step = 1, subdivisions do
      local value = 0.5 * (a + b * t1[step] + c * t2[step] + d * t3[step])
      if value < 0 then value = 0 elseif value > 100 then value = 100 end
      length = length + 1
      out[length] = value * 0.01
    end
  end

  length = length + 1
  out[length] = newest * 0.01

  local a = 2 * newest
  local b = -values[count - 1] + lead
  local c = 2 * values[count - 1] - 5 * newest + 4 * lead - lead
  local d = -values[count - 1] + 3 * newest - 3 * lead + lead
  for step = 1, subdivisions do
    local t = step / subdivisions
    local t2 = t * t
    local value = 0.5 * (a + b * t + c * t2 + d * t2 * t)
    if value < 0 then value = 0 elseif value > 100 then value = 100 end
    length = length + 1
    out[length] = value * 0.01
  end
  return out
end

-- Rolls a densified history forward by one coarse sample. A shift of the
-- window changes only the first segment (its p0 falls off the front) and the
-- lead, so the interior grid can be copied instead of recomputed. Returns nil
-- when the history length changed and the caller must densify from scratch.
function M.roll(dense, values, subdivisions, lead, previousValues)
  subdivisions = math.max(1, math.floor(subdivisions or 1))
  local count = #(values or {})
  if not dense or count < 3 or #dense ~= count * subdivisions + 1 then return nil end

  -- Only a one-sample shift keeps the interior segments identical. A dropped
  -- sample (or a fresh history) must take the full densify path.
  if previousValues then
    if #previousValues ~= count then return nil end
    for index = 1, count - 1 do
      if values[index] ~= previousValues[index + 1] then return nil end
    end
  end

  local newest = values[count]
  local previous = values[count - 1]
  lead = math.max(0, math.min(100, lead or (newest + (newest - previous) * 0.5)))

  local samples = timeSamples(subdivisions)
  local t1, t2, t3 = samples[1], samples[2], samples[3]

  local out = {}
  local length = 0
  local p0 = values[0] or values[1]
  local p1 = values[1]
  local p2 = values[2]
  local p3 = values[3] or p2

  local a = 2 * p1
  local b = -p0 + p2
  local c = 2 * p0 - 5 * p1 + 4 * p2 - p3
  local d = -p0 + 3 * p1 - 3 * p2 + p3

  for step = 1, subdivisions do
    local value = 0.5 * (a + b * t1[step] + c * t2[step] + d * t3[step])
    if value < 0 then value = 0 elseif value > 100 then value = 100 end
    length = length + 1
    out[length] = value * 0.01
  end

  -- Interior segments 3..count-2 are unchanged, shifted left by one segment.
  -- The old final segment was clamped against the old newest sample, so the
  -- last two segments have to be evaluated.
  local copyFirst = subdivisions * 2 + 1
  local copyLast = (count - 2) * subdivisions
  if copyLast >= copyFirst then
    if table.move then
      table.move(dense, copyFirst, copyLast, length + 1, out)
    else
      for index = copyFirst, copyLast do
        length = length + 1
        out[length] = dense[index]
      end
    end
  end
  length = (count - 3) * subdivisions

  for segment = count - 2, count - 1 do
    p0 = (segment == 1) and (values[0] or values[1]) or values[segment - 1]
    p1 = values[segment]
    p2 = values[segment + 1]
    p3 = values[segment + 2] or p2

    a = 2 * p1
    b = -p0 + p2
    c = 2 * p0 - 5 * p1 + 4 * p2 - p3
    d = -p0 + 3 * p1 - 3 * p2 + p3
    for step = 1, subdivisions do
      local value = 0.5 * (a + b * t1[step] + c * t2[step] + d * t3[step])
      if value < 0 then value = 0 elseif value > 100 then value = 100 end
      length = length + 1
      out[length] = value * 0.01
    end
  end

  length = length + 1
  out[length] = newest * 0.01

  a = 2 * newest
  b = -previous + lead
  c = 2 * previous - 5 * newest + 4 * lead - lead
  d = -previous + 3 * newest - 3 * lead + lead
  for step = 1, subdivisions do
    local t = step / subdivisions
    local t2 = t * t
    local value = 0.5 * (a + b * t + c * t2 + d * t2 * t)
    if value < 0 then value = 0 elseif value > 100 then value = 100 end
    length = length + 1
    out[length] = value * 0.01
  end
  return out
end

-- Returns a fixed-length window of a densified history at an integer grid
-- offset. Because the offset lands on the grid, consecutive frames are exact
-- translations of one another: the old line never changes shape.
function M.denseWindow(dense, subdivisions, offset)
  return M.fillWindow({}, dense, subdivisions, offset)
end

-- In-place variant for the per-frame paint path: reuses one table per series
-- instead of allocating a fresh window on every frame.
function M.fillWindow(target, dense, subdivisions, offset)
  target = target or {}
  if not dense or #dense == 0 then
    target[1], target[2] = 0, 0
    return target
  end

  subdivisions = math.max(1, math.floor(subdivisions or 1))
  local count = math.floor((#dense - 1) / subdivisions)
  if count <= 1 then
    local value = dense[1] or 0
    target[1], target[2] = value, value
    return target
  end

  offset = math.max(0, math.min(subdivisions, math.floor(offset or 0)))
  local length = (count - 1) * subdivisions + 1

  if table.move then
    table.move(dense, offset + 1, offset + length, 1, target)
  else
    for index = 1, length do target[index] = dense[offset + index] end
  end
  for index = #target, length + 1, -1 do target[index] = nil end
  return target
end

-- Returns one rolling history per core. Core indices are not stable when a
-- core goes offline, so a count change starts a fresh history instead of
-- joining points that belong to different cores.
function M.pushCores(histories, cores, capacity)
  if not cores or #cores == 0 then return histories end

  if #histories ~= #cores then
    local reset = {}
    for index, value in ipairs(cores) do
      reset[index] = { value }
    end
    return reset
  end

  local out = {}
  for index, value in ipairs(cores) do
    out[index] = M.push(histories[index] or {}, value, capacity)
  end
  return out
end

return M

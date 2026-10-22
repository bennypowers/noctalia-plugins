--!nonstrict
-- Samples per-core CPU usage once per interval and publishes the current values.
-- The widget animates them; the details panel keeps its own rolling history.

local sampleInterval = noctalia.getConfig("updateInterval") or 1000
local lastCores = nil

local function unchanged(a, b)
  if not b or #a ~= #b then return false end
  for index = 1, #a do
    if a[index] ~= b[index] then return false end
  end
  return true
end

local function sample()
  local cores = noctalia.cpuCores()
  if not cores or #cores == 0 then return end

  local current = {}
  for index, value in ipairs(cores) do
    current[index] = math.max(0, math.min(100, value or 0))
  end

  -- The host samples per-core usage on its own 1 s cadence. Skip a poll that
  -- returns the same sample again so the panel does not append duplicates.
  if unchanged(current, lastCores) then return end
  lastCores = current
  noctalia.state.set("cores", current)
end

noctalia.setUpdateInterval(sampleInterval)
sample()

function update()
  sample()
end

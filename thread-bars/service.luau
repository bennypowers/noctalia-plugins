--!nonstrict
-- Samples per-core CPU usage once per interval and publishes both the current
-- values and a rolling history. The widget animates the values; the details
-- panel draws the history, which keeps recording while the panel is closed.

local history = require("./lib/history.luau")

local sampleInterval = noctalia.getConfig("updateInterval") or 1000
-- The panel draws the newest 30 samples; retain a few extra so trimming never
-- discards a point still on screen.
local RETAIN_SAMPLES = 40

local lastCores = nil
local coreHistory = {}
local overallHistory = {}

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

  -- Append every poll, even an unchanged one: the graph is a time series, so
  -- idle stretches must stay flat instead of disappearing from the window.
  coreHistory = history.pushCores(coreHistory, current, RETAIN_SAMPLES)
  overallHistory = history.push(overallHistory, history.average(current), RETAIN_SAMPLES)
  noctalia.state.set("history", { cores = coreHistory, overall = overallHistory })

  -- The widget only redraws when the values actually change; history still
  -- advances so the panel can show flat idle stretches.
  if unchanged(current, lastCores) then return end
  lastCores = current
  noctalia.state.set("cores", current)
end

noctalia.setUpdateInterval(sampleInterval)
sample()

function update()
  sample()
end

--!nonstrict
-- Samples per-core CPU usage once per interval and publishes both the current
-- values (for the animated bar) and a rolling history (for the details panel).

local history = require("./lib/history.luau")

local sampleInterval = noctalia.getConfig("updateInterval") or 1000
local MAX_SAMPLES = 30

local coreHistory = {}
local overallHistory = {}
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

  -- The host samples per-core usage on its own 1 s cadence. When this service
  -- polls faster, or lands just before the host's update, cpuCores() returns
  -- the same sample again; appending it would double-shift the graph.
  if unchanged(current, lastCores) then return end
  lastCores = current

  coreHistory = history.pushCores(coreHistory, current, MAX_SAMPLES)
  overallHistory = history.push(overallHistory, history.average(current), MAX_SAMPLES)

  noctalia.state.set("cores", current)
  noctalia.state.set("history", {
    cores = coreHistory,
    overall = overallHistory,
    intervalMs = sampleInterval,
  })
end

noctalia.setUpdateInterval(sampleInterval)
sample()

function update()
  sample()
end

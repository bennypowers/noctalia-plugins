--!nonstrict
-- Frame-rate independent easing for the per-core bars. Bar widgets have no
-- frame-tick API, so the widget drives this from a fast update interval.

local M = {}

local SNAP_DISTANCE = 0.05
local MIN_DELTA_MS = 16
local MAX_DELTA_MS = 250

-- Advances `current` toward `target`. Returns the new values and whether any
-- core is still moving. A core-count change resets immediately: offline cores
-- come and go, and easing across a different array length would glitch.
function M.smooth(current, target, dtMs, tauMs)
  if not target then return current, false end

  if not current or #current ~= #target then
    local reset = {}
    for index, value in ipairs(target) do reset[index] = value end
    return reset, false
  end

  local dt = math.min(math.max(dtMs or MIN_DELTA_MS, MIN_DELTA_MS), MAX_DELTA_MS)
  local tau = math.max(tauMs or 100, 1)
  local alpha = 1 - math.exp(-dt / tau)

  local nextValues = {}
  local moving = false
  for index, goal in ipairs(target) do
    local value = current[index]
    if value == nil then value = goal end

    local nextValue = value + (goal - value) * alpha
    if math.abs(goal - nextValue) < SNAP_DISTANCE then
      nextValue = goal
    end
    if nextValue ~= goal then moving = true end
    nextValues[index] = nextValue
  end

  return nextValues, moving
end

return M

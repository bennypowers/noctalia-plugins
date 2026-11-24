--!nonstrict
-- Polls the monitor through the bundled ddc-dell backend and publishes the
-- parsed state for the widget and panel. Writes go straight from the panel to
-- the backend (serialized by its flock); this service only reads.

local model = require("./lib/model.luau")

local monitor = noctalia.getConfig("monitor") or ""
local interval = noctalia.getConfig("updateInterval") or 5000

local backend = noctalia.pluginDir() and noctalia.pluginDir() .. "/ddc-dell" or nil
local haveDdcutil = noctalia.commandExists("ddcutil")
local polling = false

local function argv(subcommand, ...)
  local args = { "sh", backend }
  if monitor ~= "" then
    args[#args + 1] = "--model"
    args[#args + 1] = monitor
  end
  args[#args + 1] = subcommand
  for _, arg in ipairs({ ... }) do
    args[#args + 1] = arg
  end
  return args
end

local function publish(state)
  noctalia.state.set("ddc", state)
end

local function poll()
  if polling or not backend then
    return
  end
  if not haveDdcutil then
    publish({ ok = false, reason = "ddcutil" })
    return
  end

  polling = true
  local accepted = noctalia.runAsync(argv("state"), function(result)
    polling = false
    if result.exitCode ~= 0 then
      publish({ ok = false, reason = "monitor" })
      return
    end
    local fresh = model.buildState(model.parseGetvcp(result.stdout))
    -- The KVM switch position has no readable DDC value (see lib/model.luau):
    -- carry the plugin-tracked position through the poll.
    local previous = noctalia.state.get("ddc")
    if previous and previous.kvm ~= nil then
      fresh.kvm = previous.kvm
    end
    publish(fresh)
  end)
  if not accepted then
    polling = false
  end
end

noctalia.setUpdateInterval(interval)
poll()

function update()
  poll()
end

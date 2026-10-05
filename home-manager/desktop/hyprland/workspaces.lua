local M = {}
local groupSize = 4
local secondary, topology

local function sync(excluded)
  local monitors = hl.get_monitors()
  table.sort(monitors, function(a, b)
    return a.name < b.name
  end)
  local outputs = {}
  for _, monitor in ipairs(monitors) do
    if monitor.name ~= excluded and not monitor.is_mirror then
      outputs[#outputs + 1] = monitor
    end
  end
  local main = outputs[1]
  for _, monitor in ipairs(outputs) do
    if monitor.name == HUIX.primaryMonitor then
      main = monitor
      break
    end
  end
  if not main then
    secondary, topology = nil, nil
    return
  end
  local external
  for _, monitor in ipairs(outputs) do
    if monitor ~= main then
      external = monitor
      break
    end
  end
  local key = main.name .. ":" .. (external and external.name or "")
  if key == topology then
    return
  end
  secondary, topology = external and external.name, key

  for id = 1, groupSize * 2 do
    local firstGroup = id <= groupSize
    local target = firstGroup and main or external or main
    hl.workspace_rule({
      workspace = tostring(id),
      monitor = target.name,
      persistent = firstGroup or external ~= nil,
      default = id == 1 or (id == groupSize + 1 and external ~= nil),
    })
    local workspace = hl.get_workspace(tostring(id))
    if workspace and workspace.monitor ~= target then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = target.name }))
    end
  end
  for _, monitor in ipairs({ main, external }) do
    local first = monitor == main and 1 or groupSize + 1
    local active = monitor.active_workspace
    if not active or not active.id or active.id < first or active.id >= first + groupSize then
      monitor:set_workspace(tostring(first))
    end
  end
end

function M.step(offset, dispatcher, monitor)
  monitor = monitor or hl.get_monitor_at_cursor() or hl.get_active_monitor()
  if not monitor then
    return
  end
  local first = monitor.name == secondary and groupSize + 1 or 1
  local workspace = monitor.active_workspace
  local id = workspace and workspace.id
  if not id or id < first or id >= first + groupSize then
    id = offset > 0 and first - 1 or first
  end
  local target = tostring(first + ((id - first + offset) % groupSize))
  hl.dispatch(dispatcher(target))
end

-- A callback shares the exact cycle with the wheel, even after an output disconnects
function M.swipe(touchscreen)
  local monitor, distance, threshold, invert
  return {
    start = function()
      monitor = hl.get_monitor_at_cursor() or hl.get_active_monitor()
      distance = 0
      threshold = hl.get_config("gestures.workspace_swipe_distance")
        * hl.get_config("gestures.workspace_swipe_cancel_ratio")
      invert =
        hl.get_config(touchscreen and "gestures.workspace_swipe_touch_invert" or "gestures.workspace_swipe_invert")
    end,
    update = function(event)
      distance = distance + event.delta.x
    end,
    finish = function(event)
      if event.cancelled or not monitor or not monitor.name or math.abs(distance) < math.max(2, threshold) then
        return
      end
      local offset = distance > 0 and 1 or -1
      if invert then
        offset = -offset
      end
      M.step(offset, function(target)
        return hl.dsp.focus({ workspace = target })
      end, monitor)
    end,
  }
end

hl.on("monitor.added", function()
  sync()
end)
hl.on("monitor.removed", function(monitor)
  sync(monitor.name)
end)
hl.on("monitor.layout_changed", function()
  sync()
end)
hl.on("hyprland.start", function()
  sync()
end)
hl.on("config.reloaded", function()
  sync()
end)
sync()

return M

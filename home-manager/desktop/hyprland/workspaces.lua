local workspaceCounts = {
  primary = 4,
  secondary = 4,
  tertiary = 1,
}

local groupOrder = { "primary", "secondary", "tertiary" }
local groups, first = {}, 1
for _, role in ipairs(groupOrder) do
  local count = workspaceCounts[role]
  assert(type(count) == "number" and count >= 1 and count % 1 == 0, "Workspace counts must be positive integers")
  groups[role] = { first = first, count = count }
  first = first + count
end

local M = {}
local assigned, topology = {}, nil

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
    assigned, topology = {}, nil
    return
  end

  local available = {}
  for _, monitor in ipairs(outputs) do
    if monitor ~= main then
      available[monitor.name] = monitor
    end
  end

  -- Existing workspace bindings keep a new output from taking another output's group
  local function select(role)
    local monitor = available[assigned[role]]
    if not monitor then
      local group = groups[role]
      for id = group.first, group.first + group.count - 1 do
        local workspace = hl.get_workspace(tostring(id))
        local owner = workspace and workspace.monitor
        if owner and available[owner.name] then
          monitor = available[owner.name]
          break
        end
      end
    end
    if not monitor then
      for _, candidate in ipairs(outputs) do
        if available[candidate.name] then
          monitor = candidate
          break
        end
      end
    end
    if monitor then
      available[monitor.name] = nil
    end
    return monitor
  end

  local selected = { primary = main }
  selected.secondary = select("secondary")
  selected.tertiary = select("tertiary")
  local names = {}
  for _, role in ipairs(groupOrder) do
    names[#names + 1] = selected[role] and selected[role].name or ""
  end
  local key = table.concat(names, ":")
  if key == topology then
    return
  end
  topology = key
  for _, role in ipairs(groupOrder) do
    assigned[role] = selected[role] and selected[role].name
  end

  for _, role in ipairs(groupOrder) do
    local group = groups[role]
    local monitor = selected[role]
    local target = monitor or main
    for id = group.first, group.first + group.count - 1 do
      hl.workspace_rule({
        workspace = tostring(id),
        monitor = target.name,
        persistent = monitor ~= nil,
        default = id == group.first and monitor ~= nil,
      })
      local workspace = hl.get_workspace(tostring(id))
      if workspace and workspace.monitor ~= target then
        hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = target.name }))
      end
    end
    if monitor then
      local active = monitor.active_workspace
      if not active or not active.id or active.id < group.first or active.id >= group.first + group.count then
        monitor:set_workspace(tostring(group.first))
      end
    end
  end
end

function M.step(offset, dispatcher, monitor)
  monitor = monitor or hl.get_monitor_at_cursor() or hl.get_active_monitor()
  if not monitor then
    return
  end
  local group = groups.primary
  for _, role in ipairs(groupOrder) do
    if monitor.name == assigned[role] then
      group = groups[role]
      break
    end
  end
  local first, count = group.first, group.count
  local workspace = monitor.active_workspace
  local id = workspace and workspace.id
  if not id or id < first or id >= first + count then
    id = offset > 0 and first - 1 or first
  end
  local target = tostring(first + ((id - first + offset) % count))
  hl.dispatch(dispatcher(target))
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

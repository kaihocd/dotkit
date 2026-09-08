-- Popup group types.
-- Groups tie multiple instances together under shared lifecycle logic.

local Group = {}
Group.__index = Group

local registry = {}

---@param name string
---@param config? popup.group.config
---@return popup.group
function Group.create(name, config)
  if registry[name] then
    error('group already exists: ' .. name)
  end

  local group = setmetatable({
    name = name,
    instances = {},
    config = config or {},
  }, Group)

  registry[name] = group

  return group
end

---@param name string
---@return popup.group?
function Group.get(name)
  return registry[name]
end

---@param instance popup.instance
function Group:add(instance)
  table.insert(self.instances, instance)

  if self.config.on_join then
    self.config.on_join(instance, self)
  end
end

---@param instance popup.instance
function Group:remove(instance)
  if self.config.on_leave then
    self.config.on_leave(instance, self)
  end

  for i, inst in ipairs(self.instances) do
    if inst == instance then
      table.remove(self.instances, i)
      break
    end
  end
end

return Group

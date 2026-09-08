local Group = require('popup.group')

-- Popup group membership helpers for instances.
local M = {}

---@param instance popup.instance
---@param name string
function M.join_group(instance, name)
  if instance._group then
    error('instance already in group: ' .. instance._group.name)
  end

  local group = Group.get(name)
  if not group then
    error('group not found: ' .. name)
  end

  group:add(instance)
  instance._group = group
end

---@param instance popup.instance
function M.leave_group(instance)
  if not instance._group then
    return
  end

  local group = instance._group
  instance._group = nil
  group:remove(instance)
end

return M

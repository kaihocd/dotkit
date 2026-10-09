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

  local membership = {}
  instance._group = group
  instance._group_membership = membership
  local ok, problem = pcall(group.add, group, instance)
  if not ok then
    if instance._group_membership == membership then
      instance._group = nil
      instance._group_membership = nil
    end
    error(problem, 0)
  end
end

---@param instance popup.instance
function M.leave_group(instance)
  local group = instance._group
  if not group then
    return
  end
  instance._group = nil
  instance._group_membership = nil
  group:remove(instance)
end

return M

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local popup = require('popup')
local source = {
  search = function()
    return { status = 'ready', total = 0, items = {} }
  end,
}
local notifications = {}
local function notify(message)
  notifications[#notifications + 1] = message
end
vim.notify = notify
for _, hook in ipairs({ 'on_join', 'on_leave' }) do
  local config = {}
  config[hook] = function()
    error('test ' .. hook)
  end
  local group = popup.group('error-' .. hook, config)
  local count = 0
  local session = Session.new(source, function()
    count = count + 1
  end)
  session:open(function(instance)
    instance:join_group(group.name)
  end)
  session:close()
  assert(vim.wait(2000, function()
    return count == 1
  end))
  assert(#group.instances == 0 and session.window.popup._group == nil)
  assert(#vim.api.nvim_list_wins() == 1)
end
assert(#notifications == 2)
local first = true
local reentrant = popup.group('reentrant-join', {
  on_join = function(instance)
    if first then
      first = false
      instance:leave_group()
      instance:join_group('reentrant-join')
      error('outer join failed')
    end
  end,
})
local session = Session.new(source, function() end)
local instance = session.window.popup
assert(not pcall(instance.join_group, instance, reentrant.name))
assert(instance._group == reentrant and #reentrant.instances == 1)
instance:leave_group()
assert(#reentrant.instances == 0 and instance._group == nil)
local leaves = 0
local rejoin = popup.group('reentrant-leave', {
  on_leave = function(member)
    leaves = leaves + 1
    member:leave_group()
    if leaves == 1 then
      member:join_group('reentrant-leave')
    end
  end,
})
instance:join_group(rejoin.name)
instance:leave_group()
assert(leaves == 1 and #rejoin.instances == 1 and instance._group == rejoin)
instance:leave_group()
instance:leave_group()
assert(leaves == 2 and #rejoin.instances == 0)
local failing_rejoin = popup.group('failing-rejoin-leave', {
  on_leave = function(member)
    member:join_group('failing-rejoin-leave')
    error('leave failed after rejoin')
  end,
})
instance:join_group(failing_rejoin.name)
assert(not pcall(instance.leave_group, instance))
assert(instance._group == failing_rejoin and #failing_rejoin.instances == 1)
failing_rejoin.config.on_leave = nil
instance:leave_group()
assert(instance._group == nil and #failing_rejoin.instances == 0)
session:close()
vim.wait(100)
print(
  'PASS group hook errors clean resources and reentrant memberships survive old rollback/removal'
)

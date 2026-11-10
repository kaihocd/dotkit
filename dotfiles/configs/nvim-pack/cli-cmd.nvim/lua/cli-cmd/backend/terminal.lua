---Adapter for an external terminal implementation (for example `terminal.nvim`).
---The capability owns the session and the UI; this adapter only translates its
---outcome into task events. Nothing here can observe the session's exit code, so
---a delegated run always reports `delegated` rather than success.
local check = require('cli-cmd.guard')('cli-cmd.terminal')
local Terminal = {}
Terminal.__index = Terminal

function Terminal.new(capability)
  check(type(capability) == 'table', 'capability is required')
  check(type(capability.delegate) == 'function', 'capability.delegate is required')
  return setmetatable({ _capability = capability }, Terminal)
end

function Terminal:run(context, task)
  check(type(context) == 'table', 'context is required')
  check(task and type(task.finish) == 'function', 'task is required')

  local ok, handle = pcall(self._capability.delegate, context, task)
  if not ok then
    task:finish({ kind = 'error', message = tostring(handle) })
    error(handle, 0)
  end

  if handle ~= nil then
    check(type(handle) == 'table', 'delegate must return a handle or nil')
    if handle.cancel ~= nil then
      check(type(handle.cancel) == 'function', 'handle.cancel must be a function')
    end
  end

  task:finish({ kind = 'delegated', target = 'terminal' })
  return handle or {}
end

return Terminal

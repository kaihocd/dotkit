---Adapter for an external terminal implementation (for example `terminal.nvim`).
---The capability owns the session and the UI; this adapter only translates its
---outcome into task events. Nothing here observes the session's exit code, so a
---delegated run reports `delegated` rather than success — unless the capability
---says it will report the real outcome itself (`owns_result`).
local check = require('cli-cmd.guard')('cli-cmd.backend.external_terminal')
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
    if handle.owns_result ~= nil then
      check(type(handle.owns_result) == 'boolean', 'handle.owns_result must be a boolean')
    end
  end

  --A capability that can see the exit code reports it itself. Saying `delegated`
  --on its behalf would throw that away and claim less than is known; the task
  --stays open until the capability finishes it.
  if handle and handle.owns_result then
    return handle
  end

  task:finish({ kind = 'delegated', target = 'terminal' })
  return handle or {}
end

return Terminal

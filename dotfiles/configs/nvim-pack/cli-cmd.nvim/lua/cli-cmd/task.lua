local check = require('cli-cmd.guard')('cli-cmd.task')
local Task = {}
Task.__index = Task

local terminal_kinds = {
  exit = true,
  delegated = true,
  error = true,
  cancelled = true,
}

function Task.new(metadata)
  check(metadata == nil or type(metadata) == 'table', 'metadata must be a table')
  return setmetatable(
    { _metadata = vim.deepcopy(metadata or {}), _status = 'created', _listeners = {}, _next_id = 0 },
    Task
  )
end

function Task:status()
  return self._status
end

---Execution metadata, copied so callers cannot mutate task state.
---@return table
function Task:metadata()
  return vim.deepcopy(self._metadata)
end

---Record a scalar fact about how the task runs, for example the output surface a
---handler already presents. Backends annotate; presenters read.
---@param key string
---@param value string|number|boolean
---@return table task
function Task:annotate(key, value)
  check(type(key) == 'string' and key ~= '', 'metadata key is required')
  check(
    type(value) == 'string' or type(value) == 'number' or type(value) == 'boolean',
    'metadata value must be a scalar'
  )
  self._metadata[key] = value
  return self
end

function Task:result()
  return self._result and vim.deepcopy(self._result) or nil
end

function Task:on(callback)
  check(type(callback) == 'function', 'listener must be a function')
  self._next_id = self._next_id + 1
  local id = self._next_id
  self._listeners[id] = callback
  return function()
    self._listeners[id] = nil
  end
end

function Task:_emit(event)
  for _, callback in pairs(self._listeners) do
    callback(vim.deepcopy(event), self)
  end
end

function Task:start()
  check(self._status == 'created', 'can only start a created task')
  self._status = 'running'
  self:_emit({ kind = 'start' })
  return self
end

function Task:output(stream, data)
  check(stream == 'stdout' or stream == 'stderr', 'invalid output stream')
  check(type(data) == 'string', 'output must be a string')
  if self._status == 'finished' then
    return false
  end
  self:_emit({ kind = 'output', stream = stream, data = data })
  return true
end

function Task:complete(result)
  check(self._status ~= 'finished', 'task already finished')
  check(self._status == 'running' or self._status == 'cancelling', 'task must be running')
  check(type(result) == 'table' and terminal_kinds[result.kind], 'invalid result')
  if result.kind == 'exit' then
    check(
      type(result.code) == 'number' and result.code >= 0,
      'exit code must be a non-negative number'
    )
  elseif result.kind == 'delegated' then
    check(result.target == 'terminal', 'delegated target must be terminal')
  elseif result.kind == 'error' then
    check(type(result.message) == 'string' and result.message ~= '', 'error message is required')
  end
  self._result = vim.deepcopy(result)
  self._status = 'finished'
  self:_emit({ kind = 'result', result = vim.deepcopy(result) })
  self._listeners = {}
  return true
end

---Finish a running task, or a cancelling one as cancelled.
---Returns false when the task already finished, so a late process or terminal
---callback cannot complete it twice or overwrite an earlier result. Ownership of
---the lifecycle stays here: backends report what they saw, they never decide
---whether the task may still be completed.
---@param result table
---@return boolean completed
function Task:finish(result)
  if self._status == 'finished' then
    return false
  end
  if self._status == 'cancelling' then
    self:complete({ kind = 'cancelled' })
    return true
  end
  self:complete(result)
  return true
end

function Task:cancel()
  if self._status == 'finished' then
    return false
  end
  check(self._status == 'running', 'can only cancel a running task')
  self._status = 'cancelling'
  self:_emit({ kind = 'cancel' })
  return true
end

return Task

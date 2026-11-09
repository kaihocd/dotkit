---Presenter that reports a finished Task through `vim.notify`, so a single
---`vim.notify` override takes over every CLI output surface.
---
---Output is buffered per task and emitted once on completion; success without
---output stays silent so that ordinary commands do not spam the message area.
local check = require('cli.guard')('cli.presenter.notify')

---One presenter instance. It buffers per task, so a single instance can serve
---several commands without mixing their output.
---@class cli.NotifyPresenter
---@field private _notify? fun(message: string, level?: integer)
---@field private _level? integer
local Notify = {}
Notify.__index = Notify

local levels = vim.log.levels

---@param opts? {notify?: fun(message: string, level?: integer), level?: integer}
function Notify.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  check(opts.notify == nil or type(opts.notify) == 'function', 'notify must be a function')
  check(opts.level == nil or type(opts.level) == 'number', 'level must be a number')
  return setmetatable({ _notify = opts.notify, _level = opts.level }, Notify)
end

---Level for a terminal result, or nil when the result carries no level of its
---own; `opts.level` is the fallback for those, never a threshold.
---@param result table
---@return integer?
local function level_of(result)
  if result.kind == 'exit' then
    return result.code == 0 and levels.INFO or levels.ERROR
  elseif result.kind == 'error' then
    return levels.ERROR
  elseif result.kind == 'cancelled' then
    return levels.WARN
  end
  return nil
end

---@param output string
---@param result table
---@return string?
local function message_of(output, result)
  local text = output:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('^%s*\n', ''):gsub('\n%s*$', '')
  if text ~= '' then
    return text
  end
  if result.kind == 'exit' then
    if result.code == 0 then
      return nil
    end
    return 'exit ' .. result.code
  elseif result.kind == 'error' then
    return result.message
  elseif result.kind == 'cancelled' then
    return 'cancelled'
  end
  return nil
end

---Observe a task and report its outcome once it finishes.
---@param task table
---@return table task
function Notify:attach(task)
  check(type(task) == 'table' and type(task.on) == 'function', 'task is required')
  local chunks = {}
  task:on(function(event)
    if event.kind == 'output' then
      chunks[#chunks + 1] = event.data
    elseif event.kind == 'result' then
      if task:metadata().surface == 'terminal' then
        return
      end
      local message = message_of(table.concat(chunks), event.result)
      local level = level_of(event.result) or self._level
      if message and level then
        local notify = self._notify or vim.notify
        notify(message, level)
      end
    end
  end)
  return task
end

return Notify

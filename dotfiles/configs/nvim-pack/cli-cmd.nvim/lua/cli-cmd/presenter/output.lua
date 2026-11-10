---Presenter that reports a finished Task in one piece: a report short enough to
---read in the message area goes through `vim.notify`, so a single `vim.notify`
---override takes over every short report; a longer one opens in a scratch tab,
---where it can still be scrolled, searched, and yanked from.
---
---Output is buffered per task and emitted once on completion; success without
---output stays silent so that ordinary commands do not spam the message area.
local check = require('cli-cmd.guard')('cli-cmd.presenter.output')

---One presenter instance. It buffers per task, so a single instance can serve
---several commands without mixing their output.
---@class cli-cmd.OutputPresenter
---@field private _notify? fun(message: string, level?: integer)
---@field private _level? integer
---@field private _max_lines integer
local Output = {}
Output.__index = Output

local levels = vim.log.levels

---Reports longer than this do not fit the message area.
local default_max_lines = 15

---@param opts? {notify?: fun(message: string, level?: integer), level?: integer, max_lines?: integer}
function Output.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  check(opts.notify == nil or type(opts.notify) == 'function', 'notify must be a function')
  check(opts.level == nil or type(opts.level) == 'number', 'level must be a number')
  local max_lines = opts.max_lines
  check(
    max_lines == nil or (type(max_lines) == 'number' and max_lines > 0 and max_lines % 1 == 0),
    'max_lines must be a positive integer'
  )
  return setmetatable(
    { _notify = opts.notify, _level = opts.level, _max_lines = max_lines or default_max_lines },
    Output
  )
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

---@param message string
---@return integer
local function line_count(message)
  local _, newlines = message:gsub('\n', '\n')
  return newlines + 1
end

---A tab rather than a split: a long report must not replace what the user was
---reading, and closing it is the familiar `:q`.
---@param message string
local function show(message)
  vim.cmd.tabnew()
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(message, '\n', { plain = true }))
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].modifiable = false
end

---Report one finished task: short reports notify, long ones open a tab.
---@param message string
---@param level integer
function Output:report(message, level)
  if line_count(message) > self._max_lines then
    show(message)
    return
  end
  local notify = self._notify or vim.notify
  notify(message, level)
end

---Observe a task and report its outcome once it finishes.
---@param task table
---@return table task
function Output:attach(task)
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
        self:report(message, level)
      end
    end
  end)
  return task
end

return Output

---Presenter that reports a finished Task in one piece, as one string of text
---handed to a kind of sink. Which window or message area the report lands in is
---the sink's decision, never the report's length.
---
---A caller does not build this; `setup` builds it once per name and `install`
---picks one by name. See `cli-cmd.presenter.registry`.
---
---Output is buffered per task and emitted once on completion; success without
---output stays silent so that ordinary commands do not spam the message area.
local check = require('cli-cmd.guard')('cli-cmd.presenter.output')

---One kind's options. `kind` chooses the kind; every other field belongs to the
---kinds that have something to do with it.
---@class cli-cmd.ReportConfig
---@field kind? 'split'|'notify'|'tab'|fun(message: string, level: integer) Defaults to `'split'`.
---@field level? integer Fallback level for results that carry no level of their own, for every kind.
---@field min_height? integer `split` only: the shortest the window may be.
---@field max_height? integer `split` only: the tallest the window may be.
---@field enter? boolean `tab` only: switch to the tab, or leave it in the background. Defaults to `true`.
---@field number? boolean `split` and `tab`: line numbers in the report. Defaults to the editor's setting.
---@field wrap? boolean `split` and `tab`: wrap long lines. Defaults to the editor's setting.

---One option a kind accepts.
---@class cli-cmd.Option
---@field accepts fun(value: any): boolean
---@field message string How to say no.
---@field default? any What an unconfigured presenter uses; a function is called each time the option is read.
---@field window? boolean Set on the report's own window instead of inherited.

---The whole default configuration of the presenter.
---@class cli-cmd.PresenterDefaults
---@field kind string The kind an unconfigured presenter uses.
---@field kinds table<string, table<string, cli-cmd.Option>> Every kind, and every option it accepts.

---A third of the screen, measured when a report is shown so the report follows a
---resize instead of freezing the screen size it was configured at.
---@return integer
local function screen_third()
  return math.max(1, math.floor(vim.o.lines / 3))
end

---@param value any
---@return boolean
local function positive_integer(value)
  return type(value) == 'number' and value > 0 and value % 1 == 0
end

---@param value any
---@return boolean
local function boolean(value)
  return type(value) == 'boolean'
end

---Every kind, every option it accepts, and every default. This is the whole
---configurable surface: validation, defaults and window handling are read from
---here instead of being written into the code paths that use them, so "what does
---the plugin do by default" is one table rather than a search through the module.
---@type table<string, table<string, cli-cmd.Option>>
local kinds = {
  split = {
    min_height = {
      accepts = positive_integer,
      message = 'min_height is a positive integer',
      default = 1,
    },
    max_height = {
      accepts = positive_integer,
      message = 'max_height is a positive integer',
      default = screen_third,
    },
    number = { accepts = boolean, message = 'number is a boolean', window = true },
    wrap = { accepts = boolean, message = 'wrap is a boolean', window = true },
  },
  tab = {
    enter = { accepts = boolean, message = 'enter is a boolean', default = true },
    number = { accepts = boolean, message = 'number is a boolean', window = true },
    wrap = { accepts = boolean, message = 'wrap is a boolean', window = true },
  },
  notify = {},
}

---One presenter instance. It buffers per task, so a single instance can serve
---several commands without mixing their output.
---@class cli-cmd.OutputPresenter
---@field private _kind 'split'|'notify'|'tab'|fun(message: string, level: integer)
---@field private _level? integer
---@field private _options table<string, any> What this presenter actually uses, defaults included.
---@field private _rules table<string, cli-cmd.Option>
local Output = {}
Output.__index = Output

---The default configuration, readable in one screen.
---@type cli-cmd.PresenterDefaults
Output.defaults = { kind = 'split', kinds = kinds }

local levels = vim.log.levels

---@param config cli-cmd.ReportConfig
---@return cli-cmd.OutputPresenter
function Output.new(config)
  check(type(config) == 'table', 'a report config must be a table')

  local kind = config.kind or Output.defaults.kind
  local rules = type(kind) == 'string' and kinds[kind] or nil
  check(
    type(kind) == 'function' or rules ~= nil,
    "kind must be 'split', 'notify', 'tab', or a function"
  )
  check(config.level == nil or type(config.level) == 'number', 'level must be a number')

  -- A field the chosen kind has no use for is a mistake in the config, not
  -- something to ignore: `notify` has no window to size, so `min_height` there
  -- would be silently dead.
  for name in pairs(config) do
    if name ~= 'kind' and name ~= 'level' then
      check(
        rules ~= nil and rules[name] ~= nil,
        name
          .. ' does not apply to kind = '
          .. (type(kind) == 'string' and ("'" .. kind .. "'") or 'a function')
      )
    end
  end

  local options = {}
  for name, rule in pairs(rules or {}) do
    local value = config[name]
    if value == nil then
      options[name] = rule.default
    else
      check(rule.accepts(value), rule.message)
      options[name] = value
    end
  end

  check(
    config.min_height == nil or config.max_height == nil or config.min_height <= config.max_height,
    'min_height must not exceed max_height'
  )

  return setmetatable({
    _kind = kind,
    _level = config.level,
    _options = options,
    _rules = rules or {},
  }, Output)
end

---Level for a terminal result, or nil when the result carries no level of its
---own; `level` is the fallback for those, never a threshold.
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

---Put the report into the current window's buffer, read-only and wiped when the
---window closes.
---@param message string
---@return integer lines
local function fill(message)
  local lines = vim.split(message, '\n', { plain = true })
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].modifiable = false
  return #lines
end

---How tall a report's window should be: as tall as its text, kept inside the
---configured bounds. A default that is a function is called now, because it
---describes the screen as it is at this moment.
---@param lines integer
---@return integer
function Output:_height(lines)
  local max_height = self._options.max_height
  if type(max_height) == 'function' then
    max_height = max_height()
  end
  return math.min(math.max(lines, self._options.min_height), max_height)
end

---Window options the report asks for, taken from the same table that declares
---them. They belong to the report's window, so they are set here rather than
---inherited from whatever the editor had.
function Output:_decorate()
  for name, rule in pairs(self._rules) do
    local value = self._options[name]
    if rule.window == true and value ~= nil then
      vim.wo[name] = value
    end
  end
end

---A tab is reserved for commands that take a keyboard, so the default kind is a
---bottom split and the tabline stays free of reports; `<C-w>T` promotes one to a
---tab when it is worth keeping beside the files.
---@param message string
function Output:_split(message)
  -- `new`, not `split`: the report needs a buffer of its own, since reusing the
  -- current one would fail on a read-only buffer and overwrite a real file.
  vim.cmd('botright new')
  vim.api.nvim_win_set_height(0, self:_height(fill(message)))
  self:_decorate()
end

---@param message string
function Output:_tab(message)
  local origin = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  fill(message)
  self:_decorate()
  if not self._options.enter then
    -- A report you asked not to look at must not take the keyboard.
    vim.api.nvim_set_current_tabpage(origin)
  end
end

---@param message string
---@param level integer
function Output:_notify(message, level)
  -- Resolved per report, so overriding `vim.notify` later takes over.
  vim.notify(message, level)
end

---One entry per kind, so a new kind is a method plus a row here.
---@type table<string, fun(presenter: cli-cmd.OutputPresenter, message: string, level: integer)>
local sinks = {
  split = Output._split,
  tab = Output._tab,
  notify = Output._notify,
}

---Hand one report to the sink.
---@param message string
---@param level integer
function Output:report(message, level)
  local kind = self._kind
  if type(kind) == 'function' then
    kind(message, level)
    return
  end
  sinks[kind](self, message, level)
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

-- Adapt popup events to commands without accessing Select session state.

local keymap = require('popup.extensions.keymap')
local keymap_ui = require('picker.ui.keymap')
local augroup = require('picker.ui.augroup')
---Internal event adapters supplied by the session.
---@class picker.select.Events
---@field active fun(): boolean
---@field click fun()
---@field refresh fun()
---@field focus fun()
---@field resize? fun()

---@class picker.select.SelectBindings
---@field private _configured table
---@field private _detail_key string?
---@field private _events picker.ui.Augroup?
---@field private _closed boolean
---@field private _attached boolean
local SelectBindings = {}
SelectBindings.__index = SelectBindings
local M = {}

-- Construction

---@return picker.select.SelectBindings
---@param overrides table
function M.new(overrides)
  local configured, detail = M.resolve(overrides)
  return setmetatable({
    _events = nil,
    _closed = false,
    _attached = false,
    _configured = configured,
    _detail_key = detail,
  }, SelectBindings)
end

-- Binding resolution

---Describe declarative detail bindings; arbitrary callbacks cannot be inferred.
---@param configured table
---@return string?
local function detail_key(configured)
  local labels = {}
  for _, mode in ipairs({ 'i', 'n' }) do
    local bindings = configured[mode] or {}
    local keys = {}
    for key, action in pairs(bindings) do
      if action == 'toggle_detail' then
        keys[#keys + 1] = key
      end
    end
    table.sort(keys)
    labels[mode] = table.concat(keys, '/')
  end
  if labels.i == labels.n then
    return labels.i ~= '' and labels.i or nil
  end
  local parts = {}
  for _, mode in ipairs({ 'i', 'n' }) do
    if labels[mode] ~= '' then
      parts[#parts + 1] = mode .. ':' .. labels[mode]
    end
  end
  return #parts > 0 and table.concat(parts, ' ') or nil
end

---Binding and hint discovery share the same resolved declaration.
---@generic T
---@param overrides table<string, table<string, string|false|fun(actions: picker.select.Actions<T>)>>
---@return table<string, table<string, string|false|fun(actions: picker.select.Actions<T>)>> configured
---@return string? detail_key
function M.resolve(overrides)
  local configured = vim.deepcopy(overrides)

  return configured, detail_key(configured)
end

-- Private helpers

---@generic T
---@param configured table<string, table<string, string|false|fun(actions: picker.select.Actions<T>)>>
---@param commands picker.select.Actions<T>
---@param events picker.select.Events
---@return popup.keymap.opts
local function bind_actions(configured, commands, events)
  local actions = {
    confirm = commands.confirm,
    toggle_detail = commands.toggle_detail,
    cancel = commands.cancel,
    next = function()
      commands.move(1)
    end,
    previous = function()
      commands.move(-1)
    end,
    page_down = function()
      commands.page(1)
    end,
    page_up = function()
      commands.page(-1)
    end,
    click = events.click,
  }

  ---@type popup.keymap.opts
  local resolved = {}
  for mode, bindings in pairs(configured) do
    resolved[mode] = {}
    for key, action in pairs(bindings) do
      if type(action) == 'function' then
        resolved[mode][key] = function()
          if events.active() then
            action(commands)
          end
        end
      elseif type(action) == 'string' and actions[action] then
        resolved[mode][key] = actions[action]
      elseif type(action) == 'string' or action == false then
        resolved[mode][key] = action
      end
    end
  end
  return resolved
end

-- Instance API

---Register listeners before opening; release invocation-owned autocmds on teardown.
---@generic T
---@param instance popup.instance
---@param commands picker.select.Actions<T>
---@param events picker.select.Events
function SelectBindings:attach(instance, commands, events)
  if self._closed or self._attached then
    return
  end
  self._attached = true

  -- Mappings can be declared now; buffer-local listeners require mounted panes.
  instance:use(keymap(bind_actions(self._configured, commands, events)))
  keymap_ui.preserve_insert_word_delete(instance, self._configured)
  instance:on('close', commands.cancel)

  instance:on('open', function()
    if self._closed or not events.active() then
      return
    end

    -- The group exists before the first listener: partial setup still tears down.
    local group = augroup.new('picker:select:events')
    self._events = group
    local ok, problem = pcall(function()
      local input = instance:pane('input')
      if not input or not vim.api.nvim_buf_is_valid(input.buf) then
        commands.cancel()
        return
      end
      group:create({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
        buffer = input.buf,
        callback = events.refresh,
        desc = 'Update Select list from input',
      })

      -- Screen and focus events belong to this invocation, not the input buffer.
      if events.resize then
        group:create('VimResized', {
          callback = events.resize,
          desc = 'Rebuild Select layout for the current screen',
        })
      end
      group:create('WinEnter', {
        callback = events.focus,
        desc = 'Close Select when focus leaves its panes',
      })
    end)

    if not ok then
      self:detach()
      error(problem, 0)
    end
  end)
end

function SelectBindings:detach()
  self._closed = true
  if self._events then
    self._events:close()
    self._events = nil
  end
end

---@return string?
function SelectBindings:detail_key()
  return self._detail_key
end

return M

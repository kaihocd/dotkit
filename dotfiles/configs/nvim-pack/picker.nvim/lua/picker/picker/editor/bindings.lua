-- Editor wiring for one Picker session: keymaps, editor events and their lifetime.
--
-- Reads panel methods and writes only to the popup instance, so it holds no
-- session state of its own. Keymaps are resolved once per invocation and every
-- bound command runs through the panel's error boundary; that is why the
-- installation lives here and not in the session object.

local keymap = require('popup.extensions.keymap')
local keymap_ui = require('picker.ui.keymap')
local actions_module = require('picker.picker.editor.actions')
local augroup = require('picker.ui.augroup')

local M = {}

-- Keymaps

---Resolve once per invocation; native actions remain native declarations.
---@param configured picker.picker.Keymaps
---@param actions picker.picker.Actions
---@param run fun(operation: fun())
---@param click fun()
---@return popup.keymap.opts
local function resolve(configured, actions, run, click)
  local named = {
    click = click,
    confirm = actions.confirm,
    open_split = function()
      actions.open('split')
    end,
    open_vsplit = function()
      actions.open('vsplit')
    end,
    open_tab = function()
      actions.open('tab')
    end,
    quickfix = actions.quickfix,
    mark_next = function()
      actions.mark(1)
    end,
    mark_previous = function()
      actions.mark(-1)
    end,
    cancel = actions.cancel,
    next = function()
      actions.move(1)
    end,
    previous = function()
      actions.move(-1)
    end,
    page_down = function()
      actions.page(1)
    end,
    page_up = function()
      actions.page(-1)
    end,
    preview_down = function()
      actions.scroll_preview(nil, 1)
    end,
    preview_up = function()
      actions.scroll_preview(nil, -1)
    end,
    toggle_preview = actions.toggle_preview,
    cycle_match_mode = actions.cycle_match_mode,
  }
  ---@type popup.keymap.opts
  local resolved = {}
  for mode, mappings in pairs(configured) do
    resolved[mode] = {}
    for lhs, declaration in pairs(mappings) do
      if type(declaration) == 'function' then
        resolved[mode][lhs] = function()
          run(function()
            declaration(actions)
          end)
        end
      elseif type(declaration) == 'string' and named[declaration] then
        resolved[mode][lhs] = function()
          run(named[declaration])
        end
      else
        resolved[mode][lhs] = declaration
      end
    end
  end
  return resolved
end

---@param instance popup.instance
---@param mappings popup.keymap.opts
local function apply_mappings(instance, mappings)
  instance:use(keymap(mappings))
  keymap_ui.preserve_insert_word_delete(instance, mappings)
end

-- Editor events

---Install editor events; callbacks are supplied by the session and remain narrow.
---@param group picker.ui.Augroup
---@param input popup.pane
---@param callbacks { changed: fun(), outside: fun(), theme: fun(), resize: fun() }
local function attach_events(group, input, callbacks)
  group:create({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
    buffer = input.buf,
    callback = callbacks.changed,
    desc = 'Update Picker input results',
  })
  group:create('WinEnter', {
    callback = callbacks.outside,
    desc = 'Cancel Picker on outside focus',
  })
  group:create('ColorScheme', {
    callback = callbacks.theme,
    desc = 'Repaint Picker theme decorations',
  })
  group:create('VimResized', {
    callback = callbacks.resize,
    desc = 'Resize Picker layout',
  })
end

---Owns the registered editor-event lifetime, independently of panel business state.
---@class picker.picker.PickerBindings
---@field private _events picker.ui.Augroup?
local PickerBindings = {}
PickerBindings.__index = PickerBindings

---@return picker.picker.PickerBindings
function M.new()
  return setmetatable({ _events = nil }, PickerBindings)
end

---@param input popup.pane
---@param callbacks { changed: fun(), outside: fun(), theme: fun(), resize: fun() }
function PickerBindings:listen(input, callbacks)
  self:detach()
  -- Registered before the first listener so a partial install still tears down.
  self._events = augroup.new('picker:events')
  local ok, problem = pcall(attach_events, self._events, input, callbacks)
  if not ok then
    self:detach()
    error(problem, 0)
  end
end

function PickerBindings:detach()
  if self._events then
    self._events:close()
    self._events = nil
  end
end

-- Install

---Install before open so partial opening also belongs to this invocation.
---@param panel picker.picker.PickerPanel
function M.install(panel)
  local function action(operation)
    return function()
      panel:run(operation)
    end
  end
  local actions = actions_module.create({
    confirm = function(mode)
      panel:confirm(mode)
    end,
    cancel = function()
      panel:close()
    end,
    quickfix = function()
      panel:quickfix()
    end,
    mark = function(step)
      panel:mark(step)
    end,
    move = function(delta)
      panel:move(delta)
    end,
    page = function(step)
      panel:page(step)
    end,
    scroll_preview = function(lines, step)
      panel.window:scroll_preview(lines, step)
    end,
    cycle_match_mode = function()
      panel:cycle_match_mode()
    end,
    toggle_preview = function()
      panel:resize(true)
    end,
  }, function(operation)
    panel:run(operation)
  end)

  local mappings = resolve(panel._settings.keymaps, actions, function(operation)
    panel:run(operation)
  end, function()
    panel:click()
  end)
  apply_mappings(panel.window.popup, mappings)

  panel.window.popup:on('close', function()
    panel:close()
  end)
  panel.window.popup:on('open', function()
    if panel._closed then
      return
    end
    local input = panel.window:pane('input')
    if not input then
      panel:close()
      return
    end
    panel.bindings:listen(input, {
      changed = action(function()
        panel:query_changed()
      end),
      outside = function()
        if not panel.window:focused() then
          panel:close()
        end
      end,
      theme = action(function()
        panel:decorate()
      end),
      resize = action(function()
        panel:resize()
      end),
    })
  end)
end

return M

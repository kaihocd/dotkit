local keymap = require('popup.extensions.keymap')
local M = {}

---Resolve once per invocation; native actions remain native declarations.
---@param configured picker.picker.Keymaps
---@param actions picker.picker.Actions
---@param run fun(operation: fun())
---@param click fun()
---@return popup.keymap.opts
function M.resolve(configured, actions, run, click)
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
function M.attach(instance, mappings)
  instance:use(keymap(mappings))
  if not mappings.i or mappings.i['<C-w>'] == nil then
    local function bind_input()
      local input = instance:pane('input')
      if input then
        vim.keymap.set('i', '<C-w>', '<C-S-w>', {
          buffer = input.buf,
          desc = 'Delete previous word',
        })
      end
    end
    instance:on('open', bind_input)
    instance:on('render', bind_input)
  end
end

---Install editor events; callbacks are supplied by Session and remain narrow.
---@param input popup.pane
---@param callbacks { changed: fun(), outside: fun(), theme: fun(), resize: fun() }
---@return integer[]
function M.attach_events(input, callbacks)
  local events = {}
  local function register(event, options)
    events[#events + 1] = vim.api.nvim_create_autocmd(event, options)
  end

  local ok, problem = pcall(function()
    register({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
      buffer = input.buf,
      callback = callbacks.changed,
      desc = 'Update Picker input results',
    })
    register('WinEnter', {
      callback = callbacks.outside,
      desc = 'Cancel Picker on outside focus',
    })
    register('ColorScheme', {
      callback = callbacks.theme,
      desc = 'Repaint Picker theme decorations',
    })
    register('VimResized', {
      callback = callbacks.resize,
      desc = 'Resize Picker layout',
    })
  end)

  if not ok then
    M.detach_events(events)
    error(problem, 0)
  end

  return events
end

---@param events integer[]
function M.detach_events(events)
  for _, id in ipairs(events) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
end

---Owns the registered editor-event lifetime, independently of Panel business state.
---@class picker.picker.PickerBindings
---@field private _events integer[]
local PickerBindings = {}
PickerBindings.__index = PickerBindings

---@return picker.picker.PickerBindings
function M.new()
  return setmetatable({ _events = {} }, PickerBindings)
end

---@param input popup.pane
---@param callbacks { changed: fun(), outside: fun(), theme: fun(), resize: fun() }
function PickerBindings:attach(input, callbacks)
  self:detach()
  self._events = M.attach_events(input, callbacks)
end

function PickerBindings:detach()
  M.detach_events(self._events)
  self._events = {}
end

return M

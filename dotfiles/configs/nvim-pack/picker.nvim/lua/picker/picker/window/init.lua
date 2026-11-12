local PreviewPane = require('picker.picker.window.preview')
local icons = require('picker.picker.window.icons')
local input_view = require('picker.picker.window.input')
local layout = require('picker.picker.window.layout')
local list_view = require('picker.picker.window.list')
local pane_guard = require('picker.ui.pane')
local popup = require('popup')
local presentation = require('picker.picker.presentation')
local render_view = require('picker.picker.window.render')

---Owns native popup resources, not selection or search state.
---@class picker.picker.PickerWindow
---@field popup popup.instance
---@field _buffers integer[]
---@field _closed boolean
---@field _options picker.picker.ResolvedView
---@field _preview boolean
---@field _mode 'files'|'grep'
---@field _list picker.picker.ListPane
---@field _preview_pane picker.picker.PreviewPane
---@field _icon fun(path: string): string?, string?
---@field _presentation picker.picker.ResolvedPresentation
---@field _render picker.picker.Renderer
local PickerWindow = {}
PickerWindow.__index = PickerWindow

-- Lifecycle

---Prepare without opening windows; all allocated buffers are registered immediately.
---@param options picker.picker.ResolvedView
---@return picker.picker.PickerWindow
function PickerWindow.new(options, mode)
  local self = setmetatable({
    _buffers = {},
    _closed = false,
    _options = vim.deepcopy(options),
    _mode = mode or 'files',
    _preview = false,
    _preview_pane = PreviewPane.new(),
    _presentation = presentation.resolve(options.presentation, mode or 'files'),
    _icon = icons.resolve(options.icon),
    _list = list_view.new(),
  }, PickerWindow)
  self._render = render_view.new({
    pane = function(id)
      return self:pane(id)
    end,
    query = function()
      return self:query()
    end,
    page_size = function()
      return self:page_size()
    end,
    list = self._list,
    presentation = self._presentation,
    icon = self._icon,
    mode = self._mode,
    signs = self._options.signs,
  })
  local ok, problem = pcall(function()
    for _ = 1, 3 do
      self._buffers[#self._buffers + 1] = vim.api.nvim_create_buf(false, true)
    end
    self.popup = popup.root(layout.build(self._options, self._buffers, self._preview))
  end)
  if not ok then
    self:close()
    error(problem, 0)
  end
  return self
end

---@param id string
---@return popup.pane?
function PickerWindow:pane(id)
  if self._closed then
    return
  end
  return pane_guard.get(self.popup, id)
end

---Open failures are cleaned locally before reaching the session error boundary.
function PickerWindow:open()
  if self._closed then
    return
  end
  local ok, problem = pcall(function()
    self.popup:open()
    local input = self:pane('input')
    if input then
      vim.bo[input.buf].buftype = 'prompt'
      -- The visible prefix is an extmark, not part of the editable query.
      vim.fn.prompt_setprompt(input.buf, '')
      input_view.render_prefix(input, self._presentation.prefix)
    end
    local list = self:pane('list')
    if list then
      vim.wo[list.win].wrap = false
    end
  end)
  if not ok then
    self:close()
    error(problem, 0)
  end
end

---Reevaluate declarations while retaining the interactive pane identities.
function PickerWindow:resize()
  if self._closed then
    return
  end
  local preview = self:pane('preview')
  if preview then
    self._preview_pane:save(preview)
  end
  local root = layout.build(self._options, self._buffers, self._preview)
  self.popup
    :update(function(node)
      for key, value in pairs(root) do
        node[key] = value
      end
    end)
    :render()
  preview = self:pane('preview')
  if preview then
    self._preview_pane:restore(preview)
  end
  local list = self:pane('list')
  if list then
    vim.wo[list.win].wrap = false
  end
end

---The caller owns completion/focus; View releases only its own UI resources.
function PickerWindow:close()
  if self._closed then
    return
  end
  self._closed = true
  if self.popup then
    self.popup:close()
  end
  for _, buf in ipairs(self._buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  self._buffers = {}
end

-- Preview pane

---Preview content is owned by Preview; this only controls its pane.
---@return boolean Requested state, including preview temporarily hidden by layout.
function PickerWindow:preview_requested()
  return self._preview
end

function PickerWindow:toggle_preview()
  if self._closed then
    return
  end
  self._preview = not self._preview
  local ok, problem = pcall(self.resize, self)
  if not ok then
    self._preview = not self._preview
    error(problem, 0)
  end
end

---Only this capability is handed to the preview reader; popup ownership stays here.
---@return picker.picker.PreviewDisplay
function PickerWindow:preview_display()
  return {
    visible = function()
      return self:pane('preview') ~= nil
    end,
    content = function(lines, line, path)
      self:preview_content(lines, line, path)
    end,
    matches = function(entry)
      self:preview_matches(entry)
    end,
    position = function(line)
      local pane = self:pane('preview')
      if pane then
        self._preview_pane:position(pane, line)
      end
    end,
  }
end

---@param lines string[]
---@param line? integer
---@param path? string
function PickerWindow:preview_content(lines, line, path)
  local pane = self:pane('preview')
  if not pane then
    return
  end
  self._preview_pane:content(pane, lines, line, path)
end

---Match decorations can change without rewriting content or resetting scroll.
---@param entry? picker.picker.Entry
function PickerWindow:preview_matches(entry)
  local pane = self:pane('preview')
  if not pane then
    return
  end
  self._preview_pane:matches(pane, entry, self._presentation.row.match)
end

---Scroll only the preview viewport; business selection remains Controller-owned.
---@param lines? integer nil uses half the preview height.
---@param direction? integer
function PickerWindow:scroll_preview(lines, direction)
  local pane = self:pane('preview')
  if not pane then
    return
  end
  self._preview_pane:scroll(pane, lines, direction)
end

-- Input pane

---@return string
function PickerWindow:query()
  local input = self:pane('input')
  return input and input_view.query(input) or ''
end

---@param query string
---@param insert boolean
function PickerWindow:restore_query(query, insert)
  local input = assert(self:pane('input'))
  input_view.restore(input, query, insert)
end

---The input pane holds a single line; callers never render a query they cannot see.
---@return boolean changed
function PickerWindow:flatten_input()
  local input = self:pane('input')
  return input ~= nil and input_view.one_line(input)
end

---@return boolean
function PickerWindow:focused()
  local input = self:pane('input')
  return input ~= nil and input_view.focused(input)
end

-- Geometry

---Use screen geometry: nonfocusable floats do not reliably report mouse.winid.
---@param row integer
---@param col integer
---@return integer? index
function PickerWindow:hit(row, col)
  local list = self:pane('list')
  return list and self._list:hit(list, row, col) or nil
end

---Borders and preview are inside the invocation, but not selectable rows.
---@param row integer
---@param col integer
---@return boolean
function PickerWindow:contains(row, col)
  if self._closed then
    return false
  end
  local root = self.popup:root()
  if not root or not vim.api.nvim_win_is_valid(root.win) then
    return false
  end
  local position = vim.api.nvim_win_get_position(root.win)
  return row > position[1]
    and col > position[2]
    and row <= position[1] + vim.api.nvim_win_get_height(root.win)
    and col <= position[2] + vim.api.nvim_win_get_width(root.win)
end

---@return integer
function PickerWindow:page_size()
  local list = self:pane('list')
  return list and vim.api.nvim_win_get_height(list.win) or 1
end

-- Painting

---Search mode is fixed for the lifetime of one invocation, so the presentation
---resolved in `new` stays valid; there is no per-render mode switch.
---@param entries picker.picker.Entry[]
---@param index integer?
---@param status? 'ready'|'indexing'
function PickerWindow:render(entries, index, status)
  self._render.entries(entries, index, status)
end

---Decorations reflect model marks; they never store a second selection state.
---@param entries picker.picker.Entry[]
---@param is_marked fun(entry: picker.picker.Entry): boolean
function PickerWindow:marks(entries, is_marked)
  self._render.marks(entries, is_marked)
end

---@param result picker.picker.Page
---@param marked integer
---@param mode? string
function PickerWindow:status(result, marked, mode)
  return self._render.status(result, marked, mode)
end

---@param index? integer
---@param direction integer
---@return integer
function PickerWindow:page_delta(index, direction)
  return self._render.page_delta(index, direction)
end

---@param index integer?
function PickerWindow:select(index)
  self._render.select(index)
end

return PickerWindow

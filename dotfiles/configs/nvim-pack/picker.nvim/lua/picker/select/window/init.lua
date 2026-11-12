-- Native popup resources and detail transitions for the cursor-local Select menu.
--
-- Owns buffers, windows and the detail pane only. Rows, prompt and hint are
-- painted by `picker.select.window.paint`; what to show is decided by the panel.

local DetailPane = require('picker.select.window.detail')
local layout = require('picker.select.window.layout')
local list_renderer = require('picker.ui.list')
local paint = require('picker.select.window.paint')
local pane_guard = require('picker.ui.pane')
local popup = require('popup')

---@class picker.select.SelectWindow
---@field popup popup.instance
---@field private _buffers integer[]
---@field private _closed boolean
---@field private _prompt string
---@field private _config picker.select.ResolvedView
---@field private _detail picker.select.Detail
---@field private _list_view table?
---@field private _texts string[]
---@field private _anchor { row: integer, col: integer }
---@field private _detail_text string?
local SelectWindow = {}
SelectWindow.__index = SelectWindow

-- Lifecycle

---Own every allocated buffer before mounting any window.
---@param prompt string
---@param texts string[]
---@param current_index integer?
---@param config picker.select.ResolvedView
---@param rows? picker.list.Row[]
---@return picker.select.SelectWindow
function SelectWindow.new(prompt, texts, current_index, config, rows)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local anchor = vim.fn.screenpos(0, cursor[1], cursor[2] + 1)
  ---@type picker.select.SelectWindow
  local self = setmetatable({
    _buffers = {},
    _closed = false,
    _prompt = prompt,
    _config = config,
    _detail = DetailPane.new(),
    _list_view = nil,
    _texts = vim.list_slice(texts),
    _anchor = { row = anchor.row, col = anchor.col },
    _detail_text = nil,
  }, SelectWindow)
  local ok, problem = pcall(self.prepare, self, texts, current_index, rows)
  if not ok then
    self:close()
    error(problem, 0)
  end
  return self
end

---Allocate and register resources before invoking caller layout code.
---@private
---@param texts string[]
---@param current_index integer?
---@param rows? picker.list.Row[]
function SelectWindow:prepare(texts, current_index, rows)
  for _ = 1, 4 do
    self._buffers[#self._buffers + 1] = vim.api.nvim_create_buf(false, true)
  end
  local root = layout.build(texts, self._config, self._buffers, self._anchor, false, self._prompt)
  self.popup = popup.root(vim.deepcopy(root))
  self.popup:on('open', function()
    paint.decorate(self.popup, self._config)
    self:render(texts, current_index, rows)
  end)
end

function SelectWindow:open()
  if not self._closed then
    self.popup:open()
  end
end

function SelectWindow:close()
  if self._closed then
    return
  end
  self._closed = true

  -- Leave the group before destruction, but still release buffers if its hook fails.
  local ok, problem = true, nil
  if self.popup then
    ok, problem = pcall(self.popup.leave_group, self.popup)
    self.popup:close()
  end

  for _, buf in ipairs(self._buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  self._buffers = {}
  if not ok then
    error(problem, 0)
  end
end

-- Detail pane

---@return boolean
function SelectWindow:detail_active()
  return self._detail_text ~= nil
end

---@param text string
function SelectWindow:show_detail(text)
  if self._closed or self:detail_active() then
    return
  end

  -- Capture the list viewport before the layout can unmount its window.
  local list = self:pane('list')
  self._list_view = list and vim.api.nvim_win_call(list.win, vim.fn.winsaveview)

  self._detail_text = text
  self:rebuild()

  local pane = assert(self:pane('detail'))
  vim.bo[pane.buf].filetype = 'picker-select-detail'
  self._detail:open(pane, text)
end

function SelectWindow:leave_detail()
  if not self:detail_active() then
    return
  end

  self._detail:close()
  self._detail_text = nil
  self:rebuild()

  -- The list must be mounted before its original cursor and scroll can return.
  local list = self:pane('list')
  local view = self._list_view
  self._list_view = nil
  if list and view then
    vim.api.nvim_win_call(list.win, function()
      vim.fn.winrestview(view)
    end)
  end
end

---@param direction integer
function SelectWindow:scroll_detail(direction)
  self._detail:scroll(direction)
end

-- Layout

---One layout evaluation path for detail transitions and screen resize.
function SelectWindow:rebuild()
  local root = layout.build(
    self._texts,
    self._config,
    self._buffers,
    self._anchor,
    self:detail_active(),
    self._prompt
  )

  self.popup
    :update(function(node)
      for key, value in pairs(root) do
        node[key] = value
      end
    end)
    :render()

  -- Returning from detail may create a new list window around the retained buffer.
  local list = self:pane('list')
  if list then
    vim.bo[list.buf].filetype = 'picker-select'
    vim.wo[list.win].wrap = false
    vim.wo[list.win].winhighlight = 'CursorLine:' .. self._config.highlights.current
  end
end

function SelectWindow:resize()
  if self._closed then
    return
  end

  local pane = self:pane(self:detail_active() and 'detail' or 'list')
  local view = pane and vim.api.nvim_win_call(pane.win, vim.fn.winsaveview)

  self._detail:close()
  self:rebuild()
  if self._detail_text then
    self._detail:open(assert(self:pane('detail')), self._detail_text)
  end

  pane = self:pane(self:detail_active() and 'detail' or 'list')
  if pane and view then
    vim.api.nvim_win_call(pane.win, function()
      vim.fn.winrestview(view)
    end)
  end
end

-- Painting

---@param texts string[]
---@param index integer?
function SelectWindow:render(texts, index, rows)
  self:leave_detail()
  paint.render(self.popup, self._prompt, texts, index, self._config, rows)
end

---@param index integer?
function SelectWindow:select(index)
  paint.select(self.popup, index, self._config.highlights.current)
end

---@param key string?
---@param text string?
function SelectWindow:hint(key, text)
  paint.hint(self.popup, self._config, key, text, self:detail_active())
end

---Use the same clipping rule as list rendering and hints.
---@param text string
---@return boolean
function SelectWindow:clipped(text)
  return paint.clipped(self.popup, self._config, text)
end

-- Accessors

---@param id string
---@return popup.pane?
function SelectWindow:pane(id)
  return not self._closed and pane_guard.get(self.popup, id) or nil
end

---@return string?
function SelectWindow:query()
  local input = self:pane('input')
  return input and (vim.api.nvim_buf_get_lines(input.buf, 0, 1, false)[1] or '') or nil
end

---@return integer?
function SelectWindow:page_size()
  local pane = self:pane('list')
  return pane and math.max(1, vim.api.nvim_win_get_height(pane.win)) or nil
end

---@param row integer
---@param col integer
---@return integer? index Nil denotes outside the list.
function SelectWindow:hit(row, col)
  local pane = self:pane('list')
  return pane and list_renderer.hit(pane, row, col)
end

---@param input_only? boolean
---@return boolean
function SelectWindow:focused(input_only)
  local win = vim.api.nvim_get_current_win()
  local input, list = self:pane('input'), self:pane('list')
  local detail = self:pane('detail')
  return (input ~= nil and input.win == win)
    or (not input_only and list ~= nil and list.win == win)
    or (not input_only and detail ~= nil and detail.win == win)
    or false
end

return SelectWindow

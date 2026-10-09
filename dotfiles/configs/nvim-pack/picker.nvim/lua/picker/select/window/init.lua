-- Native popup configuration and rendering for the cursor-local Select menu.
local DetailPane = require('picker.select.window.detail')
local layout = require('picker.select.window.layout')
local list_renderer = require('picker.list')
local popup = require('popup')

local prefix_namespace = vim.api.nvim_create_namespace('PickerSelect')
local hint_namespace = vim.api.nvim_create_namespace('PickerSelectHint')
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
local M = {}

---A queued update may arrive after a pane has been destroyed.
---@param instance popup.instance
---@param id string
---@return popup.pane?
function M.pane(instance, id)
  local pane = instance:pane(id)
  if pane and vim.api.nvim_win_is_valid(pane.win) and vim.api.nvim_buf_is_valid(pane.buf) then
    return pane
  end
end

-- Window initialization

---Apply static styling only after popup has created both panes.
---@param instance popup.instance
---@param config picker.select.ResolvedView
local function decorate(instance, config)
  local input = M.pane(instance, 'input')
  local list = M.pane(instance, 'list')
  local detail = M.pane(instance, 'detail')
  if not input or not list then
    return
  end

  vim.bo[input.buf].buftype = 'prompt'
  -- The visible prefix is an extmark, not part of the editable query.
  vim.fn.prompt_setprompt(input.buf, '')
  vim.bo[input.buf].filetype = 'picker-select-input'
  vim.bo[list.buf].filetype = 'picker-select'
  if detail then
    vim.bo[detail.buf].filetype = 'picker-select-detail'
    vim.wo[detail.win].wrap = false
    vim.wo[detail.win].cursorline = false
  end

  vim.wo[input.win].wrap = false
  vim.wo[list.win].wrap = false
  vim.wo[list.win].winhighlight = 'CursorLine:' .. config.highlights.current

  vim.api.nvim_buf_set_extmark(input.buf, prefix_namespace, 0, 0, {
    virt_text = {
      { string.rep(' ', config.prefix.margin[1]) },
      { config.prefix.text, config.prefix.highlight },
      { string.rep(' ', config.prefix.margin[2]) },
    },
    virt_text_pos = 'inline',
    right_gravity = false,
  })
end

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
  for _ = 1, 3 do
    self._buffers[#self._buffers + 1] = vim.api.nvim_create_buf(false, true)
  end
  local root = layout.build(texts, self._config, self._buffers, self._anchor)
  self.popup = popup.root(vim.deepcopy(root))
  self.popup:on('open', function()
    decorate(self.popup, self._config)
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

---Compose Select's prompt and item rows for the shared renderer.
---@param instance popup.instance
---@param prompt string
---@param texts string[]
---@param current_index integer?
---@param config picker.select.ResolvedView
function M.render(instance, prompt, texts, current_index, config, formatted)
  local rows = { { content = { { prompt, config.highlights.prompt } } } }
  for index, text in ipairs(texts) do
    rows[#rows + 1] = formatted and formatted[index] or { content = { { text } } }
  end
  local pane = M.pane(instance, 'list')
  if not pane then
    return
  end
  list_renderer.render(pane, rows, {
    padding = {
      left = config.padding.left,
      right = config.padding.right,
    },
  }, { [1] = { padding = { left = 1, right = 1 } } })
  M.select(instance, current_index, config.highlights.current)
end

---@param instance popup.instance
---@param current_index integer?
function M.select(instance, current_index, highlight)
  local pane = M.pane(instance, 'list')
  if not pane then
    return
  end
  -- Row one belongs to the prompt.
  list_renderer.select(pane, current_index and current_index + 1 or nil, highlight)
end

---Keep the input hint clear of the query and its insertion cursor.
---@param instance popup.instance
---@param config picker.select.ResolvedView
---@param key string?
---@param text string?
---@param detail boolean
function M.hint(instance, config, key, text, detail)
  local pane = M.pane(instance, 'list')
  local clipped = pane
    and text
    and list_renderer.is_clipped(
      text,
      vim.api.nvim_win_get_width(pane.win),
      { padding = config.padding }
    )
  local input = M.pane(instance, 'input')
  if not input then
    return
  end
  vim.api.nvim_buf_clear_namespace(input.buf, hint_namespace, 0, -1)
  if not key or not (detail or clipped) then
    return
  end

  local hint = key .. (detail and ': back ' or ': full text ')
  local query = vim.api.nvim_buf_get_lines(input.buf, 0, 1, false)[1] or ''
  local occupied = vim.fn.strdisplaywidth(config.prefix.text)
    + vim.fn.strdisplaywidth(query)
    + config.prefix.margin[1]
    + config.prefix.margin[2]
  local available = vim.api.nvim_win_get_width(input.win)
  -- Reserve a cell for the insertion cursor and a gap before the hint.
  if occupied + 2 + vim.fn.strdisplaywidth(hint) > available then
    return
  end

  vim.api.nvim_buf_set_extmark(input.buf, hint_namespace, 0, 0, {
    virt_text = { { hint, config.highlights.hint } },
    virt_text_pos = 'right_align',
    right_gravity = false,
  })
end

---@param id string
---@return popup.pane?
function SelectWindow:pane(id)
  return not self._closed and M.pane(self.popup, id) or nil
end

---@return string?
function SelectWindow:query()
  local input = self:pane('input')
  return input and (vim.api.nvim_buf_get_lines(input.buf, 0, 1, false)[1] or '') or nil
end

---@param texts string[]
---@param index integer?
function SelectWindow:render(texts, index, rows)
  self:leave_detail()
  M.render(self.popup, self._prompt, texts, index, self._config, rows)
end

---@param index integer?
function SelectWindow:select(index)
  M.select(self.popup, index, self._config.highlights.current)
end

---@param key string?
---@param text string?
function SelectWindow:hint(key, text)
  M.hint(self.popup, self._config, key, text, self:detail_active())
end

---@return boolean
function SelectWindow:detail_active()
  return self._detail_text ~= nil
end

---Use the same clipping rule as list rendering and hints.
---@param text string
---@return boolean
function SelectWindow:clipped(text)
  local pane = self:pane('list')
  return pane ~= nil
    and list_renderer.is_clipped(
      text,
      vim.api.nvim_win_get_width(pane.win),
      { padding = self._config.padding }
    )
end

---One layout evaluation path for mode transitions and screen resize.
function SelectWindow:rebuild()
  local root =
    layout.build(self._texts, self._config, self._buffers, self._anchor, self:detail_active())

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

---@return integer?
function SelectWindow:page_size()
  local pane = self:pane('list')
  return pane and math.max(1, vim.api.nvim_win_get_height(pane.win) - 1) or nil
end

---@param row integer
---@param col integer
---@return integer? index Zero denotes the prompt; nil denotes outside the list.
function SelectWindow:hit(row, col)
  local pane = self:pane('list')
  local hit = pane and list_renderer.hit(pane, row, col)
  return hit and hit - 1 or nil
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

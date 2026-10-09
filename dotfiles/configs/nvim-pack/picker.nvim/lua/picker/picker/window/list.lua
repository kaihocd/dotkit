local list_items = require('picker.picker.window.row')
local renderer = require('picker.list')
local marks_namespace = vim.api.nvim_create_namespace('PickerMarks')

local M = {}

---@class picker.picker.ListBuild
---@field rows picker.list.Row[]
---@field decorations picker.picker.ListHighlight[][]
---@field entry_rows table<integer, integer>
---@field row_entries table<integer, integer>

---@class picker.picker.ListBuildOptions
---@field mode 'files'|'grep'
---@field width integer
---@field entries picker.picker.Entry[]
---@field icon fun(path: string): string?, string?
---@field format? picker.picker.FormatItem
---@field match? string
---@field empty_text string

---Build list data without touching windows, buffers, selection, or Session state.
---@param options picker.picker.ListBuildOptions
---@return picker.picker.ListBuild
function M.build(options)
  local rows, decorations = {}, {}
  local entry_rows, row_entries = {}, {}
  local previous

  for entry_index, entry in ipairs(options.entries) do
    if options.mode == 'files' or entry.path ~= previous then
      local row = list_items.item(
        entry,
        'files',
        options.width,
        options.icon,
        options.mode == 'files' and options.format or nil,
        options.match
      )
      rows[#rows + 1] = row
      decorations[#decorations + 1] = {}
    end

    if options.mode == 'grep' then
      local row =
        list_items.item(entry, 'grep', options.width, options.icon, options.format, options.match)
      rows[#rows + 1] = row
      decorations[#decorations + 1] = {}
    end

    local entry_row = #rows
    entry_rows[entry_index] = entry_row
    row_entries[entry_row] = entry_index
    previous = entry.path
  end

  if #rows == 0 then
    rows[1] = { content = { { options.empty_text, 'Comment' } } }
  end

  return {
    rows = rows,
    decorations = decorations,
    entry_rows = entry_rows,
    row_entries = row_entries,
  }
end

---@param pane popup.pane
---@param built picker.picker.ListBuild
---@param padding { left: integer, right: integer }
function M.render(pane, built, padding)
  renderer.render(pane, built.rows, { padding = padding })
end

---@param pane popup.pane
---@param row integer
---@param col integer
---@param row_entries table<integer, integer>
---@return integer?
function M.hit(pane, row, col, row_entries)
  local display_row = renderer.hit(pane, row, col)
  return display_row and row_entries[display_row] or nil
end

---@param entry_rows table<integer, integer>
---@param index integer?
---@param direction integer
---@param page_size integer
---@return integer
function M.page_delta(entry_rows, index, direction, page_size)
  if not index then
    return 0
  end
  local count = #entry_rows
  if (direction < 0 and index == 1) or (direction > 0 and index == count) then
    return direction
  end
  local target = entry_rows[index] + direction * math.max(1, math.floor(page_size / 2))
  local next_index = index
  while entry_rows[next_index + direction] do
    next_index = next_index + direction
    if direction * (entry_rows[next_index] - target) >= 0 then
      break
    end
  end
  return next_index - index
end

---@param pane popup.pane
---@param entries picker.picker.Entry[]
---@param entry_rows table<integer, integer>
---@param is_marked fun(entry: picker.picker.Entry): boolean
---@param marker fun(status: string?, marked: boolean): string[]?
---@param status_column integer
function M.render_marks(pane, entries, entry_rows, is_marked, marker, status_column)
  vim.api.nvim_buf_clear_namespace(pane.buf, marks_namespace, 0, -1)
  if vim.api.nvim_win_get_width(pane.win) <= status_column then
    return
  end
  for index, entry in ipairs(entries) do
    local row = entry_rows[index]
    local sign = row and marker(entry.git_status, is_marked(entry)) or nil
    if sign then
      vim.api.nvim_buf_set_extmark(pane.buf, marks_namespace, row - 1, status_column, {
        virt_text = { sign },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
      })
    end
  end
end

---Owns the display projection; item identity and marks remain Selection-owned.
---@class picker.picker.ListPane
---@field private _built picker.picker.ListBuild
local ListPane = {}
ListPane.__index = ListPane

---@return picker.picker.ListPane
function M.new()
  return setmetatable({
    _built = { rows = {}, decorations = {}, entry_rows = {}, row_entries = {} },
  }, ListPane)
end

---@param pane popup.pane
---@param built picker.picker.ListBuild
---@param padding {left: integer, right: integer}
function ListPane:render(pane, built, padding)
  self._built = built
  M.render(pane, built, padding)
end

---@param pane popup.pane
---@param index? integer
function ListPane:select(pane, index, highlight)
  renderer.select(pane, index and self._built.entry_rows[index] or nil, highlight)
end

---@param pane popup.pane
---@param row integer
---@param col integer
---@return integer?
function ListPane:hit(pane, row, col)
  return M.hit(pane, row, col, self._built.row_entries)
end

---@param index? integer
---@param direction integer
---@param height integer
---@return integer
function ListPane:page_delta(index, direction, height)
  return M.page_delta(self._built.entry_rows, index, direction, height)
end

---@param pane popup.pane
---@param entries picker.picker.Entry[]
---@param is_marked fun(entry: picker.picker.Entry): boolean
---@param marker fun(status: string?, marked: boolean): string[]?
---@param column integer
function ListPane:marks(pane, entries, is_marked, marker, column)
  M.render_marks(pane, entries, self._built.entry_rows, is_marked, marker, column)
end

return M

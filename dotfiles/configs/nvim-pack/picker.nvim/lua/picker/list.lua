-- Render caller-owned rows; never own selection or popup lifecycle.
local M = {}
local namespace = vim.api.nvim_create_namespace('PickerList')
local current_namespace = vim.api.nvim_create_namespace('PickerListCurrent')

---Normalize display text only; callers retain their original search and item values.
---@param text string
---@return string
local function single_line(text)
  return (text:gsub('[\r\n\t]', ' '))
end

---Natural row width, including both insets.
---@param text string
---@param style picker.list.Style
---@return integer
function M.measure(text, style)
  return vim.fn.strdisplaywidth(single_line(text)) + style.padding.left + style.padding.right
end

---Clamp insets before calculating the space left for text.
---@param width integer
---@param style picker.list.Style
---@return integer left
---@return integer right
---@return integer available
local function insets(width, style)
  local left = math.min(style.padding.left, width)
  local right = math.min(style.padding.right, width - left)
  return left, right, width - left - right
end

---@param text string
---@param available integer
---@return boolean
local function overflows(text, available)
  return vim.fn.strdisplaywidth(text) > available
end

---Use the renderer's exact clipping condition, including narrow-window padding.
---@param text string
---@param width integer Window content width before padding.
---@param style picker.list.Style
---@return boolean
function M.is_clipped(text, width, style)
  local _, _, available = insets(width, style)
  return overflows(single_line(text), available)
end

---Fit display cells without cutting a UTF-8 character.
---@param text string
---@param width integer
---@return string
local function truncate(text, width)
  if width <= 0 then
    return ''
  end
  if not overflows(text, width) then
    return text
  end

  local kept = ''
  for _, character in ipairs(vim.fn.split(text, '\\zs')) do
    local candidate = kept .. character
    if vim.fn.strdisplaywidth(candidate) > width - 1 then
      break
    end
    kept = candidate
  end
  return kept .. '…'
end

---Use the same inset and clipping rules for prompt and selectable rows.
---@param text string
---@param width integer
---@param config picker.list.Style
---@return string
local function format_row(text, width, config)
  local left, right, available = insets(width, config)
  return string.rep(' ', left) .. truncate(single_line(text), available) .. string.rep(' ', right)
end

---Remove only decorations owned by this renderer, leaving other namespaces intact.
---@param pane popup.pane
function M.clear_decorations(pane)
  vim.api.nvim_buf_clear_namespace(pane.buf, namespace, 0, -1)
end

---Render rows into an existing pane. Row numbers belong to the caller.
---@param pane popup.pane
---@param rows picker.list.Row[]
---@param style picker.list.Style
---@param row_styles? table<integer, picker.list.Style> Optional per-row inset overrides.
function M.render(pane, rows, style, row_styles)
  local width = vim.api.nvim_win_get_width(pane.win)
  local lines = {}
  local projected = {}
  for index, row in ipairs(rows) do
    local row_style = row_styles and row_styles[index] or style
    local text, ranges = require('picker.content').project(row)
    projected[#projected + 1] = { text = text, ranges = ranges, style = row_style }
    lines[#lines + 1] = format_row(text, width, row_style)
  end

  vim.bo[pane.buf].modifiable = true
  vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, lines)
  vim.bo[pane.buf].modifiable = false

  M.clear_decorations(pane)
  for index, row in ipairs(projected) do
    local left, right = insets(width, row.style)
    local kept = #lines[index] - left - right
    if M.is_clipped(row.text, width, row.style) then
      kept = math.max(0, kept - #'…')
    end
    for _, range in ipairs(row.ranges) do
      local last = math.min(range.last, kept)
      if last > range.first then
        vim.api.nvim_buf_set_extmark(pane.buf, namespace, index - 1, left + range.first, {
          end_col = left + last,
          hl_group = range.group,
          priority = 200,
        })
      end
    end
  end
end

---Reflect a caller-selected buffer row without changing focus.
---@param pane popup.pane
---@param row integer?
function M.select(pane, row, highlight)
  vim.api.nvim_buf_clear_namespace(pane.buf, current_namespace, 0, -1)
  if row then
    vim.api.nvim_buf_set_extmark(pane.buf, current_namespace, row - 1, 0, {
      -- Use the same range-composition path as content highlights. A line_hl_group
      -- background can cover higher-priority match ranges.
      hl_group = highlight or 'CursorLine',
      end_row = row,
      end_col = 0,
      hl_eol = true,
      priority = 100,
    })
  end
  vim.wo[pane.win].cursorline = false
  vim.api.nvim_win_set_cursor(pane.win, { row or 1, 0 })
end

---Return the hit buffer row, including nonselectable rows, or nil outside.
---Requires unwrapped rows: each screen row must correspond to one buffer row.
---@param pane popup.pane
---@param screenrow integer
---@param screencol integer
---@return integer?
function M.hit(pane, screenrow, screencol)
  local first = vim.api.nvim_win_call(pane.win, function()
    return vim.fn.line('w0')
  end)
  local top = vim.fn.screenpos(pane.win, first, 1)
  local offset = screenrow - top.row
  if
    offset < 0
    or offset >= vim.api.nvim_win_get_height(pane.win)
    or screencol < top.col
    or screencol >= top.col + vim.api.nvim_win_get_width(pane.win)
  then
    return nil
  end
  return first + offset
end

return M

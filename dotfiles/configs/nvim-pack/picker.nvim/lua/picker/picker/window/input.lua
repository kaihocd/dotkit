local M = {}

---@param pane popup.pane
---@return boolean
function M.focused(pane)
  return vim.api.nvim_get_current_win() == pane.win
end

---@param pane popup.pane
---@return string
function M.query(pane)
  return vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1] or ''
end

---@param pane popup.pane
---@param query string
---@param insert? boolean
function M.restore(pane, query, insert)
  vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, { query })
  vim.api.nvim_win_set_cursor(pane.win, { 1, #query })
  if insert then
    vim.cmd('startinsert!')
  end
end
local prefix_namespace = vim.api.nvim_create_namespace('PickerInput')
local status_namespace = vim.api.nvim_create_namespace('PickerStatus')

---@param pane popup.pane
---@param style picker.picker.TextStyle
function M.render_prefix(pane, style)
  vim.api.nvim_buf_clear_namespace(pane.buf, prefix_namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(pane.buf, prefix_namespace, 0, 0, {
    virt_text = {
      { string.rep(' ', style.margin and style.margin[1] or 0) },
      { style.text, style.highlight },
      { string.rep(' ', style.margin and style.margin[2] or 0) },
    },
    virt_text_pos = 'inline',
    right_gravity = false,
  })
end

---@param pane popup.pane
---@param prefix string
---@param query string
---@param result picker.picker.Page
---@param marked integer
---@param mode string?
---@param style picker.picker.StatusPresentation
---@param indexing string
function M.render_status(pane, prefix, query, result, marked, mode, style, indexing)
  vim.api.nvim_buf_clear_namespace(pane.buf, status_namespace, 0, -1)
  local text = result.status == 'indexing' and indexing
    or tostring(result.total) .. (result.more and '+' or '')
  if mode then
    text = mode .. style.separator .. text
  end
  if marked > 0 then
    text = text .. style.separator .. marked .. style.selected_suffix
  end
  text = text .. style.trailing_space
  local occupied = vim.fn.strdisplaywidth(prefix .. query) + 2
  if occupied + vim.fn.strdisplaywidth(text) <= vim.api.nvim_win_get_width(pane.win) then
    vim.api.nvim_buf_set_extmark(pane.buf, status_namespace, 0, 0, {
      virt_text = { { text, style.highlight } },
      virt_text_pos = 'right_align',
    })
  end
end

return M

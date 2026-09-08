local M = {}

-- Reuse an external buffer or create a new scratch buffer for the popup.
---@param node popup.config.root|popup.config.pane
---@return integer
---@return boolean scratch
function M.create_buffer(node)
  if node.buf and vim.api.nvim_buf_is_valid(node.buf) then
    return node.buf, false
  end

  local buf = vim.api.nvim_create_buf(false, true)

  if node.content then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, node.content)
  end

  return buf, true
end

return M

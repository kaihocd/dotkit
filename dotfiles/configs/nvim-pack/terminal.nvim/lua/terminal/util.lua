local M = {}

-- Return true if Neovim is shutting down.
---@return boolean
function M.is_exiting()
  return vim.v.exiting ~= vim.NIL
end

-- Return true if the buffer is currently displayed in any window.
---@param buf integer
---@return boolean
function M.buffer_is_visible(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

-- Delete a buffer only when it is still valid and hidden.
---@param buf integer
function M.delete_buffer_if_hidden(buf)
  if vim.api.nvim_buf_is_valid(buf) and not M.buffer_is_visible(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

return M

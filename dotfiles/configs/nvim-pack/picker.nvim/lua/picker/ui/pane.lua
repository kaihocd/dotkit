-- A pane is usable only while both its window and buffer are alive.
--
-- Popup updates and timers can outlive a pane, so every read goes through this
-- guard instead of trusting `instance:pane(id)`.

local M = {}

---@param instance popup.instance
---@param id string
---@return popup.pane?
function M.get(instance, id)
  local pane = instance:pane(id)
  if pane and vim.api.nvim_win_is_valid(pane.win) and vim.api.nvim_buf_is_valid(pane.buf) then
    return pane
  end
end

return M

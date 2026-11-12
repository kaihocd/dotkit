-- Teardown steps both entry points must perform in the same order.
--
-- Closing a popup that owns focus must hand focus back to the window the UI was
-- opened from. The order matters: the popup is destroyed while focus is still
-- inside it, so `stopinsert` has to run first and the origin window can only be
-- restored afterwards, when the popup windows are gone.
--
-- What happens *around* this step differs per entry point (the picker saves a
-- snapshot and leaves its group first; Select does neither) and stays there.

local M = {}

---@param origin integer Window that opened the UI.
---@param focused boolean The UI owned focus; only then is focus handed back.
---@param close fun() Destroys the popup; may raise.
---@return boolean ok
---@return any problem
function M.release(origin, focused, close)
  if focused then
    vim.cmd.stopinsert()
  end

  local ok, problem = pcall(close)

  if focused and vim.api.nvim_win_is_valid(origin) then
    vim.api.nvim_set_current_win(origin)
  end

  return ok, problem
end

return M

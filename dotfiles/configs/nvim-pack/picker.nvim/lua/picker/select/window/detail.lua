-- Own temporary full-text presentation, not selection or list composition.
---@class picker.select.Detail
---@field pane? popup.pane
---@field snapshot? { wrap: boolean, cursorline: boolean, view: table }
local Detail = {}
Detail.__index = Detail

---@return picker.select.Detail
function Detail.new()
  return setmetatable({}, Detail)
end

---@param self picker.select.Detail
---@return boolean
function Detail.active(self)
  return self.snapshot ~= nil
end

---@param self picker.select.Detail
---@param pane popup.pane
---@param text string
function Detail.open(self, pane, text)
  if self:active() then
    return
  end
  self.pane = pane
  self.snapshot = {
    wrap = vim.wo[pane.win].wrap,
    cursorline = vim.wo[pane.win].cursorline,
    view = vim.api.nvim_win_call(pane.win, vim.fn.winsaveview),
  }

  vim.bo[pane.buf].modifiable = true
  vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, vim.split(text, '\n', { plain = true }))
  vim.bo[pane.buf].modifiable = false
  -- Soft-wrap with Neovim display lines, never insert width-based newlines.
  vim.wo[pane.win].wrap = true
  vim.wo[pane.win].linebreak = true
  vim.wo[pane.win].breakindent = false
  vim.wo[pane.win].showbreak = ''
  vim.wo[pane.win].cursorline = false
  vim.api.nvim_win_set_cursor(pane.win, { 1, 0 })
end

---Restore the detail pane's own options and viewport; never touch the list.
---@param self picker.select.Detail
function Detail.close(self)
  local pane, snapshot = self.pane, self.snapshot
  self.pane, self.snapshot = nil, nil
  if not pane or not snapshot or not vim.api.nvim_win_is_valid(pane.win) then
    return nil
  end

  vim.wo[pane.win].wrap = snapshot.wrap
  vim.wo[pane.win].cursorline = snapshot.cursorline
  vim.api.nvim_win_call(pane.win, function()
    vim.fn.winrestview(snapshot.view)
  end)
end

---Move by wrapped screen lines, without entering the pane.
---@param self picker.select.Detail
---@param direction integer
function Detail.scroll(self, direction)
  local pane = self.pane
  if not self:active() or not pane or not vim.api.nvim_win_is_valid(pane.win) then
    return
  end
  local count = math.max(1, math.floor(vim.api.nvim_win_get_height(pane.win) / 2))
  vim.api.nvim_win_call(pane.win, function()
    vim.cmd('normal! ' .. count .. (direction > 0 and 'gj' or 'gk'))
  end)
end

return Detail

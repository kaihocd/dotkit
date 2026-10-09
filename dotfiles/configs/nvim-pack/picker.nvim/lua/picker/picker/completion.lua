local M = {}

---@alias picker.picker.OpenMode 'edit'|'split'|'vsplit'|'tab'

---Data captured before teardown; executed only after the invocation releases its UI.
---@class picker.picker.Completion
---@field mode picker.picker.OpenMode|'quickfix'
---@field entries picker.picker.Entry[]

---@param result picker.picker.Completion?
---@param origin integer
function M.execute(result, origin)
  if not result then
    return
  end
  if not vim.api.nvim_win_is_valid(origin) then
    vim.notify('picker: source window no longer exists', vim.log.levels.WARN)
    return
  end
  vim.api.nvim_set_current_win(origin)
  if result.mode == 'quickfix' then
    local items = {}
    for _, entry in ipairs(result.entries) do
      items[#items + 1] = {
        filename = entry.path,
        lnum = entry.line or 1,
        col = (entry.col or 0) + 1,
        text = entry.content or entry.display,
      }
    end
    vim.fn.setqflist({}, ' ', { title = 'Picker', items = items })
    vim.cmd.copen()
    return
  end
  local entry = result.entries[1]
  if not entry then
    return
  end
  local commands = { edit = 'edit', split = 'split', vsplit = 'vsplit', tab = 'tabedit' }
  local command = commands[result.mode]
  if not command then
    error('picker: unsupported open mode: ' .. tostring(result.mode), 0)
  end
  vim.cmd(command .. ' ' .. vim.fn.fnameescape(entry.path))
  if entry.line then
    local row = math.max(1, math.min(entry.line, vim.api.nvim_buf_line_count(0)))
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    vim.api.nvim_win_set_cursor(0, { row, math.max(0, math.min(entry.col or 0, #line)) })
  end
end

return M

local api = vim.api
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile({ 'needle one', 'needle two' }, root .. '/sample.txt')
vim.cmd.cd(root)

local function key(value)
  vim.fn.maparg(value, 'i', false, true).callback()
end

for _, mode in ipairs({ 'files', 'grep' }) do
  require('plugins.explorer.picker').open({ mode = mode })
  local query = api.nvim_get_current_buf()
  if mode == 'grep' then
    api.nvim_buf_set_lines(query, 0, -1, false, { 'needle' })
    api.nvim_exec_autocmds('TextChangedI', { buffer = query })
  end
  local results
  assert(vim.wait(5000, function()
    for _, win in ipairs(api.nvim_list_wins()) do
      local buf = api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'file-picker' then
        results = buf
        local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
        if mode == 'files' then
          return lines[1]:find('sample.txt', 1, true) ~= nil
        end
        return #lines == 3
      end
    end
    return false
  end))
  key('<Tab>')
  if mode == 'grep' then
    key('<Tab>')
  end
  local marks =
    api.nvim_buf_get_extmarks(results, api.nvim_create_namespace('PickerMarks'), 0, -1, {})
  assert(#marks == (mode == 'grep' and 2 or 1))
  key('<C-q>')
  assert(vim.wait(1000, function()
    return vim.bo.buftype == 'quickfix'
  end))
  local items = vim.fn.getqflist()
  assert(#items == (mode == 'grep' and 2 or 1))
  assert(items[1].col == 1 and items[1].lnum == 1)
  assert(api.nvim_buf_get_name(items[1].bufnr) == vim.uv.fs_realpath(root .. '/sample.txt'))
  if mode == 'grep' then
    assert(items[2].lnum == 2)
  end
  vim.cmd.cclose()
end
vim.fn.delete(root, 'rf')
print('PASS Picker multiselect')
vim.cmd('qa!')

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local completion = require('picker.picker.completion')
local path = vim.fn.tempname() .. ' space.lua'
vim.fn.writefile({ 'first', 'second line' }, path)
---@type picker.picker.PageSource
local source = {
  search = function()
    return {
      status = 'ready',
      total = 2,
      items = {
        { path = path, display = 'first', line = 1, col = 0 },
        { path = path, display = 'second', line = 2, col = 3 },
      },
    }
  end,
}
local function key(lhs)
  local mapping = vim.fn.maparg(lhs, 'i', false, true)
  assert(mapping.callback)
  mapping.callback()
end
local cases =
  { { 'edit', '<CR>' }, { 'split', '<C-s>' }, { 'vsplit', '<C-v>' }, { 'tab', '<C-t>' } }
for _, case in ipairs(cases) do
  local origin = vim.api.nvim_get_current_win()
  local windows, tabs = #vim.api.nvim_list_wins(), #vim.api.nvim_list_tabpages()
  local done = false
  local session = Session.new(source, function(_, result)
    assert(result and result.mode == case[1])
    assert(#vim.api.nvim_list_wins() == windows, 'completion ran before popup cleanup')
    completion.execute(result, origin)
    done = true
  end)
  session:open()
  key('<C-n>')
  key(case[2])
  assert(vim.wait(1000, function()
    return done
  end))
  assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(path))
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 3 }))
  if case[1] == 'edit' then
    assert(vim.api.nvim_get_current_win() == origin)
  elseif case[1] == 'tab' then
    assert(#vim.api.nvim_list_tabpages() == tabs + 1)
    vim.cmd.tabclose()
  else
    assert(#vim.api.nvim_list_wins() == windows + 1)
    vim.cmd.close()
  end
  print('PASS cleanup then ' .. case[1] .. ' with escaped path and grep position')
end
local finished = false
local origin = vim.api.nvim_get_current_win()
local session = Session.new(source, function(_, result)
  completion.execute(result, origin)
  finished = true
end)
session:open()
key('<Tab>')
key('<Tab>')
key('<C-q>')
assert(vim.wait(1000, function()
  return finished
end))
local items = vim.fn.getqflist()
assert(#items == 2 and items[1].lnum == 1 and items[2].lnum == 2 and items[2].col == 4)
vim.cmd.cclose()
vim.fn.delete(path)
print('PASS ordered marks complete into quickfix with 1-based columns')

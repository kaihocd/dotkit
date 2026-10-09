local api = vim.api
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile({ 'first', 'hello needle', 'another needle' }, root .. '/sample.lua')
vim.cmd.cd(root)
local backend = require('plugins.explorer.picker.search.grep').new(root)
local result
assert(vim.wait(5000, function()
  result = backend.search('needle', 100)
  return result.status == 'ready' and #result.items == 2
end, 20))
assert(result.items[1].line == 2 and result.items[1].col == 6)
assert(#backend.search('', 100).items == 0)
require('plugins.explorer.picker').open({ mode = 'grep' })
local query = api.nvim_get_current_buf()
api.nvim_buf_set_lines(query, 0, -1, false, { 'needle' })
api.nvim_exec_autocmds('TextChangedI', { buffer = query })
local results
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'file-picker' then
    results = win
  end
end
assert(vim.wait(2000, function()
  return api.nvim_buf_line_count(api.nvim_win_get_buf(results)) == 3
end))
local lines = api.nvim_buf_get_lines(api.nvim_win_get_buf(results), 0, -1, false)
assert(lines[2]:find(':2:7  hello needle', 1, true))
assert(lines[3]:find(':3:9  another needle', 1, true))
assert(api.nvim_win_get_cursor(results)[1] == 2)
api.nvim_win_set_cursor(results, { 1, 0 })
vim.fn.maparg('<CR>', 'i', false, true).callback()
assert(api.nvim_win_is_valid(results), 'File headers must not confirm')
api.nvim_win_set_cursor(results, { 2, 0 })
vim.fn.maparg('<C-n>', 'i', false, true).callback()
assert(api.nvim_win_get_cursor(results)[1] == 3)
vim.fn.maparg('<CR>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
assert(vim.fn.expand('%:t') == 'sample.lua')
assert(api.nvim_win_get_cursor(0)[1] == 3)
local syntax = require('plugins.explorer.picker.list.syntax')
local marks = syntax.highlights('test.lua', 'local number = 42')
assert(#marks > 0, 'Lua snippets should have syntax highlights')
assert(#syntax.highlights('test.unknown_extension', 'hello') == 0)
print('PASS Grep Picker')
vim.cmd('qa!')

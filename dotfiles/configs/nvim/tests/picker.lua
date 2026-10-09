local api = vim.api
require('plugins.explorer.picker.config').view.preview.enabled = false
local origin = api.nvim_get_current_win()
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, 'p')
vim.fn.writefile({ 'picker test' }, directory .. '/example.lua')
vim.cmd.cd(directory)
local previous_active = rawget(_G, 'active')
require('plugins.explorer.picker').open()
assert(rawget(_G, 'active') == previous_active, 'Opening Picker must not write global active')
local query, results
for _, win in ipairs(api.nvim_list_wins()) do
  if win ~= origin then
    local buf = api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == 'file-picker-input' then
      query = win
    elseif ft == 'file-picker' then
      results = win
    end
  end
end
assert(query and results)
assert(#api.nvim_list_wins() == 4)
assert(api.nvim_win_get_config(query).border[2] == '─')
assert(api.nvim_win_get_config(query).border[6] == '')
assert(api.nvim_win_get_config(results).border[2] == '─')
assert(api.nvim_win_get_config(results).border[6] == '─')
local q, r = api.nvim_win_get_config(query), api.nvim_win_get_config(results)
assert(r.row == q.row + q.height + 1)
assert(q.col == r.col and q.width == r.width)
assert(vim.wait(5000, function()
  return api
    .nvim_buf_get_lines(api.nvim_win_get_buf(results), 0, 1, false)[1]
    :match(' example%.lua $') ~= nil
end, 20))
vim.fn.maparg('<CR>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
assert(api.nvim_get_current_win() == origin)
assert(vim.fn.expand('%:t') == 'example.lua')
require('plugins.explorer.picker').open()
vim.fn.maparg('<Esc>', 'i', false, true).callback()
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
require('plugins.explorer.picker').open()
vim.o.columns = 100
api.nvim_exec_autocmds('VimResized', {})
local border_win
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'file-picker-input' then
    border_win = win
  end
end
assert(border_win)
assert(not api.nvim_win_get_config(border_win).title)
api.nvim_win_close(border_win, true)
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
require('plugins.explorer.picker').open()
api.nvim_set_current_win(origin)
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == 1
end))
assert(api.nvim_get_current_win() == origin)
print('PASS file Picker')
vim.cmd('qa!')

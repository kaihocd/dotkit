local api = vim.api
local buf = api.nvim_create_buf(false, true)
local lines = {}
for i = 1, 4000 do
  lines[i] = tostring(i)
end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)
local win =
  api.nvim_open_win(buf, false, { relative = 'editor', row = 1, col = 1, width = 40, height = 10 })
local reads = 0
local config = require('plugins.explorer.picker.config')
local signs = require('plugins.explorer.picker.list.signs').new({ buf = buf, win = win }, function()
  reads = reads + 1
  return false, 'staged_modified'
end, { git = config.list.signs.git, selection = config.list.signs.selection })
api.nvim_set_hl(0, config.list.signs.git.highlights.staged_modified, { fg = 0xffffff })
api.nvim_set_hl(0, config.list.signs.git.background_highlight, { bg = 0 })
signs.replace()
assert(reads == 4000)
reads = 0
api.nvim_win_set_cursor(win, { 2000, 0 })
signs.update()
assert(reads == 2, 'Movement must repaint only previous/current rows, even with 4000 results')
local group = 'PickerSignCursor_PickerSignStaged_'
  .. config.list.signs.git.highlights.staged_modified
local before = api.nvim_get_hl(0, { name = group, link = false }).fg
local count = #api.nvim_get_autocmds({ event = 'ColorScheme' })
api.nvim_set_hl(0, config.list.signs.git.highlights.staged_modified, { fg = 0xff0000 })
api.nvim_exec_autocmds('ColorScheme', {})
assert(
  api.nvim_get_hl(0, { name = group, link = false }).fg ~= before,
  'Theme change must rebuild derived colors'
)
api.nvim_win_close(win, true)
assert(
  #api.nvim_get_autocmds({ event = 'ColorScheme' }) == count - 1,
  'Closing must release the theme listener'
)
api.nvim_buf_delete(buf, { force = true })
print('PASS Picker signs theme and incremental drawing')
vim.cmd('qa!')

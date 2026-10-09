local api = vim.api
require('plugins.explorer.picker.config').view.preview.enabled = true
vim.o.columns = 180
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local path = root .. '/sample.lua'
vim.fn.writefile({ 'on disk' }, path)
vim.cmd.edit(path)
api.nvim_buf_set_lines(0, 0, -1, false, { 'local unsaved = true', 'second line' })
local source = api.nvim_get_current_buf()
local view
view = require('plugins.explorer.picker.view').open(
  'Files',
  function() end,
  require('plugins.explorer.picker.config').view
)
local preview_module = require('plugins.explorer.picker.preview')
local reader = require('plugins.explorer.picker.preview.content').new({
  max_bytes = 1024 * 1024,
  max_cached_files = 32,
  max_cached_bytes = 8 * 1024 * 1024,
  max_prefetch = 4,
})
local preview = preview_module.new(
  view.preview_pane,
  reader,
  { match_highlight = 'Search', match_priority = 200 }
)
local function content()
  return api.nvim_buf_get_lines(view.preview_pane().buf, 0, -1, false)
end
assert(view.preview_pane() and not api.nvim_win_get_config(view.preview_pane().win).focusable)
local focus = api.nvim_get_current_win()
preview.show({ path = path, line = 2, col = 0 })
assert(vim.wait(1000, function()
  return content()[1] == 'local unsaved = true'
end))
assert(api.nvim_win_get_cursor(view.preview_pane().win)[1] == 2)
assert(api.nvim_get_current_win() == focus)
preview.scroll(1)
assert(api.nvim_get_current_win() == focus)
preview.show({ path = path })
preview.show(nil)
vim.wait(100)
assert(content()[1] == '', 'Cancelled preview must not reappear')
view.toggle_preview()
assert(not view.preview_pane() and api.nvim_win_is_valid(view.query.win))
view.toggle_preview()
assert(view.preview_pane())
vim.o.columns = 60
view.resize()
assert(view.preview_pane(), 'Narrow windows must stack Preview instead of hiding it')
local upper = api.nvim_win_get_position(view.results.win)
local lower = api.nvim_win_get_position(view.preview_pane().win)
assert(lower[1] > upper[1] and lower[2] == upper[2])
assert(
  lower[1] == upper[1] + api.nvim_win_get_height(view.results.win) + 1,
  'Stacked list and preview must share one separator'
)
assert(api.nvim_win_get_config(view.results.win).border[6] == '')
assert(api.nvim_win_get_config(view.preview_pane().win).border[1] == '├')
view.toggle_preview()
assert(api.nvim_win_get_config(view.results.win).border[6] == '─')
view.toggle_preview()
assert(api.nvim_win_get_config(view.results.win).border[6] == '')
vim.o.columns = 240
view.resize()
assert(api.nvim_win_get_config(view.results.win).border[6] == '─')
assert(api.nvim_win_get_config(view.preview_pane().win).border[1] == '┌')
assert(view.preview_pane(), 'Resizing must preserve the requested visibility')
assert(
  api.nvim_win_get_position(view.preview_pane().win)[2]
    > api.nvim_win_get_position(view.results.win)[2]
)
local binary = root .. '/binary'
local file = assert(io.open(binary, 'wb'))
file:write('a\0b')
file:close()
preview.show({ path = binary })
assert(vim.wait(1000, function()
  return content()[1] == 'Binary file'
end))
preview.close()
view.close()
assert(api.nvim_buf_is_valid(source) and vim.bo[source].modified)
vim.fn.delete(root, 'rf')
print('PASS Picker preview')
vim.cmd('qa!')

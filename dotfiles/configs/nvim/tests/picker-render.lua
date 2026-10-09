local config = require('plugins.explorer.picker.config')
local renderer = require('plugins.explorer.picker.list.render')
local render = renderer.new(config.list.style, config.list.priority)
local entry = {
  path = '/project/lua/文件.lua',
  display = 'lua/文件.lua',
  match_ranges = { { 0, 3 }, { 4, 10 } },
}
local text, ranges = render.line(entry, function(path)
  assert(path == entry.path)
  return '◆', 'Icon'
end)
assert(text == '◆  文件.lua lua ')
assert(ranges[1].col == 0 and ranges[1].end_col == #'◆')
assert(text:sub(ranges[2].col + 1, ranges[2].end_col) == 'lua')
assert(ranges[2].hl_group == 'Comment')
assert(text:sub(ranges[3].col + 1, ranges[3].end_col) == 'lua')
assert(text:sub(ranges[4].col + 1, ranges[4].end_col) == '文件')
assert(
  ranges[4].hl_group == require('plugins.explorer.picker.config').list.style.match_hl
    and ranges[4].priority == 200
)
assert(render.line(entry) == '文件.lua lua ')
assert(render.line(entry, function()
  return nil
end) == '文件.lua lua ')
local root_text, root_ranges =
  render.line({ path = '/a.lua', display = 'a.lua', match_ranges = { { 0, 1 } } })
assert(root_text == 'a.lua ' and #root_ranges == 1)
assert(root_ranges[1].col == 0 and root_ranges[1].end_col == 1)
local style = vim.tbl_extend('force', require('plugins.explorer.picker.config').list.style, {
  padding_left = '   ',
  padding_right = '',
  directory_gap = ' · ',
  match_hl = 'Search',
})
local custom, marks = render.line(entry, nil, style)
assert(custom == '   文件.lua · lua')
assert(custom:sub(marks[3].col + 1, marks[3].end_col) == '文件')
assert(marks[3].hl_group == 'Search')
print('PASS Picker rendering')
vim.cmd('qa!')

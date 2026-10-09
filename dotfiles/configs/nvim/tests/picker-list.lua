local api = vim.api
local config = require('plugins.explorer.picker.config')
local buf = api.nvim_create_buf(false, true)
local win =
  api.nvim_open_win(buf, false, { relative = 'editor', row = 0, col = 0, width = 60, height = 10 })
local notified, notifications = nil, 0
local list = require('plugins.explorer.picker.list').new({ buf = buf, win = win }, {
  grep = true,
  style = config.list.style,
  priority = config.list.priority,
  signs = { git = config.list.signs.git, selection = config.list.signs.selection },
  on_current = function(entry)
    notified = entry
    notifications = notifications + 1
  end,
})
local function item(path, line)
  return {
    path = path,
    display = path,
    line = line,
    col = 0,
    content = 'text',
    content_matches = {},
  }
end
local a, b, c = item('a.txt', 1), item('a.txt', 2), item('b.txt', 1)
list.replace({ a, b, c })
assert(api.nvim_buf_line_count(buf) == 5)
assert(list.current() == a and notified == a)
local count = notifications
list.decorate_marks()
assert(notifications == count, 'Repeated cursor events must not duplicate notifications')
list.move(1)
assert(list.current() == b and notified == b)
list.move(1)
assert(list.current() == c and api.nvim_win_get_cursor(win)[1] == 5)
list.replace({ c, a, b }, true)
assert(list.current() == c)
api.nvim_win_set_cursor(win, { 1, 0 })
assert(list.current() == nil)
list.decorate_marks()
assert(notified == nil, 'Moving onto a header must clear the current-item notification')
list.replace({})
list.move(1)
assert(list.current() == nil and api.nvim_buf_line_count(buf) == 1)
assert(api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'No Item')
assert(not list.can_move(1) and #list.nearby(2) == 0)
list.toggle_mark()
assert(list.marked_count() == 0, 'No Item is a nonselectable placeholder')
list.replace({ a, b, c })
list.toggle_mark()
list.move(1)
list.toggle_mark()
assert(#list.marked_items() == 2)
list.replace({ c })
assert(#list.marked_items() == 2, 'Filtering must retain hidden marks')
list.replace({ a, b })
local signs = api.nvim_buf_get_extmarks(
  buf,
  api.nvim_create_namespace('PickerMarks'),
  0,
  -1,
  { details = true }
)
assert(#signs == 2 and signs[1][4].sign_text:find('▊', 1, true))
list.toggle_mark()
list.toggle_mark()
assert(list.marked_items()[1].line == 2 and list.marked_items()[2].line == 1)
api.nvim_win_set_cursor(win, { 1, 0 })
list.toggle_mark()
assert(#list.marked_items() == 2, 'Headers cannot be marked')
list.replace({})
list.toggle_mark()
assert(#list.marked_items() == 2)
api.nvim_win_close(win, true)
api.nvim_buf_delete(buf, { force = true })
print('PASS Picker list')
vim.cmd('qa!')

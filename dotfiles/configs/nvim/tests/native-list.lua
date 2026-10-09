local api = vim.api
local buf = api.nvim_create_buf(false, true)
local win =
  api.nvim_open_win(buf, false, { relative = 'editor', row = 0, col = 0, width = 30, height = 6 })
local list = require('native-ui.list').new(buf, win)
local first, second = {}, {}
list.set_rows({
  { text = 'Explanation', highlight = 'Comment' },
  { text = 'First', entry = first },
  { text = 'Another group', highlight = 'WarningMsg' },
  { text = 'Second', entry = second },
})
assert(list.current() == first)
list.move(-1)
assert(api.nvim_win_get_cursor(win)[1] == 2)
list.move(1)
assert(list.current() == second and api.nvim_win_get_cursor(win)[1] == 4)
list.move(1)
assert(list.current() == second)
list.set_rows({ { text = 'Second', entry = second }, { text = 'First', entry = first } })
assert(list.current() == second, 'Preserve entry identity across row changes')
list.set_rows({ { text = 'No matches', highlight = 'Comment' } })
assert(list.current() == nil)
list.move(1)
assert(list.current() == nil)
list.set_rows({})
assert(list.current() == nil)
api.nvim_win_close(win, true)
api.nvim_buf_delete(buf, { force = true })
print('PASS native list arbitrary nonselectable rows and selection identity')
vim.cmd('qa!')

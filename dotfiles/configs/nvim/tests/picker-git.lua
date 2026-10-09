local api = vim.api
local config = require('plugins.explorer.picker.config')
local buf = api.nvim_create_buf(false, true)
local win =
  api.nvim_open_win(buf, false, { relative = 'editor', row = 0, col = 0, width = 60, height = 10 })
local list = require('plugins.explorer.picker.list').new({ buf = buf, win = win }, {
  style = config.list.style,
  priority = config.list.priority,
  signs = { git = config.list.signs.git, selection = config.list.signs.selection },
})
local ns = api.nvim_create_namespace('PickerMarks')
local function sign(row)
  return api.nvim_buf_get_extmark_by_id(buf, ns, row, { details = true })[3]
end
list.replace({
  { path = '/a', display = 'a', git_status = 'modified' },
  { path = '/b', display = 'b', git_status = 'untracked' },
  { path = '/c', display = 'c', git_status = 'clean' },
})
assert(sign(1).sign_text:find('┃', 1, true))
local active = api.nvim_get_hl(0, { name = sign(1).sign_hl_group, link = false })
assert(
  active.fg
    == api.nvim_get_hl(0, { name = config.list.signs.git.highlights.modified, link = false }).fg
)
assert(
  active.bg
    == api.nvim_get_hl(0, { name = config.list.signs.selection.cursor_highlight, link = false }).bg
)
list.toggle_mark()
assert(sign(1).sign_text:find(config.list.signs.selection.sign, 1, true))
list.move(1)
assert(sign(1).sign_hl_group == config.list.signs.selection.highlight)
list.move(-1)
list.toggle_mark()
assert(sign(1).sign_text:find('┃', 1, true), 'Unmark must restore Git sign')
list.move(2)
assert(sign(3).sign_text:match('^ +$'), 'Clean current row needs continuous background')
assert(sign(1).sign_hl_group == config.list.signs.git.highlights.modified)
for status, glyph in pairs(config.list.signs.git.signs) do
  list.replace({ { path = '/a', display = 'a', git_status = status } })
  assert(vim.fn.strdisplaywidth(glyph) == 1)
  assert(sign(1).sign_text:find(glyph, 1, true))
  assert(glyph == (status == 'untracked' and '┆' or '┃'))
  if status:find('staged_', 1, true) == 1 then
    local foreground = api.nvim_get_hl(0, { name = sign(1).sign_hl_group, link = false }).fg
    local base =
      api.nvim_get_hl(0, { name = config.list.signs.git.highlights[status], link = false }).fg
    assert(foreground ~= base, 'Staged signs must have a muted foreground')
    list.replace({
      { path = '/a', display = 'a', git_status = status },
      { path = '/b', display = 'b' },
    })
    list.move(1)
    assert(api.nvim_get_hl(0, { name = sign(1).sign_hl_group, link = false }).fg == foreground)
  end
end
api.nvim_win_close(win, true)
api.nvim_buf_delete(buf, { force = true })
print('PASS Picker Git signs')
vim.cmd('qa!')

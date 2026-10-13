vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
local snapshot = require('picker.picker.snapshot')
local entry = {
  path = '/a',
  display = 'a',
  line = 3,
  col = 2,
  content = 'old snippet',
  content_matches = { { 2, 4 } },
}
local options = { cwd = '/', mode = 'grep', view = { icon = false } }
local session = Session.new({
  search = function()
    return { status = 'ready', total = 1, items = { entry } }
  end,
}, function() end, options.view, nil, true)
session:open()
session.selection:toggle_mark()
local input = assert(session.window:pane('input'))
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'latest unsearched input' })
local saved = snapshot.capture(session, options)
assert(saved.query == 'latest unsearched input' and saved.match_mode == 'plain')
assert(saved.page == 0 and saved.size == 100 and saved.index == nil)
assert(saved.current == nil)
session:refresh()
local coherent = snapshot.capture(session, options)
assert(coherent.current.path == '/a' and coherent.index == 1)
local controller = require('picker.picker.selection').new()
controller:restore_marks(saved.marks)
assert(controller:current() == nil and controller:marked_count() == 1)
saved.marks[1].display = 'changed display'
assert(controller:marked_items()[1].display == 'a')
assert(saved.marks[1].line == 3 and saved.marks[1].content_matches == nil)
entry.path = '/changed'
options.cwd = '/changed'
session:close()
vim.wait(100)
assert(coherent.current.path == '/a' and saved.marks[1].path == '/a' and saved.options.cwd == '/')
print('PASS resume snapshot copies options/locations and latest input without cached content')

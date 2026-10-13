vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
---@type picker.picker.PageSource
local source = {
  search = function(query, size, _, page)
    local items = {}
    if query ~= 'missing' then
      for i = page * size + 1, math.min(237, (page + 1) * size) do
        items[#items + 1] = { path = '/' .. i, display = tostring(i) }
      end
    end
    return { status = 'ready', items = items, total = query == 'missing' and 0 or 237 }
  end,
}
local origin = vim.api.nvim_get_current_win()
local before = {}
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  before[buf] = true
end
local count, chosen = 0, nil
local session = Session.new(source, function(entry)
  count = count + 1
  chosen = entry
end)
session:open()
-- Exercise native popup mappings rather than only direct object calls.
local function key(lhs)
  local mapping = vim.fn.maparg(lhs, 'i', false, true)
  assert(mapping.callback, lhs .. ' mapping missing')
  mapping.callback()
end
for _ = 1, 80 do
  key('<C-n>')
end
assert(session.selection:current().path == '/81')
key('<C-o>')
assert(session.selection:current().path == '/81', 'width-only layout change reset selection')
key('<C-o>')
vim.api.nvim_exec_autocmds('VimResized', {})
assert(session.selection:current().path == '/81')
key('<CR>')
session:close()
assert(vim.wait(1000, function()
  return count == 1
end))
assert(chosen and chosen.path == '/81')
assert(vim.api.nvim_get_current_win() == origin and #vim.api.nvim_list_wins() == 1)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'session leaked buffer')
end
print('PASS native navigation, layout preservation and once-only completion')

local cancelled = 0
local empty = Session.new(source, function(entry)
  assert(entry == nil)
  cancelled = cancelled + 1
end)
empty:open()
local input = empty.window:pane('input')
assert(input)
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'missing' })
key('<CR>')
assert(cancelled == 0 and empty.selection:current() == nil)
vim.api.nvim_set_current_win(origin)
assert(vim.wait(1000, function()
  return cancelled == 1
end))
assert(vim.api.nvim_get_current_win() == origin)
print('PASS latest-query confirmation and outside-focus cancellation')

local failures = 0
local failed = Session.new(source, function()
  failures = failures + 1
end)
failed:open(function(instance)
  instance:join_group('picker-session-test-missing')
end)
assert(vim.wait(1000, function()
  return failures == 1
end))
assert(#vim.api.nvim_list_wins() == 1)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'failed session leaked buffer')
end
print('PASS missing native group releases prepared resources')

local callbacks = 0
---@type picker.picker.Actions?
local retained
---@type picker.picker.Keymaps
local overrides = {
  i = {
    ['<C-n>'] = false,
    ['x'] = 'next',
    ['y'] = function(actions)
      retained = actions
      for name in pairs(actions) do
        assert(
          name == 'open'
            or name == 'quickfix'
            or name == 'mark'
            or name == 'confirm'
            or name == 'cancel'
            or name == 'move'
            or name == 'page'
            or name == 'toggle_preview'
            or name == 'scroll_preview'
            or name == 'cycle_match_mode'
        )
      end
      actions.move(2)
    end,
  },
}
local mapped = Session.new(source, function()
  callbacks = callbacks + 1
end, nil, overrides)
mapped:open()
assert(vim.fn.maparg('<C-n>', 'i', false, true).callback == nil)
key('x')
key('y')
assert(mapped.selection:current().path == '/4')
assert(overrides.i['<C-n>'] == false and overrides.i.x == 'next')
mapped:close()
assert(vim.wait(1000, function()
  return callbacks == 1
end))
assert(retained)
retained.move(20)
retained.confirm()
assert(callbacks == 1 and #vim.api.nvim_list_wins() == 1)
print('PASS mapping overrides expose only guarded Actions and retain caller config')

vim.o.mouse = 'a'
local mouse_done = 0
local mouse_session = Session.new(source, function()
  mouse_done = mouse_done + 1
end)
mouse_session:open()
local mouse_input = mouse_session.window:pane('input')
local mouse_list = mouse_session.window:pane('list')
assert(mouse_input and mouse_list)
vim.cmd.redraw()
local screen = vim.fn.screenpos(mouse_list.win, 3, 1)
vim.api.nvim_input_mouse('left', 'press', '', 0, screen.row - 1, screen.col - 1)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<LeftMouse>', true, false, true), 'xt', false)
assert(vim.wait(1000, function()
  return mouse_session.selection:current_index() == 3
end))
assert(mouse_done == 0 and vim.api.nvim_get_current_win() == mouse_input.win)
mouse_session:close()
assert(vim.wait(1000, function()
  return mouse_done == 1
end))
print('PASS mouse selects through Controller without confirming or losing input focus')

local decorated = Session.new(source, function() end)
decorated:open()
local decorated_list = decorated.window:pane('list')
local decorated_input = decorated.window:pane('input')
assert(decorated_list and decorated_input)
local namespaces = vim.api.nvim_get_namespaces()
key('<Tab>')
local marks = vim.api.nvim_buf_get_extmarks(
  decorated_list.buf,
  namespaces.PickerMarks,
  0,
  -1,
  { details = true }
)
assert(#marks == 1 and marks[1][2] == 0)
local status = vim.api.nvim_buf_get_extmarks(
  decorated_input.buf,
  namespaces.PickerStatus,
  0,
  -1,
  { details = true }
)
assert(#status == 1 and status[1][4].virt_text[1][1]:find('1 selected', 1, true))
key('<C-p>')
key('<Tab>')
assert(#vim.api.nvim_buf_get_extmarks(decorated_list.buf, namespaces.PickerMarks, 0, -1, {}) == 0)
vim.api.nvim_buf_set_lines(decorated_input.buf, 0, -1, false, { string.rep('界', 100) })
decorated:query_changed()
assert(#vim.api.nvim_buf_get_extmarks(decorated_input.buf, namespaces.PickerStatus, 0, -1, {}) == 0)
decorated:close()
assert(vim.wait(1000, function()
  return #vim.api.nvim_list_wins() == 1
end))
print('PASS visible marks, selected count and crowded-query status suppression')

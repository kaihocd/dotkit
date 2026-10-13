vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
local path = vim.fn.tempname() .. '.lua'
vim.fn.writefile({ 'local value = 42' }, path)
local ranges = { { 0, 5 } }
local session = Session.new({
  search = function()
    return {
      status = 'ready',
      total = 2,
      items = {
        { path = path, display = 'file', line = 1, content_matches = ranges },
        { path = path .. '-missing', display = 'missing' },
      },
    }
  end,
}, function() end)
session:open()
local input = vim.api.nvim_get_current_win()
session:resize(true)
local pane = assert(session.window:pane('preview'))
local function text()
  return vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1]
end
assert(vim.wait(2000, function()
  return text() == 'local value = 42'
end))
local syntax = vim.api.nvim_win_call(pane.win, function()
  return vim.fn.synIDattr(vim.fn.synID(1, 1, 1), 'name')
end)
assert(syntax ~= '', 'Lua preview keyword must have a syntax group under -u NONE')
assert(vim.api.nvim_get_current_win() == input)
assert(vim.wo[pane.win].number and not vim.wo[pane.win].relativenumber)
local namespace = vim.api.nvim_get_namespaces().PickerPreviewMatches
local function matches()
  return vim.api.nvim_buf_get_extmarks(pane.buf, namespace, 0, -1, { details = true })
end
assert(matches()[1][3] == 0 and matches()[1][4].end_col == 5)
local tick = vim.api.nvim_buf_get_changedtick(pane.buf)
ranges = { { 6, 11 } }
session:refresh()
assert(text() == 'local value = 42', 'same-item refresh must not flash Loading')
vim.wait(100)
assert(
  vim.api.nvim_buf_get_changedtick(pane.buf) == tick,
  'unchanged content must not rewrite preview'
)
assert(#matches() == 1 and matches()[1][3] == 6 and matches()[1][4].end_col == 11)
vim.fn.writefile({ 'local changed = 123' }, path)
session:refresh()
assert(
  vim.wait(2000, function()
    return text() == 'local changed = 123'
  end),
  'same-item refresh must still check the file version'
)
assert(vim.api.nvim_get_current_win() == input)
session:move(1)
assert(vim.wait(2000, function()
  return text():find('Unable to open', 1, true) ~= nil
end))
assert(vim.api.nvim_win_call(pane.win, function()
  return vim.fn.synID(1, 1, 1)
end) == 0, 'error messages must not retain previous file syntax')
assert(not vim.wo[pane.win].number, 'error messages must not show line numbers')
assert(#matches() == 0, 'error messages must clear match decorations')
session:move(-1)
session:resize(true)
assert(session.window:pane('preview') == nil)
session:resize(true)
pane = assert(session.window:pane('preview'))
assert(vim.wait(2000, function()
  return text() == 'local changed = 123'
end))
local many = {}
for i = 1, 200 do
  many[i] = '-- line ' .. i
end
vim.fn.writefile(many, path)
session:refresh()
assert(vim.wait(2000, function()
  return text() == '-- line 1'
end))
local function top()
  return vim.api.nvim_win_call(pane.win, function()
    return vim.fn.winsaveview().topline
  end)
end
local selected = session.selection:current_index()
vim.fn.maparg('<C-f>', 'i', false, true).callback()
assert(top() > 1, 'native preview-down action must scroll')
local scrolled = top()
session:refresh()
vim.wait(100)
assert(top() == scrolled, 'same-item refresh must preserve scroll')
session:resize(true)
session:resize(true)
pane = assert(session.window:pane('preview'))
vim.wait(100)
assert(top() == scrolled, 'recreated preview must restore scroll')
assert(vim.wo[pane.win].number and not vim.wo[pane.win].relativenumber)
vim.fn.maparg('<C-b>', 'i', false, true).callback()
assert(top() == 1)
assert(vim.api.nvim_get_current_win() == input and session.selection:current_index() == selected)
session.window:scroll_preview(10000)
assert(top() <= 200)
session.window:scroll_preview(-10000)
assert(top() == 1)
session:close()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
vim.fn.delete(path)
print('PASS preview UI content, movement, errors, focus, toggle and teardown')

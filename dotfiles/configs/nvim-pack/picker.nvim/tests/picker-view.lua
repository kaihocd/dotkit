vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local View = require('picker.picker.window')
local function resources()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    buffers[buf] = true
  end
  return buffers, #vim.api.nvim_list_wins()
end
local before, windows = resources()
local view = View.new({
  presentation = {
    messages = { empty = 'Nothing found', indexing = 'Searching…' },
  },
})
view:open()
assert(view:focused() and view:page_size() > 0)
local input = assert(view:pane('input'))
assert(vim.bo[input.buf].buftype == 'prompt')
assert(vim.fn.prompt_getprompt(input.buf) == '')
view:restore_query('中文 query', false)
assert(vim.api.nvim_buf_get_lines(input.buf, 0, -1, false)[1] == '中文 query')
view:render({ { path = '/a', display = 'a' }, { path = '/b', display = 'b' } }, 2)
local list = view:pane('list')
assert(list and vim.api.nvim_win_get_cursor(list.win)[1] == 2)
view:render({}, nil)
assert(vim.api.nvim_buf_get_lines(list.buf, 0, 1, false)[1]:find('Nothing found', 1, true))
assert(not vim.wo[list.win].cursorline)
view:close()
view:close()
assert(view:pane('list') == nil)
assert(#vim.api.nvim_list_wins() == windows)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'leaked owned buffer')
end
print('PASS View render, empty state and idempotent resource release')

local failed = View.new()
failed.popup:on('open', function()
  error('test open listener failure')
end)
assert(not pcall(failed.open, failed))
assert(#vim.api.nvim_list_wins() == windows)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'failed open leaked buffer')
end
print('PASS View open listener failure releases owned resources')

local popup = require('popup')
local custom = View.new({
  layout = function(panes, context)
    assert(context.width > 0 and context.height > 0)
    local children = { panes.input, panes.list }
    if panes.preview then
      children[#children + 1] = panes.preview
    end
    return popup.col({ children = children })
  end,
})
custom:open()
input = assert(custom:pane('input'))
local win = input.win
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'retained query' })
custom:toggle_preview()
assert(custom:pane('preview') and custom:pane('input').win == win)
assert(custom:query() == 'retained query')
custom:toggle_preview()
assert(custom:pane('preview') == nil)
custom:resize()
assert(custom:pane('input').win == win and custom:focused())
custom:close()
assert(#vim.api.nvim_list_wins() == windows)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'layout change leaked buffer')
end
print('PASS custom layout, preview toggle and resize retain input window and query')

assert(not pcall(View.new, {
  layout = function(panes)
    return panes.input
  end,
}))
assert(not pcall(View.new, {
  layout = function(panes)
    return popup.col({ children = { panes.input, panes.list, panes.list } })
  end,
}))
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  assert(before[buf], 'invalid layout leaked buffer')
end
print('PASS invalid layouts are rejected before opening without leaking buffers')

local config = require('picker.picker.config')
local native = vim.o.columns
local height = vim.o.lines
vim.o.columns, vim.o.lines = 100, 40
local narrow = View.new()
narrow:open()
narrow:toggle_preview()
local preview = narrow:pane('preview')
local results = narrow:pane('list')
assert(preview and results)
assert(
  vim.api.nvim_win_get_position(preview.win)[1] > vim.api.nvim_win_get_position(results.win)[1]
)
vim.o.lines = 10
narrow:resize()
assert(narrow:pane('preview') == nil)
vim.o.lines = 40
narrow:resize()
assert(narrow:pane('preview'), 'requested preview must return when height recovers')
narrow:close()
vim.o.columns = 260
local wide = View.new()
wide:open()
wide:toggle_preview()
preview, results = wide:pane('preview'), wide:pane('list')
assert(preview and results)
assert(
  vim.api.nvim_win_get_position(preview.win)[2] > vim.api.nvim_win_get_position(results.win)[2]
)
local entry = { path = '/a', display = 'alpha', git_status = 'modified' }
wide:render({ entry }, 1)
wide:marks({ entry }, function()
  return false
end)
assert(vim.api.nvim_buf_get_lines(results.buf, 0, 1, false)[1]:sub(1, 8) == '   alpha')
local ns = vim.api.nvim_get_namespaces().PickerMarks
local marks = vim.api.nvim_buf_get_extmarks(results.buf, ns, 0, -1, { details = true })
assert(marks[1][3] == 1 and marks[1][4].virt_text[1][1] == config.git.modified[1])
assert(
  marks[1][4].hl_mode == 'combine',
  'Git overlay must preserve underlying CursorLine background'
)
wide:marks({ entry }, function()
  return true
end)
marks = vim.api.nvim_buf_get_extmarks(results.buf, ns, 0, -1, { details = true })
assert(marks[1][3] == 1 and marks[1][4].virt_text[1][1] == '▊')
assert(
  marks[1][4].hl_mode == 'combine',
  'Tab overlay must preserve underlying CursorLine background'
)
wide:close()
vim.o.columns, vim.o.lines = native, height
print('PASS responsive preview visibility and fixed Git/mark slot with separator')

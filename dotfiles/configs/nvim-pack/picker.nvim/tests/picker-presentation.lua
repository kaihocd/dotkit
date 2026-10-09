vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local presentation = require('picker.picker.presentation')

for _, grep in ipairs({ false, true }) do
  local calls, formats = 0, 0
  local entries = {
    { path = '/a', display = 'a', line = 1, content = 'first' },
    { path = '/a', display = 'a', line = 2, content = 'second' },
  }
  local session = Session.new({
    search = function()
      calls = calls + 1
      return { status = 'ready', items = entries, total = 2 }
    end,
  }, function() end, {
    icon = false,
    presentation = {
      format = function(entry, context)
        formats = formats + 1
        assert(context.mode == (grep and 'grep' or 'files'))
        entry.path = '/mutated'
        return { content = { { tostring(entry.line) } } }
      end,
    },
  }, nil, grep)
  session:open()
  local pane = assert(session.window:pane('list'))
  local function text()
    return table.concat(vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false), '\n')
  end
  assert(text():find('1', 1, true))
  local searched, formatted = calls, formats
  local tick = vim.api.nvim_buf_get_changedtick(pane.buf)
  session:move(1)
  session:mark(0)
  assert(session.selection:current_index() == 2 and session.selection:marked_count() == 1)
  assert(calls == searched, 'selection must not search')
  assert(formats == formatted, 'selection must not invoke a custom formatter')
  assert(
    vim.api.nvim_buf_get_changedtick(pane.buf) == tick,
    'selection must not rewrite list content'
  )
  assert(session.selection:current().path == '/a', 'formatter mutated selection')
  if grep then
    assert(vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1]:find('a', 1, true))
    assert(vim.api.nvim_buf_line_count(pane.buf) == 3)
  end
  session:close()
  vim.wait(100, function()
    return #vim.api.nvim_list_wins() == 1
  end)
end
-- Fail through a real mapped action after resources and listeners are mounted.
local notification
local original_notify = vim.notify
local function notify(message)
  notification = message
end
vim.notify = notify
for _, invalid in ipairs({
  function()
    error('formatter failure')
  end,
  function()
    return { text = 'two\nlines' }
  end,
  function()
    return {
      text = '中',
      highlights = { { first = 1, last = 3, group = 'Title', priority = 100 } },
    }
  end,
}) do
  local buffers, events = {}, {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    buffers[buf] = true
  end
  for _, event in ipairs(vim.api.nvim_get_autocmds({})) do
    events[event.id] = true
  end
  local fail, completed = false, 0
  local session = Session.new({
    search = function()
      return { status = 'ready', total = 1, items = { { path = '/a', display = 'a' } } }
    end,
  }, function()
    completed = completed + 1
  end, {
    icon = false,
    presentation = {
      format = function()
        if fail then
          return invalid() or { content = { { 'unreachable' } } }
        end
        return { content = { { 'valid' } } }
      end,
    },
  }, { i = {
    ['<F5>'] = function(actions)
      actions.toggle_preview()
    end,
  } })
  session:open()
  notification = nil
  fail = true
  vim.fn.maparg('<F5>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return completed == 1
  end))
  assert(
    notification and (notification:find('format', 1, true) or notification:find('content', 1, true))
  )
  session:close()
  assert(completed == 1 and #vim.api.nvim_list_wins() == 1)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    assert(buffers[buf], 'leaked buffer')
  end
  for _, event in ipairs(vim.api.nvim_get_autocmds({})) do
    assert(events[event.id], 'leaked event')
  end
end
vim.notify = original_notify
print('PASS formatter errors release buffers, windows and events with once-only completion')

local configured = { messages = { empty = 'Empty' } }
local first = presentation.resolve(configured)
first.messages.empty = 'Changed'
assert(configured.messages.empty == 'Empty')
assert(presentation.resolve().messages.empty == 'No Item')
for _, invalid in ipairs({
  { messages = false },
  { status = { separator = 1 } },
  { format = true },
}) do
  assert(not pcall(presentation.resolve, invalid))
end
print(
  'PASS Session formatter movement, marks, grep entries, isolation and configuration validation'
)

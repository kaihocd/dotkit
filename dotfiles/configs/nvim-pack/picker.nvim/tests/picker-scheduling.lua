vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')

-- Drive the clock deterministically, but keep real Neovim windows and input events.
local original_defer = vim.defer_fn
local queue = {}
rawset(vim, 'defer_fn', function(callback, delay)
  queue[#queue + 1] = { callback = callback, delay = delay }
end)
local function drain()
  local pending = queue
  queue = {}
  for _, timer in ipairs(pending) do
    timer.callback()
  end
end
local calls, ready = {}, false
---@type picker.picker.PageSource
local source = {
  search = function(query)
    calls[#calls + 1] = query
    if not ready then
      return { status = 'indexing', items = {}, total = 0 }
    end
    return { status = 'ready', items = { { path = '/' .. query, display = query } }, total = 1 }
  end,
}
local completed = 0
local session = Session.new(source, function()
  completed = completed + 1
end)
session:open()
assert(#calls == 1 and #queue == 1 and queue[1].delay == 100)
local list = session.window:pane('list')
assert(list)
assert(vim.api.nvim_buf_get_lines(list.buf, 0, 1, false)[1]:find('Indexing', 1, true))
drain()
assert(#calls == 2 and #queue == 1)
local input = session.window:pane('input')
assert(input)
for _, query in ipairs({ 'a', 'ab', 'abc' }) do
  vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { query })
  vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input.buf })
end
assert(#calls == 2, 'input must not search synchronously')
ready = true
drain()
assert(#calls == 3 and calls[3] == 'abc', 'only latest input should survive old poll and debounce')
assert(#queue == 0, 'ready results should stop polling')
assert(session.selection:current().path == '/abc')
print('PASS indexing retries, latest-input debounce and ready stops polling')

vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'confirm now' })
vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input.buf })
session:confirm()
assert(calls[#calls] == 'confirm now', 'confirm must flush current query')
local before = #calls
drain()
assert(#calls == before, 'closed invocation ran a pending query')
assert(vim.wait(1000, function()
  return completed == 1
end))
print('PASS confirmation bypasses debounce and close invalidates pending work')

ready = false
local cancelled = 0
local polling = Session.new(source, function()
  cancelled = cancelled + 1
end)
polling:open()
assert(#queue == 1)
polling:close()
before = #calls
drain()
assert(#calls == before)
assert(vim.wait(1000, function()
  return cancelled == 1
end))
rawset(vim, 'defer_fn', original_defer)
assert(#vim.api.nvim_list_wins() == 1)
print('PASS close during indexing prevents further backend calls')

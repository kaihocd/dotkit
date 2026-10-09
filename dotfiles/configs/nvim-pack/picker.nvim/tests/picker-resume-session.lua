vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local saved = {
  options = { mode = 'grep' },
  query = 'old',
  match_mode = 'regex',
  preview = false,
  page = 2,
  size = 100,
  index = 1,
  marks = { { path = '/marked', display = 'marked' } },
}
local calls = {}
local source = {
  search = function(query, _, mode, offset)
    calls[#calls + 1] = { query, offset }
    assert(mode == 'regex')
    return {
      status = 'ready',
      total = 1,
      more = true,
      next_offset = offset + 13,
      items = { { path = '/' .. offset, display = tostring(offset) } },
    }
  end,
}
local session = Session.new(source, function() end, nil, nil, true)
session:open(nil, saved)
assert(vim.wait(2000, function()
  return session.selection:current().path == '/26'
end))
assert(session.selection:marked_count() == 1 and session.window:query() == 'old')
assert(vim.deep_equal(calls, { { 'old', 0 }, { 'old', 13 }, { 'old', 26 } }))
session:close()
vim.wait(100)
calls = {}
local interrupted = Session.new(source, function() end, nil, nil, true)
interrupted:open(nil, saved)
local input = assert(interrupted.window:pane('input'))
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'new' })
interrupted:query_changed()
assert(vim.wait(2000, function()
  return #calls >= 2
end))
vim.wait(100)
assert(vim.deep_equal(calls, { { 'old', 0 }, { 'new', 0 } }))
interrupted:close()
vim.wait(100)
calls = {}
local closed = Session.new(source, function() end, nil, nil, true)
closed:open(nil, saved)
closed:close()
vim.wait(100)
assert(#calls == 1 and #vim.api.nvim_list_wins() == 1)
for _, operation in ipairs({ 'move', 'confirm', 'resize' }) do
  calls = {}
  local chosen
  local interactive = Session.new(source, function(entry)
    chosen = entry
  end, nil, nil, true)
  interactive:open(nil, saved)
  if operation == 'move' then
    interactive:move(0)
  elseif operation == 'confirm' then
    interactive:confirm()
  else
    interactive:resize()
  end
  vim.wait(100)
  for _, call in ipairs(calls) do
    assert(call[2] == 0, 'interaction must cancel the queued next page')
  end
  if operation == 'confirm' then
    assert(chosen and chosen.path == '/0')
  else
    assert(interactive.selection:current().path == '/0')
    interactive:close()
  end
  vim.wait(100)
end
assert(#vim.api.nvim_list_wins() == 1)
print('PASS Session resume steps, marks, query/close guards and interaction cancels queued pages')

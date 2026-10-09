vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local calls = {}
local expected_mode = 'plain'
local session = Session.new({
  search = function(query, size, mode, offset)
    assert(size == 100 and mode == expected_mode)
    calls[#calls + 1] = offset
    if query == '' then
      return { status = 'ready', items = {}, total = 0 }
    end
    return {
      status = 'ready',
      total = 2,
      more = offset == 0,
      next_offset = offset == 0 and 42 or 0,
      items = {
        { path = '/a', display = 'a', line = offset + 1, content = 'match' },
        { path = '/b', display = 'b', line = offset + 2, content = 'match' },
      },
    }
  end,
}, function() end, nil, nil, true)
session:open()
local input = assert(session.window:pane('input'))
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'match' })
session:refresh()
local list = assert(session.window:pane('list'))
assert(vim.api.nvim_win_get_cursor(list.win)[1] == 2)
vim.fn.maparg('<C-d>', 'i', false, true).callback()
assert(session.selection:current_index() == 2 and calls[#calls] == 0)
vim.fn.maparg('<C-d>', 'i', false, true).callback()
assert(calls[#calls] == 42 and session.selection:current_index() == 1)
session:move(-1)
assert(session.selection:current_index() == 2 and session.selection:current().line == 2)
session:resize()
assert(session.selection:current().line == 2)
session.selection:toggle_mark()
local marked = session.selection:marked_count()
for _, mode in ipairs({ 'regex', 'fuzzy', 'plain' }) do
  expected_mode = mode
  assert(vim.fn.maparg('<C-r>', 'i') == '')
  vim.fn.maparg('<C-l>', 'i', false, true).callback()
  assert(calls[#calls] == 0 and session.window:query() == 'match')
  assert(session.selection:marked_count() == marked)
  local prefix = vim.api.nvim_buf_get_extmarks(
    input.buf,
    vim.api.nvim_get_namespaces().PickerInput,
    0,
    -1,
    { details = true }
  )
  assert(prefix[1][4].virt_text[2][1] == ' Grep ')
  local status = vim.api.nvim_buf_get_extmarks(
    input.buf,
    vim.api.nvim_get_namespaces().PickerStatus,
    0,
    -1,
    { details = true }
  )
  assert(status[1][4].virt_text[1][1] == mode .. ' · 2+ · ' .. marked .. ' selected ')
end
session:close()
assert(vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end))
print('PASS grep session fixed page size, display-row paging, continuation and resize')

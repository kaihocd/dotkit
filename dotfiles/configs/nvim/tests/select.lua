local api = vim.api
require('native-ui.select').setup()
local origin = api.nvim_get_current_win()
local function pane(filetype)
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == filetype then
      return win, api.nvim_win_get_buf(win)
    end
  end
  error('Missing pane: ' .. filetype)
end
local function press(key)
  vim.fn.maparg(key, 'i', false, true).callback()
end
local calls = 0
local items = { 'Alpha', 'Beta [x]', 'Beta [x]' }
vim.ui.select(items, {}, function(item, index)
  assert(item == items[3] and index == 3)
  calls = calls + 1
end)
local query, buf = pane('ui-select-input')
local win, list_buf = pane('ui-select')
local query_config = api.nvim_win_get_config(query)
local list_config = api.nvim_win_get_config(win)
assert(query_config.width == list_config.width)
assert(not query_config.title, 'No border title')
local function assert_prefix(buffer, expected)
  local ns = api.nvim_create_namespace('NativeInputList')
  local mark = api.nvim_buf_get_extmark_by_id(buffer, ns, 1, { details = true })
  assert(vim.deep_equal(mark[3].virt_text, {
    { expected, 'FloatTitle' },
    { ' ', 'NormalFloat' },
  }))
end
assert_prefix(buf, ' Select ')
assert(api.nvim_buf_get_lines(list_buf, 0, 1, false)[1] == 'Select an item')
assert(api.nvim_win_get_cursor(win)[1] == 2)
press('<C-p>')
assert(api.nvim_win_get_cursor(win)[1] == 2, 'Navigation must skip the prompt')
local marks = api.nvim_buf_get_extmarks(
  list_buf,
  api.nvim_create_namespace('NativeList'),
  0,
  -1,
  { details = true }
)
assert(marks[1][4].hl_group == 'Comment')
assert(list_config.row == query_config.row + query_config.height + 1)
assert(query_config.col >= 0)
assert(query_config.col + query_config.width + 2 <= vim.o.columns)
local function search(text)
  api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  api.nvim_exec_autocmds('TextChangedI', { buffer = buf })
end
search('[X]')
assert(api.nvim_buf_get_lines(list_buf, 1, 2, false)[1] == '   2. Beta [x]')
press('<C-n>')
api.nvim_set_current_win(win)
api.nvim_set_current_win(query)
assert(calls == 0)
press('<C-j>')
assert(vim.wait(1000, function()
  return calls == 1
end))
assert(api.nvim_get_current_win() == origin)

vim.ui.select(items, { prompt = 'Choose 100%: ' }, function(item, index)
  assert(item == nil and index == nil)
  calls = calls + 1
end)
query, buf = pane('ui-select-input')
win, list_buf = pane('ui-select')
assert_prefix(buf, ' Select ')
assert(api.nvim_buf_get_lines(list_buf, 0, 1, false)[1] == 'Choose 100%')
api.nvim_win_set_cursor(win, { 1, 0 })
press('<C-j>')
assert(calls == 1, 'The prompt cannot be confirmed')
search('3')
assert_prefix(buf, ' Select ')
assert(api.nvim_buf_get_lines(list_buf, 1, 2, false)[1] == '   3. Beta [x]')
search('no match')
assert(vim.deep_equal(api.nvim_buf_get_lines(list_buf, 0, -1, false), { 'Choose 100%' }))
press('<C-j>')
assert(calls == 1)
search('')
assert(api.nvim_buf_line_count(list_buf) == 4)
api.nvim_set_current_win(origin)
assert(vim.wait(1000, function()
  return calls == 2
end))
assert(not api.nvim_win_is_valid(win))
vim.ui.select({}, {}, function(item)
  assert(item == nil)
  calls = calls + 1
end)
assert(calls == 3)
vim.ui.select({ false }, {}, function(item, index)
  assert(item == false and index == 1)
  calls = calls + 1
end)
press('<C-j>')
press('<C-j>')
assert(vim.wait(1000, function()
  return calls == 4
end))
vim.ui.select(items, {}, function(item)
  assert(item == nil)
  calls = calls + 1
end)
win = pane('ui-select')
api.nvim_win_close(win, true)
assert(vim.wait(1000, function()
  return calls == 5
end))
vim.ui.select(items, {}, function(item)
  assert(item == nil)
  calls = calls + 1
end)
vim.ui.select({ 'replacement' }, {}, function(item)
  assert(item == 'replacement')
  calls = calls + 1
end)
assert(vim.wait(1000, function()
  return calls == 6 and vim.bo.filetype == 'ui-select-input'
end))
press('<C-j>')
assert(vim.wait(1000, function()
  return calls == 7
end))
-- A deferred confirmation must not steal focus from a subsequent window switch.
vim.cmd('vsplit')
local destination = api.nvim_get_current_win()
api.nvim_set_current_win(origin)
vim.ui.select({ 'chosen' }, {}, function(item)
  assert(item == 'chosen')
  calls = calls + 1
end)
press('<C-j>')
api.nvim_set_current_win(destination)
assert(vim.wait(1000, function()
  return calls == 8
end))
assert(api.nvim_get_current_win() == destination)
print('PASS Select regression')

vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH)
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local api = vim.api

local function press(key)
  api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, false, true), 'xt', false)
end
local original_windows = #api.nvim_list_wins()

require('picker').setup()
require('picker').select({ 'one two', 'one three' }, {}, function() end)
vim.wait(50)
assert(vim.fn.maparg('<C-w>', 'i'):lower() == '<c-s-w>')
press('ione two<C-w><Esc>')
assert(api.nvim_get_current_line() == 'one ')
press('<C-c>')
vim.wait(50)
assert(#api.nvim_list_wins() == original_windows)
print('PASS Select input Ctrl-w deletes the previous word')

-- A failed second pane must release the already-open root/input and scratch buffers.
local buffers_before = {}
for _, buf in ipairs(api.nvim_list_bufs()) do
  buffers_before[buf] = true
end
local failure_calls = 0
require('picker').select({ 'Apple' }, {
  view = {
    layout = function()
      return {}
    end,
  },
}, function(item, index)
  assert(item == nil and index == nil)
  failure_calls = failure_calls + 1
end)
assert(vim.wait(1000, function()
  return failure_calls == 1
end))
assert(#api.nvim_list_wins() == original_windows)
for _, buf in ipairs(api.nvim_list_bufs()) do
  assert(buffers_before[buf], 'failed open leaked buffer ' .. buf)
end
-- A failing later open listener must remove listeners installed earlier.
local View = require('picker.select.window')
local create_view = View.new
local external = api.nvim_get_current_win()
rawset(View, 'new', function(...)
  local window = create_view(...)
  local instance = window.popup
  local open = instance.open
  instance.open = function(self)
    self:on('open', function()
      api.nvim_set_current_win(external)
      error('test: fail after listeners were installed')
    end)
    return open(self)
  end
  return window
end)
local listener_failure_calls = 0
local caller_buf = api.nvim_create_buf(false, true)
require('picker').select({ 'Apple' }, {
  view = {},
}, function(item, index)
  assert(item == nil and index == nil)
  listener_failure_calls = listener_failure_calls + 1
end)
rawset(View, 'new', create_view)
assert(vim.wait(1000, function()
  return listener_failure_calls == 1
end))
assert(api.nvim_get_current_win() == external)
assert(api.nvim_buf_is_valid(caller_buf), 'caller buffer must survive failure')
api.nvim_buf_delete(caller_buf, { force = true })
for _, event in ipairs({ 'TextChangedI', 'WinEnter' }) do
  for _, autocmd in ipairs(api.nvim_get_autocmds({ event = event })) do
    assert(autocmd.desc ~= 'Update Select list from input')
    assert(autocmd.desc ~= 'Close Select when focus leaves its panes')
  end
end
assert(#api.nvim_list_wins() == original_windows)
for _, buf in ipairs(api.nvim_list_bufs()) do
  assert(buffers_before[buf], 'open listener failure leaked buffer ' .. buf)
end
vim.wait(50)
assert(failure_calls == 1 and listener_failure_calls == 1)
print('PASS partial mount and open listener failures release owned resources once')

-- Use popup's existing on_join policy, without exposing Select's instance.
local popup = require('popup')
local group = popup.group('select-test-single', {
  on_join = function(instance, members)
    instance:on('open', function()
      for _, other in ipairs(vim.list_extend({}, members.instances)) do
        if other ~= instance and other:is_open() then
          other:close()
        end
      end
    end)
  end,
})
local replaced_calls = 0
require('picker').select({ 'Apple' }, {
  on_instance = function(instance)
    instance:join_group('select-test-single')
  end,
}, function(item, index)
  assert(item == nil and index == nil)
  replaced_calls = replaced_calls + 1
end)
assert(#group.instances == 1)
local replacement = popup.root({
  row = 0,
  col = 0,
  width = 20,
  height = 2,
  layout = popup.pane({ id = 'replacement', enter = true }),
})
replacement:join_group('select-test-single')
replacement:open()
local replacement_win = api.nvim_get_current_win()
assert(vim.wait(1000, function()
  return replaced_calls == 1
end))
assert(replacement:is_open() and api.nvim_get_current_win() == replacement_win)
assert(#group.instances == 1 and group.instances[1] == replacement)
replacement:leave_group()
replacement:close()

local missing_calls = 0
require('picker').select({ 'Apple' }, {
  on_instance = function(instance)
    instance:join_group('select-test-missing')
  end,
}, function(item, index)
  assert(item == nil and index == nil)
  missing_calls = missing_calls + 1
end)
assert(vim.wait(1000, function()
  return missing_calls == 1
end))
assert(#api.nvim_list_wins() == original_windows)
for _, buf in ipairs(api.nvim_list_bufs()) do
  assert(buffers_before[buf], 'group lifecycle leaked buffer ' .. buf)
end
vim.wait(50)
assert(replaced_calls == 1 and missing_calls == 1)
print('PASS native group replacement and missing-group cleanup')

local calls = 0
local choice, choice_index

require('picker').select(
  { 'Apple', 'Banana', 'Apricot' },
  { prompt = 'Fruit' },
  function(item, index)
    calls = calls + 1
    choice, choice_index = item, index
  end
)

local input = api.nvim_get_current_buf()
assert(vim.bo[input].filetype == 'picker-select-input')
assert(api.nvim_win_get_height(api.nvim_get_current_win()) == 1, 'input content height must be one')
local namespace = api.nvim_create_namespace('PickerSelect')
local prefix = api.nvim_buf_get_extmarks(input, namespace, 0, -1, { details = true })[1]
assert(prefix[4].right_gravity == false, 'prefix must stay before inserted text')
api.nvim_buf_set_text(input, 0, 0, 0, 0, { 'Ap' })
local moved_prefix = api.nvim_buf_get_extmarks(input, namespace, 0, -1, { details = true })[1]
assert(moved_prefix[3] == 0, 'typing must not move the prefix after the query')
api.nvim_buf_set_lines(input, 0, -1, false, { '' })
local list
for _, win in ipairs(api.nvim_list_wins()) do
  local buf = api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype == 'picker-select' then
    list = buf
    assert(not api.nvim_win_get_config(win).focusable)
    assert(api.nvim_win_get_cursor(win)[1] == 1)
  end
end
assert(list, 'list pane must exist')
assert(vim.deep_equal(api.nvim_buf_get_lines(list, 0, -1, false), {
  '  1. Apple ',
  '  2. Banana ',
  '  3. Apricot ',
}))

local enter = api.nvim_replace_termcodes('<CR>', true, false, true)
api.nvim_feedkeys(enter, 'xt', false)
assert(
  vim.wait(1000, function()
    return calls == 1 and #api.nvim_list_wins() == original_windows
  end),
  'confirmation must close the popup and call back once'
)
assert(choice == 'Apple' and choice_index == 1)
assert(not api.nvim_buf_is_valid(input))
assert(not api.nvim_buf_is_valid(list))
print('PASS Select opens, confirms the first item, and releases its panes')

-- Empty queries must not submit stale choices, even before TextChanged fires.
local empty_calls = 0
require('picker').select({ 'Apple' }, {}, function(item, index)
  empty_calls = empty_calls + 1
  assert(item == nil and index == nil)
end)
local empty_input = api.nvim_get_current_buf()
api.nvim_buf_set_lines(empty_input, 0, -1, false, { 'missing' })
press('<CR>')
assert(empty_calls == 0)
assert(api.nvim_buf_is_valid(empty_input))
press('<C-c>')
assert(vim.wait(1000, function()
  return empty_calls == 1
end))
for _, autocmd in ipairs(api.nvim_get_autocmds({ event = 'TextChangedI' })) do
  assert(autocmd.desc ~= 'Update Select list from input')
end
print('PASS empty results do not confirm stale choices')

-- Filtering and movement must use the same current item as confirmation.
local filtered_choice, filtered_index
require('picker').select(
  { 'Apple', 'Banana', 'Apricot' },
  { prompt = 'Fruit' },
  function(item, index)
    filtered_choice, filtered_index = item, index
  end
)
local query_buf = api.nvim_get_current_buf()
local list_win
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    list_win = win
  end
end
assert(list_win)
api.nvim_buf_set_lines(query_buf, 0, -1, false, { 'Ap' })
api.nvim_exec_autocmds('TextChangedI', { buffer = query_buf })
assert(vim.deep_equal(api.nvim_buf_get_lines(api.nvim_win_get_buf(list_win), 0, -1, false), {
  '  1. Apple ',
  '  3. Apricot ',
}))
press('<C-n>')
assert(api.nvim_win_get_cursor(list_win)[1] == 2)
press('<C-p>')
assert(api.nvim_win_get_cursor(list_win)[1] == 1)
press('<C-n>')
press('<C-j>')
assert(vim.wait(1000, function()
  return filtered_index ~= nil
end))
assert(filtered_choice == 'Apricot' and filtered_index == 3)
print('PASS filter, move, and confirm original identity')

local many = {}
for index = 1, 50 do
  many[index] = 'Item ' .. index
end
local scrolled_index
require('picker').select(many, {}, function(_, index)
  scrolled_index = index
end)
local focused_win = api.nvim_get_current_win()
local scrolling_win
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    scrolling_win = win
  end
end
assert(scrolling_win)
assert(api.nvim_win_get_height(scrolling_win) == 8, 'default list shows eight items')
press('<C-d>')
assert(api.nvim_win_get_cursor(scrolling_win)[1] == 5)
press('<C-u>')
assert(api.nvim_win_get_cursor(scrolling_win)[1] == 1)
for _ = 1, 60 do
  press('<C-n>')
end
assert(api.nvim_win_get_cursor(scrolling_win)[1] == 50)
assert(api.nvim_get_current_win() == focused_win)
local bottom = api.nvim_win_call(scrolling_win, function()
  return vim.fn.line('w$')
end)
assert(bottom == 50, 'last selected item must be visible')
press('<CR>')
assert(vim.wait(1000, function()
  return scrolled_index == 50
end))
print('PASS movement clamps and scrolls without moving focus')

-- Position follows the original cursor and flips above near the bottom.
local origin_win = api.nvim_get_current_win()
local origin_buf = api.nvim_get_current_buf()
api.nvim_buf_set_lines(origin_buf, 0, -1, false, many)
for _, line in ipairs({ 1, 50 }) do
  api.nvim_win_set_cursor(origin_win, { line, 0 })
  vim.cmd(line == 1 and 'normal! zt' or 'normal! zb')
  vim.cmd.redraw()
  local anchor = vim.fn.screenpos(origin_win, line, 1).row - 1
  require('picker').select({ 'Apple' }, {}, function() end)
  local position = api.nvim_win_get_config(api.nvim_get_current_win()).row
  if line == 1 then
    assert(position > anchor)
  else
    assert(position < anchor)
  end
  press('<C-c>')
  assert(vim.wait(1000, function()
    return #api.nvim_list_wins() == original_windows
  end))
end
api.nvim_win_set_cursor(origin_win, { 1, 0 })
vim.cmd('normal! zt')
vim.cmd.redraw()

-- Native overrides are copied and do not alter the next invocation.
local custom = {
  max_items = 3,
  prefix = { text = ' Pick ', highlight = 'Title' },
  layout = function(panes)
    panes.input.win_config = { title = 'Query', title_pos = 'center' }
    return require('popup').col({ children = { panes.input, panes.prompt, panes.list } })
  end,
}
local custom_before = vim.deepcopy(custom)
require('picker').select(many, { view = custom }, function() end)
local custom_input = api.nvim_get_current_win()
assert(api.nvim_win_get_config(custom_input).title[1][1] == 'Query')
local custom_list
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    custom_list = win
  end
end
assert(custom_list)
assert(api.nvim_win_get_height(custom_list) == 3)
local before_filter = api.nvim_win_get_config(custom_list)
api.nvim_buf_set_lines(api.nvim_get_current_buf(), 0, -1, false, { 'Item 50' })
api.nvim_exec_autocmds('TextChangedI', { buffer = api.nvim_get_current_buf() })
assert(vim.deep_equal(api.nvim_win_get_config(custom_list), before_filter))
assert(vim.deep_equal(custom, custom_before))
press('<C-c>')
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == original_windows
end))
require('picker').select(many, {}, function() end)
assert(api.nvim_win_get_config(api.nvim_get_current_win()).title == nil)
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    assert(api.nvim_win_get_height(win) == 8)
  end
end
press('<C-c>')
assert(vim.wait(1000, function()
  return #api.nvim_list_wins() == original_windows
end))
print('PASS native overrides, stable filtering geometry, and configuration isolation')

-- Insets and clipping apply equally to prompt and Unicode item text.
local padded_choice
local long_text = string.rep('中文', 20)
require('picker').select({ 'Apple', 'Banana', long_text }, {
  prompt = long_text,
  view = { min_width = 12, max_width = 12, padding = { left = 2, right = 2 } },
}, function(item, index)
  assert(item == long_text)
  padded_choice = index
end)
local padded_input = api.nvim_get_current_buf()
local padded_list
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    padded_list = win
  end
end
assert(padded_list)
local padded_lines = api.nvim_buf_get_lines(api.nvim_win_get_buf(padded_list), 0, -1, false)
for index, text in ipairs(padded_lines) do
  local padding = index == 1 and ' ' or '  '
  assert(text:sub(1, #padding) == padding and text:sub(-#padding) == padding)
  assert(vim.fn.strdisplaywidth(text) <= 12)
end
-- Prompt is rendered in its own wrapping pane.
assert(padded_lines[3]:find('…', 1, true))
press('<C-n>')
press('<C-n>')
local list_buf = api.nvim_win_get_buf(padded_list)
local detail_geometry = api.nvim_win_get_config(padded_list)
local hint_namespace = api.nvim_create_namespace('PickerSelectHint')
assert(
  #api.nvim_buf_get_extmarks(padded_input, hint_namespace, 0, -1, {}) == 0,
  'hide hint in narrow input'
)
press('<C-l>')
local detail_window = nil
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select-detail' then
    detail_window = win
  end
end
assert(detail_window)
local detail_buf = api.nvim_win_get_buf(detail_window)
local foreign_namespace = api.nvim_create_namespace('SelectTestForeign')
local foreign_mark = api.nvim_buf_set_extmark(detail_buf, foreign_namespace, 0, 0, {})
local list_namespace = api.nvim_create_namespace('PickerList')
assert(vim.wo[detail_window].wrap)
assert(#api.nvim_buf_get_extmarks(list_buf, list_namespace, 0, -1, {}) > 0)
assert(
  #api.nvim_buf_get_extmark_by_id(detail_buf, foreign_namespace, foreign_mark, {}) == 2,
  'detail must not clear another namespace'
)
assert(api.nvim_win_get_config(detail_window).footer == nil)
assert(api.nvim_buf_get_lines(detail_buf, 0, -1, false)[1] == long_text)
press('<C-d>')
assert(api.nvim_win_get_cursor(detail_window)[2] > 0)
assert(vim.deep_equal(api.nvim_buf_get_lines(list_buf, 0, -1, false), padded_lines))
press('<C-u>')
press('<C-l>')
for _, win in ipairs(api.nvim_list_wins()) do
  if api.nvim_win_get_buf(win) == list_buf then
    padded_list = win
  end
end
assert(not vim.wo[padded_list].wrap)
assert(#api.nvim_buf_get_extmarks(list_buf, list_namespace, 0, -1, {}) > 0)
assert(
  #api.nvim_buf_get_extmark_by_id(detail_buf, foreign_namespace, foreign_mark, {}) == 2,
  'closing detail must not clear another namespace'
)
assert(vim.deep_equal(api.nvim_win_get_config(padded_list), detail_geometry))
assert(
  vim.deep_equal(
    api.nvim_buf_get_lines(api.nvim_win_get_buf(padded_list), 0, -1, false),
    padded_lines
  )
)
assert(api.nvim_win_get_cursor(padded_list)[1] == 3)
press('<C-l>')
press('<C-p>')
for _, win in ipairs(api.nvim_list_wins()) do
  if api.nvim_win_get_buf(win) == list_buf then
    padded_list = win
  end
end
assert(not vim.wo[padded_list].wrap)
assert(api.nvim_win_get_cursor(padded_list)[1] == 2)
press('<C-l>')
api.nvim_buf_set_lines(padded_input, 0, -1, false, { '中文' })
api.nvim_exec_autocmds('TextChangedI', { buffer = padded_input })
assert(not vim.wo[padded_list].wrap, 'query changes leave detail mode')
local filtered_line = api.nvim_buf_get_lines(api.nvim_win_get_buf(padded_list), 0, 1, false)[1]
assert(filtered_line:sub(1, 2) == '  ' and filtered_line:sub(-2) == '  ')
press('<C-l>')
press('<CR>')
assert(vim.wait(1000, function()
  return padded_choice == 3
end))
print('PASS row padding and Unicode clipping')

local List = require('picker.list')
local style = { padding = { left = 1, right = 1 } }
for _, text in ipairs({ 'Apple\tBanana', '界\t界', 'A\r\nB' }) do
  local normalized = (text:gsub('[\r\n\t]', ' '))
  local width = vim.fn.strdisplaywidth(normalized) + 2
  assert(List.measure(text, style) == width)
  assert(not List.is_clipped(text, width, style))
  assert(List.is_clipped(text, width - 1, style))
  local pane = popup.root({
    row = 0,
    col = 0,
    width = width,
    height = 1,
    layout = popup.pane({ id = 'row' }),
  })
  pane:open()
  local row = assert(pane:pane('row'))
  List.render(row, { { content = { { text } } } }, style)
  assert(api.nvim_buf_get_lines(row.buf, 0, 1, false)[1] == ' ' .. normalized .. ' ')
  pane:close()
end
assert(not List.is_clipped('', 1, style), 'padding alone must not imply hidden text')
assert(List.is_clipped('A', 1, style))
print('PASS measurement, rendering and clipping share single-line width rules')

local Config = require('picker.select.config')
local resolved = Config.options({ padding = {}, highlights = {} })
assert(resolved and resolved.padding.left == 2 and resolved.highlights.hint == 'Comment')
local rejected, problem = Config.options({ padding = { left = -1 } })
assert(rejected == nil and problem and problem:find('view.padding.left', 1, true))
local notified
local notify = vim.notify
rawset(vim, 'notify', function(message)
  notified = message
end)
local invalid_calls = 0
require('picker').select({ 'Apple' }, { view = { padding = { left = -1 } } }, function(item, index)
  assert(item == nil and index == nil)
  invalid_calls = invalid_calls + 1
end)
rawset(vim, 'notify', notify)
assert(invalid_calls == 1 and notified:find('view.padding.left', 1, true))
assert(#api.nvim_list_wins() == original_windows)
print('PASS invalid display configuration reports its option without opening windows')

local Bindings = require('picker.select.bindings')
local function detail_key(overrides)
  local _, label =
    Bindings.resolve(require('picker.config').resolve('select', { keymaps = overrides }).keymaps)
  return label
end
assert(detail_key({ i = { ['<C-l>'] = false }, n = { ['<C-l>'] = false } }) == nil)
assert(detail_key({
  i = { ['<C-l>'] = false, ['<Tab>'] = 'toggle_detail' },
  n = { ['<C-l>'] = false, ['<Tab>'] = 'toggle_detail' },
}) == '<Tab>')

require('picker').select({ long_text }, {
  view = { min_width = 40, max_width = 40, highlights = { hint = 'Special' } },
}, function() end)
local hint_input = api.nvim_get_current_buf()
local function hint_mark()
  return api.nvim_buf_get_extmarks(hint_input, hint_namespace, 0, -1, { details = true })[1]
end
assert(hint_mark()[4].virt_text[1][1] == '<C-l>: full text ')
assert(hint_mark()[4].virt_text[1][2] == 'Special')
assert(hint_mark()[4].virt_text_pos == 'right_align')
press('<C-l>')
assert(hint_mark()[4].virt_text[1][1] == '<C-l>: back ')
api.nvim_buf_set_lines(hint_input, 0, -1, false, { string.rep('中', 18) })
api.nvim_exec_autocmds('TextChangedI', { buffer = hint_input })
assert(hint_mark() == nil)
api.nvim_buf_set_lines(hint_input, 0, -1, false, { '' })
api.nvim_exec_autocmds('TextChangedI', { buffer = hint_input })
assert(hint_mark() ~= nil)
press('<C-c>')
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(hint_input)
end))
print('PASS input hint placement, highlight, and space constraints')

local outside = api.nvim_get_current_win()
local lost_focus_calls = 0
require('picker').select({ 'Apple' }, {}, function(item, index)
  assert(item == nil and index == nil)
  lost_focus_calls = lost_focus_calls + 1
end)
api.nvim_set_current_win(outside)
assert(vim.wait(1000, function()
  return lost_focus_calls == 1
end))
assert(api.nvim_get_current_win() == outside)
assert(#api.nvim_list_wins() == original_windows)
print('PASS losing focus cancels without stealing focus')

vim.o.mouse = 'a'
local mouse_choice
require('picker').select({ 'Apple', 'Banana' }, {}, function(_, index)
  mouse_choice = index
end)
local mouse_input = api.nvim_get_current_win()
local mouse_list
for _, win in ipairs(api.nvim_list_wins()) do
  if vim.bo[api.nvim_win_get_buf(win)].filetype == 'picker-select' then
    mouse_list = win
  end
end
assert(mouse_list)
vim.cmd.redraw()
local screen = vim.fn.screenpos(mouse_list, 2, 1)
api.nvim_input_mouse('left', 'press', '', 0, screen.row - 1, screen.col - 1)
press('<LeftMouse>')
vim.wait(100, function()
  return api.nvim_win_get_cursor(mouse_list)[1] == 2
end)
assert(api.nvim_win_get_cursor(mouse_list)[1] == 2, 'mouse selects Banana')
assert(api.nvim_get_current_win() == mouse_input)
press('<CR>')
assert(vim.wait(1000, function()
  return mouse_choice == 2
end))
print('PASS mouse selects through the controller and keeps input focus')

local remapped_choice
require('picker').select({ 'Apple', 'Banana' }, {
  keymaps = {
    n = {
      ['<C-n>'] = false,
      ['j'] = 'next',
      ['x'] = function(actions)
        actions.move(-1)
        local item, index = actions.choice()
        assert(item == 'Apple' and index == 1)
        actions.move(1)
        actions.confirm()
        actions.cancel()
      end,
    },
  },
}, function(_, index)
  remapped_choice = index
end)
press('<C-n>')
press('j')
press('x')
assert(vim.wait(1000, function()
  return remapped_choice == 2
end))
print('PASS custom action mappings')

for _, key in ipairs({ '<C-j>', '<C-c>', '<Esc>' }) do
  local count = 0
  local selected, selected_index
  require('picker').select({ 'Apple' }, {}, function(item, index)
    count = count + 1
    selected, selected_index = item, index
  end)

  api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, false, true), 'xt', false)
  assert(
    vim.wait(1000, function()
      return count == 1 and #api.nvim_list_wins() == original_windows
    end),
    key .. ' must finish once and close the popup'
  )

  if key == '<C-j>' then
    assert(selected == 'Apple' and selected_index == 1)
  else
    assert(selected == nil and selected_index == nil)
  end
  print('PASS ' .. key)
end

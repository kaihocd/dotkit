vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Session = require('picker.picker.panel')
local group = require('popup').group('picker-replacement-test', {
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
local source = {
  search = function()
    return { status = 'ready', total = 1, items = { { path = '/a', display = 'a' } } }
  end,
}
local baseline = #vim.api.nvim_get_autocmds({ event = 'ColorScheme' })
local first_calls, second_calls, third_calls = 0, 0, 0
local first = Session.new(source, function(entry)
  assert(entry == nil)
  first_calls = first_calls + 1
end)
first:open(function(instance)
  instance:join_group(group.name)
end)
local old_input = assert(assert(first.window:pane('input')).buf)
vim.api.nvim_buf_set_lines(old_input, 0, -1, false, { 'replacement query 中文' })
local saved
first:save_on_close(function()
  assert(
    vim.api.nvim_buf_is_valid(old_input),
    'replacement must capture before input buffer release'
  )
  saved = require('picker.picker.snapshot').capture(first, { mode = 'files', cwd = '/' })
end)
local third
local second = Session.new(source, function(entry)
  second_calls = second_calls + 1
  assert(entry and entry.path == '/a')
  assert(#group.instances == 0, 'completion must run after group removal')
  third = Session.new(source, function()
    third_calls = third_calls + 1
  end)
  third:open(function(instance)
    instance:join_group(group.name)
  end)
end)
second:open(function(instance)
  instance:join_group(group.name)
end)
local input = assert(second.window:pane('input')).win
assert(vim.wait(2000, function()
  return first_calls == 1
end))
assert(not vim.api.nvim_buf_is_valid(old_input))
assert(saved and saved.query == 'replacement query 中文')
assert(
  saved.current == nil and saved.index == nil,
  'unsearched replacement query must not retain stale location'
)
assert(vim.api.nvim_get_current_win() == input, 'old cleanup must not steal replacement focus')
assert(#group.instances == 1 and group.instances[1] == second.window.popup)
assert(#vim.api.nvim_get_autocmds({ event = 'ColorScheme' }) == baseline + 1)
second:confirm()
second:confirm()
assert(vim.wait(2000, function()
  return third ~= nil
end))
assert(second_calls == 1 and first_calls == 1)
assert(vim.api.nvim_get_current_win() == assert(third.window:pane('input')).win)
assert(#group.instances == 1 and group.instances[1] == third.window.popup)
third:close()
assert(vim.wait(2000, function()
  return third_calls == 1
end))
assert(#group.instances == 0 and #vim.api.nvim_list_wins() == 1)
assert(#vim.api.nvim_get_autocmds({ event = 'ColorScheme' }) == baseline)
print('PASS native group replacement preserves new focus and completion can reopen exactly once')

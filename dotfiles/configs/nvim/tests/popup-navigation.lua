local api = vim.api
local popup = require('popup')
local origin = api.nvim_get_current_win()
local buf = api.nvim_get_current_buf()
local instance = popup
  .root({
    row = 1,
    col = 1,
    width = 30,
    height = 8,
    layout = popup.pane({ id = 'content', buf = buf, enter = true }),
  })
  :open()
local win = assert(instance:pane('content').win)
for _, key in ipairs({ '<C-o>', '<C-i>' }) do
  local mapping = vim.fn.maparg(key, 'n', false, true)
  assert(mapping.expr == 1 and mapping.callback() == '')
  api.nvim_set_current_win(origin)
  assert(mapping.callback() == api.nvim_replace_termcodes(key, true, false, true))
  api.nvim_set_current_win(win)
end
local calls = 0
vim.keymap.set('n', '<C-o>', function()
  calls = calls + 1
end, { buffer = buf })
instance:render()
vim.fn.maparg('<C-o>', 'n', false, true).callback()
assert(calls == 1, 'Render must preserve explicit overrides')
instance:close()
assert(api.nvim_buf_is_valid(buf), 'Shared buffer must survive popup close')
print('PASS popup navigation defaults')
vim.cmd('qa!')

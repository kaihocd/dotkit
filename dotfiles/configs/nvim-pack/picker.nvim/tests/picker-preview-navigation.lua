vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Panel = require('picker.picker.panel')
local runtime = vim.fn.tempname()
vim.fn.mkdir(runtime .. '/syntax', 'p')
vim.fn.writefile(
  { 'let g:picker_test_syntax_loads = get(g:, "picker_test_syntax_loads", 0) + 1' },
  runtime .. '/syntax/lua.vim'
)
vim.opt.runtimepath:append(runtime)
local path = vim.fn.tempname() .. '.lua'
vim.fn.writefile({ 'local first = 1', 'local second = 2' }, path)
local session = Panel.new({
  search = function()
    return {
      status = 'ready',
      total = 2,
      items = {
        { path = path, display = 'fixture.lua', line = 1, content = 'local first = 1' },
        { path = path, display = 'fixture.lua', line = 2, content = 'local second = 2' },
      },
    }
  end,
}, function() end, nil, nil, true)
session:open()
session:resize(true)
local pane = assert(session.window:pane('preview'))
assert(vim.wait(2000, function()
  return vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1] == 'local first = 1'
end))
local list = assert(session.window:pane('list'))
local list_tick = vim.api.nvim_buf_get_changedtick(list.buf)
local tick = vim.api.nvim_buf_get_changedtick(pane.buf)
local syntax_loads = vim.g.picker_test_syntax_loads
assert(syntax_loads == 1)
local started = vim.uv.hrtime()
for i = 1, 20 do
  local target = i % 2 == 1 and 2 or 1
  session:move(target == 2 and 1 or -1)
  assert(
    vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1] ~= 'Loading…',
    'same-file hit movement flashes Loading'
  )
  assert(vim.wait(2000, function()
    return vim.api.nvim_win_get_cursor(pane.win)[1] == target
  end))
end
print(
  ('20 hit moves: %.2fms; buffer revisions: %d'):format(
    (vim.uv.hrtime() - started) / 1e6,
    vim.api.nvim_buf_get_changedtick(pane.buf) - tick
  )
)
assert(
  vim.api.nvim_buf_get_changedtick(pane.buf) == tick,
  'same-file hit movement rewrites preview and reloads syntax'
)
assert(vim.g.picker_test_syntax_loads == syntax_loads, 'hit navigation reloaded syntax')
assert(
  vim.api.nvim_buf_get_changedtick(list.buf) == list_tick,
  'default navigation reformatted the whole list'
)
-- A warm different-file preview must not transition through a message either.
local other = vim.fn.tempname() .. '.lua'
vim.fn.writefile({ 'local third = 3' }, other)
local display = session.window:preview_display()
local writes, loading = 0, 0
local original_content = display.content
display.content = function(lines, line, filename)
  writes = writes + 1
  if lines[1] == 'Loading…' then
    loading = loading + 1
  end
  original_content(lines, line, filename)
end
local run = function(operation)
  operation()
end
for _, filename in ipairs({ other, path, other, path }) do
  local before = writes
  session.preview:update(display, { path = filename, display = filename, line = 1 }, run, {})
  assert(vim.wait(2000, function()
    return writes > before
  end))
end
vim.wait(100)
assert(loading == 0, 'fast preview deliveries flashed Loading')
assert(vim.g.picker_test_syntax_loads == syntax_loads, 'same-filetype switch reloaded syntax')
vim.fn.delete(other)
session:close()
vim.wait(2000, function()
  return #vim.api.nvim_list_wins() == 1
end)
vim.fn.delete(path)
vim.opt.runtimepath:remove(runtime)
vim.fn.delete(runtime, 'rf')
print('PASS same-file grep navigation preserves preview content and follows hit line')

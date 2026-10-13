vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local View = require('picker.picker.window')
local function create_window(view, mode)
  local options = require('picker.picker.options').resolve({ view = view, mode = mode })
  return View.new(options.view, mode)
end
local view = create_window({ icon = false })
view:open()
local entries = {
  {
    path = '/src/a.lua',
    display = 'src/a.lua',
    line = 2,
    col = 0,
    content = 'local a',
    content_matches = { { 0, 5 } },
  },
  { path = '/src/a.lua', display = 'src/a.lua', line = 8, col = 2, content = '  local b' },
  { path = '/b.lua', display = 'b.lua', line = 1, col = 0, content = 'local c' },
}
view:render(entries, 2, 'ready', true)
local pane = assert(view:pane('list'))
local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
assert(#lines == 5 and lines[1]:find('a.lua src', 1, true))
assert(lines[2]:find(':2:1  local a', 1, true))
assert(vim.api.nvim_win_get_cursor(pane.win)[1] == 3)
view:marks(entries, function(entry)
  return entry.line == 1
end)
local marks =
  vim.api.nvim_buf_get_extmarks(pane.buf, vim.api.nvim_get_namespaces().PickerMarks, 0, -1, {})
assert(#marks == 1 and marks[1][2] == 4)
vim.cmd.redraw()
local origin = vim.fn.screenpos(pane.win, 1, 1)
local pos = { origin.row - 1, origin.col - 1 }
assert(view:hit(pos[1] + 1, pos[2] + 4) == nil)
assert(view:hit(pos[1] + 2, pos[2] + 4) == 1)
assert(view:hit(pos[1] + 4, pos[2] + 4) == nil)
view:render({}, nil, 'ready', true)
assert(view:hit(pos[1] + 1, pos[2] + 4) == nil)
view:close()
print('PASS grep grouped rows, selection/mark mapping and nonselectable headings/empty state')

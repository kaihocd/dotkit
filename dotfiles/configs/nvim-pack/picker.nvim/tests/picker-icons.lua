vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local icons = require('picker.picker.window.icons')
package.preload['nvim-web-devicons'] = function()
  error('not installed')
end
assert(icons.resolve()('/a.lua') == nil)
print('PASS missing optional icons leave no placeholder')
package.preload['nvim-web-devicons'] = nil
package.loaded['nvim-web-devicons'] = {
  get_icon = function(name, extension)
    assert(name == 'a.lua' and extension == 'lua')
    return 'λ', 'Special'
  end,
}
assert(icons.resolve(false)('/a.lua') == nil)
local custom = icons.resolve(function(path)
  assert(path == '/a.lua')
  return 'L', 'String'
end)
local glyph, group = custom('/a.lua')
assert(glyph == 'L' and group == 'String')
assert(icons.resolve(function()
  return nil
end)('/a.lua') == nil)
assert(not pcall(
  icons.resolve(function()
    return 'bad\nicon'
  end),
  '/a.lua'
))
print('PASS custom icon overrides installed provider, nil suppresses and false disables')
local View = require('picker.picker.window')
local function create_window(view, mode)
  local options = require('picker.picker.options').resolve({ view = view, mode = mode })
  return View.new(options.view, mode)
end
local view = create_window()
view:open()
view:render({ { path = '/a.lua', display = 'src/a.lua' } }, 1)
local pane = assert(view:pane('list'))
local line = vim.api.nvim_buf_get_lines(pane.buf, 0, 1, false)[1]
assert(line:sub(1, #'   λ  a.lua src') == '   λ  a.lua src')
local marks = vim.api.nvim_buf_get_extmarks(
  pane.buf,
  vim.api.nvim_get_namespaces().PickerList,
  0,
  -1,
  { details = true }
)
assert(#marks == 2 and marks[1][3] == 3 and marks[1][4].end_col == 5)
view:render({}, nil)
assert(
  #vim.api.nvim_buf_get_extmarks(pane.buf, vim.api.nvim_get_namespaces().PickerList, 0, -1, {}) == 1 -- Empty-result message has its own Comment segment.
)
view:close()
print('PASS optional icon spacing, byte highlight range and empty-result cleanup')

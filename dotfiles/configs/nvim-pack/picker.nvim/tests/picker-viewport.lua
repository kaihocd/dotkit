vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')

require('picker').setup()
local PickerWindow = require('picker.picker.window')
local function create_window(view, mode)
  local options = require('picker.picker.options').resolve({ view = view, mode = mode })
  return PickerWindow.new(options.view, mode)
end
local window = create_window({ icon = false })
window:open()
window:toggle_preview()

local lines = {}
for index = 1, 200 do
  lines[index] = 'line ' .. index
end
window:preview_content(lines, 1, '/tmp/picker-viewport.txt')
window:scroll_preview(30, 1)

local function top()
  local pane = assert(window:pane('preview'))
  return vim.api.nvim_win_call(pane.win, function()
    return vim.fn.winsaveview().topline
  end)
end

local scrolled = top()
assert(scrolled > 1)
window:resize()
assert(top() == scrolled, 'resize must retain preview viewport')
window:toggle_preview()
assert(window:pane('preview') == nil)
window:toggle_preview()
assert(top() == scrolled, 'hidden preview must restore its viewport')
window:close()
print('PASS Window independently preserves preview viewport through resize and hiding')

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')

require('picker').setup()
local bindings = require('picker.picker.editor.bindings')
local buffer = vim.api.nvim_create_buf(false, true)
local original = vim.api.nvim_create_autocmd
local registered = {}
local calls = 0

local function create(event, options)
  calls = calls + 1
  if calls == 3 then
    error('test: partial registration failure')
  end
  local id = original(event, options)
  registered[#registered + 1] = id
  return id
end

rawset(vim.api, 'nvim_create_autocmd', create)

local function ignore() end
local ok, problem = pcall(bindings.attach_events, { buf = buffer, scratch = true }, {
  changed = ignore,
  outside = ignore,
  theme = ignore,
  resize = ignore,
})
rawset(vim.api, 'nvim_create_autocmd', original)

assert(not ok and tostring(problem):find('partial registration failure', 1, true))
for _, id in ipairs(registered) do
  assert(#vim.api.nvim_get_autocmds({ id = id }) == 0)
end
vim.api.nvim_buf_delete(buffer, { force = true })
print('PASS partial binding registration releases every acquired event')

local Window = require('picker.picker.window')
local function create_window(view, mode)
  local options = require('picker.picker.options').resolve({ view = view, mode = mode })
  return Window.new(options.view, mode)
end
local window = create_window()
bindings.attach(window.popup, { i = {}, n = {} })
window:open()
assert(vim.fn.maparg('<C-w>', 'i') == '<C-S-W>' or vim.fn.maparg('<C-w>', 'i'):lower() == '<c-s-w>')
vim.api.nvim_feedkeys(vim.keycode('ione two<C-w><Esc>'), 'xt', false)
assert(window:query() == 'one ')
window:resize()
assert(vim.fn.maparg('<C-w>', 'i'):lower() == '<c-s-w>')
assert(vim.fn.maparg('<C-w>', 'n') == '')
window:close()
print('PASS Picker input Ctrl-w deletes a word and survives resize without normal-mode override')

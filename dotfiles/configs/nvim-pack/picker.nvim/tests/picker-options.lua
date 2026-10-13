vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local backend_calls = 0
package.loaded['picker.picker.backend.fff'] = {
  files = function()
    backend_calls = backend_calls + 1
    error('test backend boundary')
  end,
}
local messages = {}
local function notify(message)
  messages[#messages + 1] = message
end
vim.notify = notify
require('picker').setup()
local picker = require('picker')
local buffers = #vim.api.nvim_list_bufs()
local cases = {
  { 'false', 'options must be a table' },
  { '3', 'options must be a table' },
  { '{"mode":false}', 'mode must be files or grep' },
  { '{"mode":"other"}', 'mode must be files or grep' },
  { '{"cwd":false}', 'cwd must be a directory string' },
  { '{"view":false}', 'view must be a table' },
  { '{"keymaps":true}', 'keymaps must be a table' },
  { '{"view":{"root":false}}', 'view.root is no longer supported' },
  { '{"view":{"input":3}}', 'view.input is no longer supported' },
  { '{"view":{"list":true}}', 'view.list is no longer supported' },
  { '{"view":{"preview":"x"}}', 'view.preview is no longer supported' },
  { '{"view":{"input":{"buf":0}}}', 'view.input is no longer supported' },
  { '{"view":{"layout":true}}', 'view.layout must be a function or table' },
  { '{"view":{"icon":true}}', 'view.icon must be false or a function' },
  { '{"keymaps":{"bad":{}}}', 'keymaps mode must be a native Neovim mapping mode' },
  { '{"keymaps":{"i":false}}', 'keymaps[i] must be a table' },
  { '{"keymaps":{"i":{"":false}}}', 'keymaps[i] keys must be non-empty strings' },
  { '{"keymaps":{"i":{"<C-a>":true}}}', 'keymaps[i][<C-a>] must be false, a string or a function' },
}
for _, case in ipairs(cases) do
  local options = vim.json.decode(case[1])
  local before = vim.deepcopy(options)
  picker.open(options)
  assert(
    messages[#messages]:find('picker: ' .. case[2], 1, true),
    case[1] .. ': ' .. tostring(messages[#messages])
  )
  assert(vim.deep_equal(before, options))
end
assert(#messages == #cases and backend_calls == 0)
assert(#vim.api.nvim_list_bufs() == buffers and #vim.api.nvim_list_wins() == 1)
picker.open()
assert(backend_calls == 1 and messages[#messages]:find('test backend boundary', 1, true))
local valid =
  { view = { icon = false }, keymaps = { i = { ['<C-a>'] = '<Home>', ['<C-l>'] = false } } }
local copy = vim.deepcopy(valid)
picker.open(valid)
assert(backend_calls == 2 and vim.deep_equal(valid, copy))
print('PASS public option errors precede backend/UI work and preserve caller configuration')

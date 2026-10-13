-- Real backend, isolated configuration. Confirmation opens files in this test process.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH)
vim.opt.runtimepath:prepend(vim.env.FFF_NVIM_PATH)
if vim.env.DEVICONS_NVIM_PATH and vim.env.DEVICONS_NVIM_PATH ~= '' then
  vim.opt.runtimepath:prepend(vim.env.DEVICONS_NVIM_PATH)
  require('nvim-web-devicons').setup({})
end
vim.o.mouse = 'a'
vim.cmd('filetype on')
vim.cmd('syntax enable')
local function open()
  require('picker').setup()
  require('picker').open({ cwd = vim.env.PICKER_DEMO_CWD or vim.fn.getcwd() })
end
vim.api.nvim_create_user_command('PickerDemo', open, {})
vim.api.nvim_create_user_command('PickerResumeDemo', function()
  require('picker').resume()
end, {})
vim.api.nvim_create_user_command('PickerGrepDemo', function()
  require('picker').open({ cwd = vim.env.PICKER_DEMO_CWD or vim.fn.getcwd(), mode = 'grep' })
end, {})
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  'Real fff Picker demo — isolated from personal Neovim configuration.',
  'Enter opens a real file; C-s/C-v/C-t open splits/tab; C-q sends marks to quickfix.',
  'Tab marks; click selects; Esc cancels; :PickerDemo / :PickerGrepDemo reopen.',
  'In grep, C-l cycles plain / regex / fuzzy matching.',
  'C-o toggles syntax-highlighted preview; C-f/C-b scroll preview down/up half a window.',
})
vim.bo.modified = false
open()

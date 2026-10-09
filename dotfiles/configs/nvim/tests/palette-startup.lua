-- Run: nvim --headless -u NONE -l dotfiles/configs/nvim/tests/palette-startup.lua
vim.opt.rtp:append(vim.fn.getcwd() .. '/dotfiles/configs/nvim')
local root = vim.fn.tempname()
vim.env.XDG_STATE_HOME = root
local directory = root .. '/palette'
vim.fn.mkdir(directory, 'p')
local theme = { id = 'test', name = 'Test', variant = 'dark', palette = {} }
for i = 0, 23 do
  theme.palette[('base%02X'):format(i)] = '#282c34'
end
local function save()
  vim.fn.writefile({ vim.json.encode(theme) }, directory .. '/active-theme.json')
end
save()
local changes = 0
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    changes = changes + 1
  end,
})
local palette = require('palette')
local function check_normal()
  local semantic = require('palette.colors').semantic(theme)
  assert(
    vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg == tonumber(semantic.bg:sub(2), 16)
  )
end
local ok, err = xpcall(function()
  vim.cmd('packadd heirline.nvim')
  vim.cmd('packadd nvim-web-devicons')
  local original_tabline = vim.o.tabline
  require('plugins.ui.heirline').config()
  assert(vim.o.tabline == original_tabline, 'No palette: leave the native UI unchanged')
  palette.setup()
  assert(changes == 1, 'Initial theme must be applied before setup returns')
  check_normal()
  assert(vim.o.tabline ~= original_tabline, 'First valid palette must initialize Heirline')
  local function check_heirline()
    local loaded = require('heirline.highlights').get_loaded_colors()
    assert(loaded.bg == theme.palette.base00)
    local snapshot = require('palette.highlights').current()
    snapshot.bg = '#ffffff'
    assert(require('palette.highlights').current().bg == theme.palette.base00)
  end
  check_heirline()
  palette.setup()
  assert(changes == 1, 'Repeated setup must not reapply the theme')
  theme.palette.base00 = '#101820'
  save()
  assert(
    vim.wait(2000, function()
      return changes == 2
    end, 10),
    'Theme watcher did not reload'
  )
  check_normal()
  check_heirline()
  local errors = {}
  local function capture_notification(message)
    errors[#errors + 1] = message
  end
  vim.notify = capture_notification
  vim.fn.writefile({ '{invalid' }, directory .. '/active-theme.json')
  assert(
    vim.wait(2000, function()
      return #errors > 0
    end, 10),
    'Invalid theme must be reported'
  )
  assert(changes == 2, 'Invalid theme must not emit ColorScheme')
  check_normal()
  check_heirline()
  -- Even a manual ColorScheme event must not reread the broken file.
  vim.api.nvim_exec_autocmds('ColorScheme', {})
  assert(changes == 3)
  check_heirline()
  save()
  vim.wait(200)
  assert(changes == 3, 'Unchanged theme must not be reapplied')
end, debug.traceback)
vim.api.nvim_exec_autocmds('VimLeavePre', {})
vim.fn.delete(root, 'rf')
assert(ok, err)
print('Palette synchronous startup and asynchronous reload checks passed')
vim.cmd('qa!')

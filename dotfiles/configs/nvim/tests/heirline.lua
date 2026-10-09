-- Run from the repository root: nvim --headless -u NONE -l dotfiles/configs/nvim/tests/heirline.lua
vim.opt.rtp:append(vim.fn.getcwd() .. '/dotfiles/configs/nvim')
vim.cmd('packadd heirline.nvim')
vim.cmd('packadd nvim-web-devicons')
vim.o.termguicolors = true

require('palette').setup()
local config = require('plugins.ui.heirline')
local context = require('plugins.ui.heirline.context')
config.config()
local function render()
  return vim.api.nvim_eval_statusline(vim.o.tabline, {
    use_tabline = true,
    highlights = true,
    maxwidth = 240,
  })
end
local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
end
local root = vim.fn.getcwd()
local first = vim.api.nvim_get_current_tabpage()
vim.api.nvim_buf_set_name(0, root .. '/lua/中文%file.lua')
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), 'lua' })
assert(render().str:find('中文%file.lua', 1, true))
vim.bo.modified = true
equal(context.buffer_status(0), '[+]')
vim.bo.modified = false
vim.bo.readonly = true
equal(context.buffer_status(0), '[RO]')
vim.bo.readonly = false

vim.cmd('tabnew')
local second = vim.api.nvim_get_current_tabpage()
equal(context.buffer_label(0), '[No Name]')
vim.api.nvim_buf_set_name(0, 'oil://' .. root .. '/lua/')
vim.bo.filetype = 'oil'
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), 'lua' })
equal(context.buffer_label(0), '[oil]')
vim.bo.filetype = 'fugitive'
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), '' })
equal(context.buffer_status(0), nil)

-- Native click regions must use current tab numbers, including after reordering.
local function check_targets()
  render()
  local list = require('heirline').tabline[1][4]
  for _, item in ipairs(list) do
    equal(item[1].provider(item), ('%%%dT'):format(vim.api.nvim_tabpage_get_number(item.tabpage)))
    equal(item[#item].provider, '%T')
  end
end
check_targets()
vim.cmd('tabmove 0')
check_targets()
vim.api.nvim_set_current_tabpage(first)
vim.cmd('lcd ' .. vim.fn.fnameescape(root .. '/dotfiles'))
equal({ context.workdir(0) }, { 'dotfiles', vim.fn.fnamemodify(root .. '/lua', ':~') })
vim.cmd('lcd /')
equal(({ context.workdir(0) })[1], '/')
vim.cmd('lcd ' .. vim.fn.fnameescape(vim.fn.expand('~')))
equal(({ context.workdir(0) })[1], '~')

local before = render().str
vim.api.nvim_exec_autocmds('ColorScheme', {})
equal(render().str, before)
local count = #vim.api.nvim_get_autocmds({ group = 'DotkitStatusline' })
config.config()
equal(#vim.api.nvim_get_autocmds({ group = 'DotkitStatusline' }), count)
check_targets()
vim.api.nvim_set_current_tabpage(second)
vim.cmd('tabclose')
check_targets()
assert(vim.api.nvim_eval_statusline(vim.o.statusline, {}).str:find('NORMAL', 1, true))
print('Heirline context, rendering, native click targets and lifecycle checks passed')
vim.cmd('qa!')

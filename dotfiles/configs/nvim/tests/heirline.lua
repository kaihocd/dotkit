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
local statusline = require('plugins.ui.heirline.statusline')
local position_format = statusline[#statusline].provider
assert(type(position_format) == 'string')
local saved_buffer = vim.api.nvim_get_current_buf()
local position_buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(position_buffer)
vim.api.nvim_buf_set_lines(
  position_buffer,
  0,
  -1,
  false,
  vim.fn['repeat']({ string.rep('x', 120) }, 120)
)
local position_width
for _, position in ipairs({ { 1, 0 }, { 9, 8 }, { 10, 9 }, { 99, 98 }, { 120, 119 } }) do
  vim.api.nvim_win_set_cursor(0, position)
  local result = vim.api.nvim_eval_statusline(position_format, {})
  position_width = position_width or result.width
  equal(result.width, position_width)
  assert(result.str:find(tostring(position[1]), 1, true))
end
vim.api.nvim_set_current_buf(saved_buffer)
vim.api.nvim_buf_delete(position_buffer, { force = true })
local directory = require('plugins.ui.heirline.tabline')[1][2][2]
for _, case in ipairs({
  { 'dotfiles/configs/nvim/lua/plugins/ui/heirline', ' …/ui/heirline', ' …/heirline' },
  { 'lua/plugins', ' lua/plugins', ' …/plugins' },
  { 'lua', ' lua', ' lua' },
  { '', '', '' },
  { '/', ' /', ' /' },
  { '/tmp/中文/100%目录', ' …/中文/100%%目录', ' …/100%%目录' },
  { 'a/b', ' a/b', ' a/b' },
}) do
  local state = { directory = case[1], cwd_name = 'dotkit', within_cwd = true }
  equal(directory[2].provider(state), case[2]:gsub('^ ', '/'))
  equal(directory[3].provider(state), case[3]:gsub('^ ', '/'))
  state.within_cwd = false
  equal(directory[2].provider(state), case[2]:gsub('^ ', '  '))
end
equal(directory[1].provider({ directory = 'tmp', cwd_name = '/', within_cwd = true }), 'tmp')
local root = vim.fn.getcwd()
local first = vim.api.nvim_get_current_tabpage()
vim.api.nvim_buf_set_name(0, root .. '/lua/中文%file.lua')
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), 'lua', true })
assert(render().str:find(vim.fn.fnamemodify(root, ':t') .. '/lua', 1, true))
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
vim.api.nvim_buf_set_name(0, 'oil://' .. root .. '/dotfiles/')
vim.bo.filetype = 'oil'
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), 'dotfiles', true })
equal(context.buffer_label(0), '[oil]')
vim.api.nvim_buf_set_name(0, 'minigit://1/git status')
vim.bo.filetype = 'git'
equal(context.buffer_label(0), '[minigit]')
equal({ context.workdir(0) }, { vim.fn.fnamemodify(root, ':t'), '' })
equal(context.buffer_status(0), nil)
local diffview_panel = vim.api.nvim_create_buf(false, true)
vim.bo[diffview_panel].filetype = 'DiffviewFiles'
vim.api.nvim_buf_set_name(diffview_panel, 'diffview:///panels/1/DiffviewFilePanel')
vim.bo[diffview_panel].modifiable = true
vim.bo[diffview_panel].readonly = false
equal(context.buffer_label(diffview_panel), '[diffview]')
equal(context.buffer_status(diffview_panel), nil)
vim.bo[diffview_panel].modifiable = false
equal(context.buffer_status(diffview_panel), nil)
vim.bo[diffview_panel].readonly = true
equal(context.buffer_status(diffview_panel), nil)
vim.api.nvim_buf_set_name(diffview_panel, 'custom+view:///missing-directory')
equal(context.buffer_label(diffview_panel), '[custom+view]')
equal({ context.workdir(diffview_panel) }, { vim.fn.fnamemodify(root, ':t'), '' })
vim.api.nvim_buf_delete(diffview_panel, { force = true })

-- Native click regions must use current tab numbers, including after reordering.
local function check_targets()
  render()
  local list = require('heirline').tabline[1][4][1]
  for _, item in ipairs(list) do
    if item.tabpage then
      equal(item[1].provider(item), ('%%%dT'):format(vim.api.nvim_tabpage_get_number(item.tabpage)))
      equal(item[#item].provider, '%T')
    end
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
assert(vim.api.nvim_eval_statusline(vim.o.statusline, {}).str:match('^ N '))
local original_columns = vim.o.columns
local extra_tabs = {}
for index = 1, 8 do
  vim.cmd('tabnew')
  extra_tabs[index] = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_buf_set_name(0, root .. '/lua/中文%' .. index .. '-long-file.lua')
end
vim.o.columns = 60
vim.api.nvim_set_current_tabpage(extra_tabs[4])
check_targets()
local rendered = render().str
assert(rendered:find('5/9', 1, true), rendered)
assert(not rendered:find('‹', 1, true))
vim.cmd('tabmove 0')
assert(render().str:find('1/9', 1, true))
vim.o.columns = 40
assert(render().str:find('1/9', 1, true))
for _, tabpage in ipairs(extra_tabs) do
  vim.api.nvim_set_current_tabpage(tabpage)
  vim.cmd('tabclose')
end
vim.o.columns = original_columns
assert(render().str:find('中文%file.lua', 1, true))
check_targets()
local mode_component = require('plugins.ui.heirline.statusline')[1]
local original_get_mode = vim.api.nvim_get_mode
local ok, failure = pcall(function()
  for _, case in ipairs({
    { 'n', 'N' },
    { 'no', 'N' },
    { 'i', 'I' },
    { 'v', 'V' },
    { 'V', 'V' },
    { '\22', 'V' },
    { 's', 'S' },
    { 'c', 'C' },
    { 'R', 'R' },
    { 't', 'T' },
    { '?', '?' },
  }) do
    local function get_mode()
      return { mode = case[1], blocking = false }
    end
    vim.api.nvim_get_mode = get_mode
    local state = {}
    mode_component.init(state)
    equal(mode_component.provider(state), ' ' .. case[2] .. ' ')
    equal(mode_component.hl, { fg = 'fg', bold = true })
  end
end)
vim.api.nvim_get_mode = original_get_mode
assert(ok, failure)
print('Heirline context, rendering, native click targets, mode labels and lifecycle checks passed')
vim.cmd('qa!')

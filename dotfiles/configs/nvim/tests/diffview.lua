-- Standalone test: DIFFVIEW_TEST_ROOT contains diffview-plus.nvim and nvim-web-devicons.
-- Run: nvim --headless -u NONE -l dotfiles/configs/nvim/tests/diffview.lua
local plugins = assert(vim.env.DIFFVIEW_TEST_ROOT, 'Set DIFFVIEW_TEST_ROOT')

-- Attach a screen grid before exercising redraws and screen-size changes.
-- Bare headless inline-diff resizing can crash Neovim 0.12.4 on macOS.
if not vim.g.dotkit_diffview_test_child then
  local channel = vim.fn.jobstart(
    { vim.v.progpath, '--embed', '--headless', '-u', 'NONE' },
    { rpc = true }
  )
  vim.rpcrequest(channel, 'nvim_ui_attach', 100, 30, { rgb = true })
  local ok, err = pcall(
    vim.rpcrequest,
    channel,
    'nvim_exec_lua',
    [[
    vim.g.dotkit_diffview_test_child = true
    dofile('dotfiles/configs/nvim/tests/diffview.lua')
  ]],
    {}
  )
  vim.fn.jobstop(channel)
  vim.fn.jobwait({ channel }, 5000)
  assert(ok, err)
  print('Diffview UI checks passed')
  return
end

vim.opt.rtp:append('dotfiles/configs/nvim')
vim.opt.rtp:append(plugins .. '/diffview-plus.nvim')
vim.opt.rtp:append(plugins .. '/nvim-web-devicons')
require('plugins.git.diffview').config()
vim.cmd('runtime plugin/diffview.lua')
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function git(...)
  local a = { 'git', '-C', root }
  vim.list_extend(a, { ... })
  assert(vim.system(a):wait().code == 0)
end
local ok, err = xpcall(function()
  git('init')
  vim.fn.writefile({ 'old' }, root .. '/a')
  git('add', '.')
  git('-c', 'user.name=T', '-c', 'user.email=t@t', 'commit', '-m', 'initial')
  vim.cmd.cd(root)
  vim.cmd.edit(root .. '/a')
  local notice
  local original_notify = vim.notify
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, level)
    notice = { msg, level }
  end
  require('plugins.git.diffview.history').open_lines(5, 5)
  assert(
    vim.wait(5000, function()
      return notice ~= nil
    end),
    'missing empty history notice'
  )
  vim.notify = original_notify
  assert(notice[2] == vim.log.levels.WARN)
  assert(notice[1] == 'No commit history is available for this file or line range.')
  assert(require('diffview.lib').get_current_view() == nil)
  vim.fn.writefile({ 'new' }, root .. '/a')
  vim.o.columns = 100
  vim.fn.maparg('<leader>gg', 'n', false, true).callback()
  assert(
    vim.wait(5000, function()
      local v = require('diffview.lib').get_current_view()
      return v and v.cur_layout and v.cur_layout.name == 'diff1_inline'
    end),
    'narrow layout'
  )
  assert(
    vim.wait(5000, function()
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.wo[w].winhl:find('DiffviewDiffDelete:DiffDelete', 1, true) then
          return true
        end
      end
      return false
    end),
    'inline highlight override missing'
  )
  vim.o.columns = 180
  vim.api.nvim_exec_autocmds('VimResized', {})
  assert(
    vim.wait(5000, function()
      return require('diffview.lib').get_current_view().cur_layout.name == 'diff2_horizontal'
    end),
    'wide layout'
  )
  require('diffview.actions').cycle_layout()
  assert(
    vim.wait(5000, function()
      return require('diffview.lib').get_current_view().cur_layout.name == 'diff1_inline'
    end),
    'manual toggle'
  )
  vim.cmd('DiffviewClose')
end, debug.traceback)
vim.cmd.cd('/tmp')
vim.cmd('silent! tabonly!')
vim.cmd('silent! %bwipeout!')
vim.fn.delete(root, 'rf')
assert(ok, err)
print('Adaptive layout and missing history checks passed')

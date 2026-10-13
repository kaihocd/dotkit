-- Standalone: GITGRAPH_TEST_ROOT points to an installed gitgraph.nvim checkout.
vim.opt.runtimepath:append('dotfiles/configs/nvim')
vim.opt.runtimepath:append(assert(vim.env.GITGRAPH_TEST_ROOT, 'Set GITGRAPH_TEST_ROOT'))
local root = vim.fn.tempname()
local cwd = vim.fn.getcwd()
vim.fn.mkdir(root, 'p')
local function git(...)
  local args = { 'git', '-C', root }
  vim.list_extend(args, { ... })
  local result = vim.system(args, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end

local original_notify = vim.notify
local notice
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(message, level)
  notice = { message, level }
end
local opened
package.loaded.diffview = {
  open = function(args)
    opened = args[1]
  end,
}

local ok, err = xpcall(function()
  require('plugins.git.gitgraph').config()
  vim.cmd.cd(root)
  local open = vim.fn.maparg('<leader>gG', 'n', false, true).callback
  local tabs = #vim.api.nvim_list_tabpages()
  open()
  assert(notice[2] == vim.log.levels.WARN)
  assert(#vim.api.nvim_list_tabpages() == tabs)

  git('init', '-b', 'test')
  open()
  assert(notice[1] == 'This repository has no commits to display.')
  assert(#vim.api.nvim_list_tabpages() == tabs)

  vim.fn.writefile({ 'first' }, root .. '/file.txt')
  git('add', '.')
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'Initial')
  local initial = git('rev-parse', 'HEAD')
  open()
  assert(#vim.api.nvim_list_tabpages() == tabs + 1)
  assert(vim.api.nvim_buf_line_count(0) > 0)
  vim.fn.maparg('<CR>', 'n', false, true).callback()
  assert(git('rev-parse', opened:match('%.%.(.+)$')) == initial)
  assert(git('diff', '--name-only', opened) == 'file.txt')

  local hooks = require('gitgraph').config.hooks
  hooks.on_select_range_commit({ hash = initial }, { hash = initial })
  assert(opened == initial .. '..' .. initial)
  assert(git('diff', '--name-only', opened) == '')
  vim.wait(50)
  vim.cmd('tabclose')
end, debug.traceback)

vim.notify = original_notify
vim.cmd.cd(cwd)
vim.fn.delete(root, 'rf')
assert(ok, err)
print('Git graph checks passed')

-- Manual smoke script. Not part of the plugin runtime.
-- Usage: :luafile /Users/qihao/dotkit/dotfiles/configs/nvim-pack/cli.nvim/dev/smoke.lua
-- Teardown: :lua _G.cli_smoke.teardown()
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:append(root)

local cwd = vim.fn.getcwd()
local EditorBridge = require('cli.bridge.editor')
local Git = require('cli.adapter.git')
local GitCompletion = require('cli.completion.git')

if _G.cli_smoke then
  _G.cli_smoke.teardown()
end

local bridge = EditorBridge.new({ cwd = cwd, layout = 'tab' })
local git = Git.new({
  cwd = cwd,
  editor = bridge,
  complete = GitCompletion.callback({ cwd = cwd }),
})
git:register('MyGit', { route_key = Git.route_key, force = true })

_G.cli_smoke = {
  bridge = bridge,
  git = git,
  teardown = function()
    bridge:dispose()
    pcall(vim.api.nvim_del_user_command, 'MyGit')
    _G.cli_smoke = nil
  end,
}

vim.notify(
  'cli.nvim smoke ready: :MyGit status | :MyGit log -2 --oneline | :MyGit commit',
  vim.log.levels.INFO
)

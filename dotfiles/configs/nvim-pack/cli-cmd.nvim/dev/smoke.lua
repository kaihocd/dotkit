-- Manual smoke script. Not part of the plugin runtime.
-- Usage: :luafile /Users/qihao/dotkit/dotfiles/configs/nvim-pack/cli-cmd.nvim/dev/smoke.lua
-- Teardown: :lua _G.cli_smoke.teardown()
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:append(root)

-- Drop cached modules so editing the plugin and re-sourcing this file takes effect.
for name in pairs(package.loaded) do
  if name == 'cli-cmd' or name:match('^cli%-cmd%.') then
    package.loaded[name] = nil
  end
end

local Installer = require('cli-cmd.install')
local cli = require('cli-cmd')

if _G.cli_smoke then
  _G.cli_smoke.teardown()
end

local tool = cli.install('git', { command = 'MyGit', editor = { layout = 'tab' } })

_G.cli_smoke = {
  tool = tool,
  teardown = function()
    Installer.dispose('git')
    _G.cli_smoke = nil
  end,
}

vim.notify(
  'cli-cmd.nvim smoke ready: :MyGit status | :MyGit log -2 --oneline | :MyGit commit',
  vim.log.levels.INFO
)

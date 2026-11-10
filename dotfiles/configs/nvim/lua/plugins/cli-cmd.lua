---@type pack.UserSpec
return {
  path = vim.fs.joinpath(G.local_plugins_root, 'cli-cmd.nvim'),
  event = 'UIEnter',
  config = function()
    require('cli-cmd.git').setup({ alias = 'G' })
  end,
}

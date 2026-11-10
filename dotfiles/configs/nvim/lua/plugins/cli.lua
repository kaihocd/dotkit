---@type pack.UserSpec
return {
  path = vim.fs.joinpath(G.local_plugins_root, 'cli.nvim'),
  event = 'UIEnter',
  config = function()
    require('cli.git').setup({ alias = 'G' })
  end,
}

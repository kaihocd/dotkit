---@type pack.UserSpec[]
return {
  {
    path = vim.fs.joinpath(G.local_plugins_root, 'picker.nvim'),
    event = 'UIEnter',
    deps = {
      { path = vim.fs.joinpath(G.local_plugins_root, 'popup.nvim') },
      { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
      {
        src = 'https://github.com/dmtrKovalenko/fff',
        build = function()
          vim.cmd.packadd('fff')
          require('fff.download').download_or_build_binary()
        end,
        opts = {
          lazy_sync = true,
        },
      },
    },
    config = require('plugins.explorer.picker').config,
  },
  {
    src = 'https://github.com/DNLHC/glance.nvim',
    event = 'UIEnter',
    config = require('plugins.explorer.glance').config,
  },
  {
    src = 'https://github.com/stevearc/oil.nvim',
    event = 'UIEnter',
    deps = {
      { path = vim.fs.joinpath(G.local_plugins_root, 'popup.nvim') },
      { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
    },
    config = require('plugins.explorer.oil').config,
  },
}

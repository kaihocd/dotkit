---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/isakbm/gitgraph.nvim',
    event = 'UIEnter',
    deps = { { src = 'https://github.com/dlyongemallo/diffview-plus.nvim' } },
    config = require('plugins.git.gitgraph').config,
  },
  {
    src = 'https://github.com/dlyongemallo/diffview-plus.nvim',
    event = 'UIEnter',
    deps = { { src = 'https://github.com/nvim-tree/nvim-web-devicons' } },
    config = require('plugins.git.diffview').config,
  },
  {
    src = 'https://github.com/echasnovski/mini-git',
    event = 'UIEnter',
    config = function()
      require('mini.git').setup()
      vim.cmd.cnoreabbrev('G Git')
    end,
  },
  {
    src = 'https://github.com/echasnovski/mini.diff',
    event = 'UIEnter',
    opts = require('plugins.git.minidiff').opts,
    config = require('plugins.git.minidiff').config,
  },
}

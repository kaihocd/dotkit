---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/stevearc/conform.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = require('plugins.devtool.format').config,
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    event = 'UIEnter',
    config = require('plugins.devtool.treesitter').config,
  },
  {
    src = 'https://github.com/mason-org/mason-lspconfig.nvim',
    event = 'UIEnter',
    deps = {
      { src = 'https://github.com/saghen/blink.cmp' },
      {
        src = 'https://github.com/mason-org/mason.nvim',
        config = require('plugins.devtool.mason').config,
      },
      { src = 'https://github.com/neovim/nvim-lspconfig' },
      { src = 'https://github.com/b0o/SchemaStore.nvim' },
    },
    config = require('plugins.devtool.lsp').config,
  },
}

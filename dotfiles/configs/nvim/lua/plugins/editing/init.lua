---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/NMAC427/guess-indent.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
  },
  {
    src = 'https://github.com/chrisgrieser/nvim-origami',
    main = 'origami',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      foldtext = {
        lineCount = { template = ' %d lines ', hlgroup = 'Function' },
        diagnosticsCount = false,
      },
      autoFold = { enabled = false },
      foldKeymaps = { setup = false },
    },
    config = function(opts)
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
      require('origami').setup(opts)
    end,
  },
  {
    src = 'https://github.com/saghen/blink.cmp',
    version = 'main',
    event = 'UIEnter',
    deps = {
      { src = 'https://github.com/saghen/blink.lib', config = false },
      { src = 'https://github.com/rafamadriz/friendly-snippets', config = false },
    },
    build = function()
      vim.cmd.packadd('blink.lib')
      vim.cmd.packadd('blink.cmp')
      require('blink.cmp').build():pwait()
    end,
    opts = require('plugins.editing.blink').opts,
  },
  { src = 'https://github.com/echasnovski/mini.pairs', event = 'InsertEnter' },
  { src = 'https://github.com/echasnovski/mini.surround', event = 'UIEnter' },
  { src = 'https://github.com/echasnovski/mini.ai', event = 'BufReadPre' },
  { src = 'https://github.com/folke/ts-comments.nvim', event = 'UIEnter' },
  {
    src = 'https://github.com/windwp/nvim-ts-autotag',
    ft = { 'html', 'xml', 'javascriptreact', 'typescriptreact', 'vue', 'svelte' },
  },
}

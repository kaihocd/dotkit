---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter-context',
    main = 'treesitter-context',
    event = 'UIEnter',
    deps = { { src = 'https://github.com/nvim-treesitter/nvim-treesitter' } },
    opts = {
      max_lines = 3,
      multiline_threshold = 1,
      min_window_height = 20,
      separator = '─',
    },
    config = function(opts)
      require('treesitter-context').setup(opts)
      vim.keymap.set('n', '[c', function()
        if vim.wo.diff then
          return '[c'
        end
        vim.schedule(function()
          require('treesitter-context').go_to_context()
        end)
        return '<Ignore>'
      end, { desc = 'Jump to upper context', expr = true })
    end,
  },
  {
    src = 'https://github.com/saghen/blink.cmp',
    deps = {
      { src = 'https://github.com/xzbdmw/colorful-menu.nvim' },
    },
    opts = require('plugins.ui.blink').opts,
  },
  {
    path = vim.fs.joinpath(G.local_plugins_root, 'popup.nvim'),
    event = 'UIEnter',
    config = require('plugins.ui.popup').config,
  },
  {
    src = 'https://github.com/rebelot/heirline.nvim',
    event = 'UIEnter',
    deps = { { src = 'https://github.com/nvim-tree/nvim-web-devicons' } },
    config = require('plugins.ui.heirline').config,
  },
  {
    src = 'https://github.com/lukas-reineke/indent-blankline.nvim',
    event = 'UIEnter',
    name = 'ibl',
    opts = {
      indent = { char = '│' },
      scope = { enabled = false },
    },
  },
}

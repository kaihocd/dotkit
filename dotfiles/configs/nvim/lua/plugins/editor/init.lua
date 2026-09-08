local config = assert(
  vim.uv.fs_realpath(vim.fn.stdpath('config')),
  'Unable to resolve Neovim configuration directory'
)

return {
  {
    src = 'https://github.com/stevearc/oil.nvim',
    event = 'UIEnter',
    deps = {
      { path = vim.fs.joinpath(vim.fs.dirname(config), 'nvim-pack', 'popup.nvim') },
      { src = 'https://github.com/nvim-tree/nvim-web-devicons', config = function() end },
    },
    config = function()
      local adapter = require('plugins.editor.oil')
      require('oil').setup({
        columns = { 'icon', 'permissions', 'size', 'mtime' },
        win_options = { number = true },
        keymaps = {
          ['-'] = adapter.close,
          ['q'] = adapter.close,
          ['<CR>'] = adapter.select,
          ['<C-l>'] = adapter.select,
          ['<C-j>'] = adapter.select,
          ['<BS>'] = 'actions.parent',
          ['<C-h>'] = 'actions.parent',
          ['<C-w>v'] = function() adapter.select({ vertical = true }) end,
          ['<C-w>s'] = function() adapter.select({ horizontal = true }) end,
          ['<C-s>'] = function() adapter.select({ vertical = true }) end,
          ['<C-v>'] = function() adapter.select({ horizontal = true }) end,
          ['<C-t>'] = function() adapter.select({ tab = true }) end,
          ['<C-r>'] = 'actions.refresh',
          ['gh'] = 'actions.toggle_hidden',
          ['<C-p>'] = adapter.preview,
        },
      })
      vim.keymap.set('n', '-', adapter.toggle, { desc = 'Toggle Oil Popup' })
    end,
  },
}

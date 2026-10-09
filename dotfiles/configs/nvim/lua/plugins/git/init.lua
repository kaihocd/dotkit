---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/tpope/vim-fugitive',
    event = 'UIEnter',
    config = function()
      vim.keymap.set('n', '<leader>gg', '<Cmd>Git<CR>', { desc = 'Git status' })
      vim.keymap.set('n', '<leader>gc', '<Cmd>Git commit<CR>', { desc = 'Git commit' })
    end,
  },
}

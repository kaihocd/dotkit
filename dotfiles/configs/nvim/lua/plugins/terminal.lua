---@type pack.UserSpec
return {
  path = vim.fs.joinpath(G.local_plugins_root, 'terminal.nvim'),
  event = 'UIEnter',
  deps = { { path = vim.fs.joinpath(G.local_plugins_root, 'popup.nvim') } },
  config = function()
    local terminal = require('terminal')

    terminal.setup({ group = require('plugins.ui.popup').EXCLUSIVE_GROUP })

    vim.keymap.set({ 'n', 't' }, '<C-\\>', function()
      terminal.toggle()
    end, { desc = 'Toggle terminal manager' })
  end,
}

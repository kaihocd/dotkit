---@type pack.UserSpec[]
return {
  {
    src = 'https://github.com/zbirenbaum/copilot.lua',
    event = { 'BufReadPre', 'BufNewFile' },
    deps = {
      {
        src = 'https://github.com/copilotlsp-nvim/copilot-lsp',
      },
    },
    opts = {
      panel = { enabled = false },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 50,
        keymap = {
          accept = '<C-l>',
          next = '<C-n>',
          prev = '<C-p>',
          dismiss = '<C-e>',
        },
      },
      nes = {
        enabled = true,
        move_count_threshold = 5,
        keymap = {
          accept_and_goto = '<leader>l',
          accept = false,
          dismiss = '<Esc>',
        },
      },
    },
    config = function(opts)
      require('copilot').setup(opts)

      vim.api.nvim_create_autocmd('InsertLeave', {
        callback = function()
          require('copilot.suggestion').dismiss()
        end,
      })
    end,
  },
}

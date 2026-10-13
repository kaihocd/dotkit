local M = {}

local CMDLINE_WINHIGHLIGHT = 'Normal:MsgArea'
local CMDWIN_ZINDEX = 201 -- One layer above ui2 Cmdline (200).

local function configure_window(win)
  -- Match ui2 Cmdline geometry. Neovim clips oversized width to available columns.
  vim.api.nvim_win_set_config(win, {
    relative = 'laststatus',
    row = 1,
    col = 0,
    width = 10000,
    height = 1,
    style = 'minimal',
    border = 'none',
    zindex = CMDWIN_ZINDEX,
  })

  vim.wo[win].wrap = false
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0
  vim.wo[win].statusline = ''
  vim.wo[win].winhighlight = CMDLINE_WINHIGHLIGHT
end

function M.setup()
  -- Keep native entry; <Esc> and <C-f> switch to cmdwin for Normal-mode editing.
  -- vim.keymap.set('c', '<Esc>', '<C-f>', { desc = 'Edit command line in cmdwin' })
  -- vim.keymap.set('c', '<C-c>', '<C-f>', { desc = 'Edit command line in cmdwin' })
  vim.opt.incsearch = true

  local group = vim.api.nvim_create_augroup('ConfigsCmdwin', { clear = true })
  vim.api.nvim_create_autocmd('CmdwinEnter', {
    group = group,
    desc = 'Present Cmdwin as the command line',
    callback = function(event)
      configure_window(vim.api.nvim_get_current_win())
      vim.cmd.stopinsert()

      vim.keymap.set({ 'n', 'i' }, '<C-j>', '<CR>', {
        buffer = event.buf,
        desc = 'Execute command-line entry',
      })

      vim.keymap.set('n', '<Esc>', '<Cmd>quit<CR>', {
        buffer = event.buf,
        desc = 'Cancel command line',
      })

      vim.keymap.set('n', '<C-c>', '<Cmd>quit<CR>', {
        buffer = event.buf,
        desc = 'Cancel command line',
      })

      vim.keymap.set('i', '<C-c>', '<Esc>', {
        buffer = event.buf,
        desc = 'Return to normal mode',
      })
    end,
  })
end

return M

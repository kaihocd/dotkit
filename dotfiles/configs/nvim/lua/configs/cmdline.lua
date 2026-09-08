local ENTRY_COMMANDS = {
  [':'] = 'q:',
  ['/'] = 'q/',
  ['?'] = 'q?',
}

local CMDLINE_WINHIGHLIGHT = 'Normal:MsgArea,Search:,CurSearch:,IncSearch:'
local CMDWIN_ZINDEX = 201 -- One layer above ui2 Cmdline (200).

local function keep_current_line(buf)
  local lineCount = vim.api.nvim_buf_line_count(buf)
  local line = vim.api.nvim_buf_get_lines(buf, lineCount - 1, lineCount, false)[1] or ''

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, #line })
end

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

for key, command in pairs(ENTRY_COMMANDS) do
  vim.keymap.set('n', key, command, {
    remap = false,
    desc = 'Open command-line window',
  })
end

local group = vim.api.nvim_create_augroup('ConfigsCmdwin', { clear = true })
vim.api.nvim_create_autocmd('CmdwinEnter', {
  group = group,
  desc = 'Present Cmdwin as the command line',
  callback = function(event)
    keep_current_line(event.buf)
    configure_window(vim.api.nvim_get_current_win())

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

    vim.keymap.set('i', '<C-c>', '<Esc><Cmd>quit<CR>', {
      buffer = event.buf,
      desc = 'Cancel command line',
    })

    vim.cmd.startinsert()
  end,
})

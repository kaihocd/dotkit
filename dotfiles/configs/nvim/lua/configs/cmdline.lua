local CMDLINE_WINHIGHLIGHT = 'Normal:MsgArea,Search:,CurSearch:,IncSearch:'
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

for key, command in pairs({ [':'] = 'q:', ['/'] = 'q/', ['?'] = 'q?' }) do
  vim.keymap.set('n', key, command, { desc = 'Open command-line window' })
end
vim.opt.incsearch = true

local function preview_search(buf, win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local match
  local old_hlsearch = vim.v.hlsearch
  vim.v.hlsearch = 0
  local autocmds = {}
  local finished = false

  local function clear()
    if match and vim.api.nvim_win_is_valid(win) then
      pcall(vim.fn.matchdelete, match, win)
    end
    match = nil
  end

  local function update()
    clear()
    if finished or not vim.api.nvim_win_is_valid(win) then return end
    local pattern = vim.api.nvim_get_current_line()
    if pattern == '' then return end
    -- matchadd honors ignorecase, but not smartcase. Explicit regex case
    -- atoms (\\c / \\C) in the user's pattern take precedence over this prefix.
    local insensitive = vim.o.ignorecase
      and not (vim.o.smartcase and pattern:find('%u'))
    local prefix = insensitive and '\\c' or '\\C'
    local ok, id = pcall(vim.fn.matchadd, 'Search', prefix .. pattern, 10, -1, { window = win })
    if ok then match = id end
  end

  local function cleanup()
    if finished then return end
    finished = true
    clear()
    vim.v.hlsearch = old_hlsearch
    for _, id in ipairs(autocmds) do pcall(vim.api.nvim_del_autocmd, id) end
  end

  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved' }, {
    buffer = buf, callback = update,
  })
  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd({ 'CmdwinLeave', 'BufWipeout' }, {
    buffer = buf, callback = cleanup,
  })
  update()
end

local group = vim.api.nvim_create_augroup('ConfigsCmdwin', { clear = true })
vim.api.nvim_create_autocmd('CmdwinEnter', {
  group = group,
  desc = 'Present Cmdwin as the command line',
  callback = function(event)
    local origin = vim.fn.win_getid(vim.fn.winnr('#'))
    local kind = vim.fn.getcmdwintype()
    configure_window(vim.api.nvim_get_current_win())
    if kind == '/' or kind == '?' then preview_search(event.buf, origin) end
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

    vim.keymap.set('i', '<C-c>', '<Esc><Cmd>quit<CR>', {
      buffer = event.buf,
      desc = 'Cancel command line',
    })

    vim.cmd.startinsert()
  end,
})

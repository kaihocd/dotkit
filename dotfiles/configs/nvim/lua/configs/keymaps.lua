local function navigate_window(direction)
  return function()
    local config = vim.api.nvim_win_get_config(0)
    if config.relative ~= '' then
      return
    end

    vim.cmd.wincmd(direction)
    if vim.bo.buftype == 'terminal' then
      vim.cmd.startinsert()
    end
  end
end

local function toggle_recording()
  local recording_register = vim.fn.reg_recording()
  if recording_register ~= '' then
    vim.cmd('normal! q')
    return
  end

  local register = vim.fn.input('Record macro into register: ')
  if vim.fn.strchars(register) == 1 then
    vim.cmd('normal! q' .. register)
  end
end

vim.keymap.set('n', 'q', '<Nop>', { desc = 'Disable direct macro recording' })
vim.keymap.set('n', '<leader>q', toggle_recording, { desc = 'Toggle macro recording' })

vim.keymap.set('i', '<C-c>', '<Esc>', { desc = 'Exit insert mode' })
vim.keymap.set('n', '<Esc>', '<Cmd>nohlsearch<CR>', { desc = 'Clear search highlighting' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

local function resize_width(delta)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(win, math.max(vim.api.nvim_win_get_width(win) + delta, 1))
  end
end

local function resize_height(delta)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_height(win, math.max(vim.api.nvim_win_get_height(win) + delta, 1))
  end
end

vim.keymap.set('n', '<M-S-h>', resize_width(-2), { desc = 'Decrease window width' })
vim.keymap.set('n', '<M-S-l>', resize_width(2), { desc = 'Increase window width' })
vim.keymap.set('n', '<M-S-j>', resize_height(-2), { desc = 'Decrease window height' })
vim.keymap.set('n', '<M-S-k>', resize_height(2), { desc = 'Increase window height' })

vim.keymap.set({ 'n', 't' }, '<M-h>', navigate_window('h'), { desc = 'Focus left window' })
vim.keymap.set({ 'n', 't' }, '<M-l>', navigate_window('l'), { desc = 'Focus right window' })
vim.keymap.set({ 'n', 't' }, '<M-j>', navigate_window('j'), { desc = 'Focus lower window' })
vim.keymap.set({ 'n', 't' }, '<M-k>', navigate_window('k'), { desc = 'Focus upper window' })

-- stylua: ignore start
vim.keymap.set('n', '<leader><Tab><Tab>', '<Cmd>tab split<CR>', { desc = 'Open current window in new tab' })
vim.keymap.set('n', '<leader><Tab>C', '<Cmd>tabonly<CR>', { desc = 'Close other tabs' })
vim.keymap.set('n', '<leader><Tab>n', '<Cmd>tabnew<CR>', { desc = 'Open new tab' })
vim.keymap.set('n', '<leader><Tab>c', '<Cmd>tabclose<CR>', { desc = 'Close current tab' })
vim.keymap.set('n', '<leader><Tab>l', '<Cmd>tabnext<CR>', { desc = 'Go to next tab' })
vim.keymap.set('n', '<leader><Tab>h', '<Cmd>tabprevious<CR>', { desc = 'Go to previous tab' })
-- stylua ignore: end

-- stylua ignore: start
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center cursor' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center cursor' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Go to next search match' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Go to previous search match' })
vim.keymap.set('x', '<', '<gv', { desc = 'Indent left and preserve selection' })
vim.keymap.set('x', '>', '>gv', { desc = 'Indent right and preserve selection' })
vim.keymap.set('x', 'J', ":move '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('x', 'K', ":move '<-2<CR>gv=gv", { desc = 'Move selection up' })
vim.keymap.set({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move down by display line' })
vim.keymap.set({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move up by display line' })
vim.keymap.set('n', 'yA', '<Cmd>%yank<CR>', { desc = 'Yank entire buffer' })
vim.keymap.set('n', 'yc', 'yygccp', { remap = true, desc = 'Comment current line and duplicate below' })
-- stylua ignore: end

vim.keymap.set('c', '<Tab>', '<Nop>')
vim.keymap.set('c', '<S-Tab>', '<Nop>')

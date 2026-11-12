-- Default keymaps and the native Neovim mapping modes they may use.
--
-- Data only; `picker/config/rules.lua` validates user keymaps against `modes`.

local M = {}

M.modes = {
  n = true,
  i = true,
  v = true,
  x = true,
  s = true,
  o = true,
  c = true,
  t = true,
  l = true,
  [''] = true,
  ['!'] = true,
}

M.picker = {
  ['<C-l>'] = 'cycle_match_mode',
  ['<C-f>'] = 'preview_down',
  ['<C-b>'] = 'preview_up',
  ['<LeftMouse>'] = 'click',
  ['<C-s>'] = 'open_split',
  ['<C-v>'] = 'open_vsplit',
  ['<C-t>'] = 'open_tab',
  ['<C-q>'] = 'quickfix',
  ['<Tab>'] = 'mark_next',
  ['<S-Tab>'] = 'mark_previous',
  ['<C-n>'] = 'next',
  ['<Down>'] = 'next',
  ['<C-p>'] = 'previous',
  ['<Up>'] = 'previous',
  ['<CR>'] = 'confirm',
  ['<C-j>'] = 'confirm',
  ['<Esc>'] = 'cancel',
  ['<C-c>'] = 'cancel',
  ['<C-o>'] = 'toggle_preview',
  ['<C-d>'] = 'page_down',
  ['<C-u>'] = 'page_up',
}

M.select = {
  ['<CR>'] = 'confirm',
  ['<C-j>'] = 'confirm',
  ['<C-l>'] = 'toggle_detail',
  ['<Esc>'] = 'cancel',
  ['<C-c>'] = 'cancel',
  ['<C-n>'] = 'next',
  ['<C-p>'] = 'previous',
  ['<C-d>'] = 'page_down',
  ['<C-u>'] = 'page_up',
  ['<LeftMouse>'] = 'click',
}

return M

local M = {}

M.opts = {
  keymap = {
    preset = 'default',
    ['<C-j>'] = { 'select_and_accept', 'fallback' },
    ['<C-y>'] = false,
    ['<C-h>'] = { 'snippet_backward', 'fallback' },
    ['<C-l>'] = { 'snippet_forward', 'fallback' },
    ['<C-e>'] = { 'hide', 'hide_signature', 'fallback' },
  },
  completion = {
    list = { selection = { preselect = true, auto_insert = false } },
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    menu = { auto_show = true },
  },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  fuzzy = { implementation = 'prefer_rust' },
  signature = { enabled = true },
  cmdline = {
    keymap = { preset = 'inherit' },
    completion = { menu = { auto_show = true } },
  },
}

return M

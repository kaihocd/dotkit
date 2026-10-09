---@class picker.picker.ViewOptions
---@field icon? false|fun(path: string): string?, string? Absolute path; returns glyph and optional highlight. nil auto-detects a provider.
---@field presentation? picker.picker.PresentationOptions
---@field layout? picker.picker.LayoutOptions|picker.picker.LayoutBuilder

---@alias picker.picker.LayoutBuilder fun(panes: picker.picker.LayoutPanes, context: picker.picker.LayoutContext): popup.node

---@class picker.picker.LayoutOptions
---@field width_ratio? number Fraction of editor columns in (0, 1]; default 0.7, minimum 20 cells.
---@field height_ratio? number Fraction of editor lines in (0, 1]; default 0.7, minimum 6 cells.
---@field build? picker.picker.LayoutBuilder Custom pane arrangement within the computed root budget.

---@class picker.picker.LayoutPanes
---@field input popup.node.pane
---@field list popup.node.pane
---@field preview? popup.node.pane

---@class picker.picker.LayoutContext
---@field width integer Available root width.
---@field height integer Available root height.

local M = {}

M.resume_grep_pages = 10
M.grep_page_size = 100
M.scan_poll_ms = 100
M.debounce_ms = 40

-- One outer inset, one status cell and one separator precede every entry.
M.list_padding = { left = 3, right = 1 }
M.status_column = 1
M.staged_foreground_ratio = 0.6
M.git = {
  untracked = { '┆', 'Added' },
  modified = { '┃', 'Changed' },
  deleted = { '┃', 'Removed' },
  staged_new = { '┃', 'Added' },
  staged_modified = { '┃', 'Changed' },
  staged_deleted = { '┃', 'Removed' },
  renamed = { '┃', 'Special' },
}

M.keymaps = {
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

return M

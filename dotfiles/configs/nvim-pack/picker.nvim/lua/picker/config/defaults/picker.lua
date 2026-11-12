-- Picker default values.
--
-- Data only; shape rules for user overrides live in `picker/config/rules.lua`.
-- The defaults double as the accepted key set.

local keys = require('picker.config.defaults.keys')

local M = {
  view = {
    layout = { width_ratio = 0.75, height_ratio = 0.75 },
    signs = {
      staged_foreground_ratio = 0.6,
      git = {
        untracked = { '┆', 'Added' },
        modified = { '┃', 'Changed' },
        deleted = { '┃', 'Removed' },
        staged_new = { '┃', 'Added' },
        staged_modified = { '┃', 'Changed' },
        staged_deleted = { '┃', 'Removed' },
        renamed = { '┃', 'Special' },
      },
    },
    presentation = {
      prefix = { text = { files = ' Files ', grep = ' Grep ' }, highlight = 'FloatTitle', margin = { 0, 1 } },
      row = { match = 'Search', current = 'CursorLine' },
      marker = { text = '▊', highlight = 'Title' },
      status = {
        highlight = 'Comment',
        selected_suffix = ' selected',
        separator = ' · ',
        trailing_space = ' ',
      },
      messages = { empty = 'No Item', indexing = 'Indexing…' },
    },
  },
  keymaps = { n = keys.picker, i = vim.deepcopy(keys.picker) },
  search = { debounce_ms = 40, scan_poll_ms = 100, grep_page_size = 100, resume_grep_pages = 10 },
  preview = { max_files = 32, max_bytes = 8 * 1024 * 1024, radius = 2, max_prefetch = 4 },
}

return M

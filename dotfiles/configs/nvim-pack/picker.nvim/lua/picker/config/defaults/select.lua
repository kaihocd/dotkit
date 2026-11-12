-- Select default values.
--
-- Data only; shape rules for user overrides live in `picker/config/rules.lua`.

local keys = require('picker.config.defaults.keys')

local M = {
  view = {
    min_items = 1,
    max_items = 8,
    min_width = 20,
    max_width = 80,
    padding = { left = 2, right = 1 },
    prefix = { text = ' Select ', highlight = 'FloatTitle', margin = { 0, 1 } },
    highlights = { prompt = 'Comment', current = 'CursorLine', hint = 'Comment' },
  },
  keymaps = { n = keys.select, i = vim.deepcopy(keys.select) },
}

return M

local M = {}
local WIDE_COLUMNS = 140

local function preferred_layout()
  return vim.o.columns < WIDE_COLUMNS and 'diff1_inline' or 'diff2_horizontal'
end

local function sync_layout()
  local config = require('diffview.config').get_config()
  local layout = preferred_layout()
  config.view.default.layout = layout
  config.view.file_history.layout = layout

  local view = require('diffview.lib').get_current_view()
  if not view or not view.cur_layout then
    return
  end

  local current = view.cur_layout.name
  if (current == 'diff1_inline' or current == 'diff2_horizontal') and current ~= layout then
    require('diffview.actions').cycle_layout()
  end
end

local function enable_diff_folding()
  vim.wo.foldmethod = 'diff'
  vim.wo.foldenable = true
end

local function set_deletion_highlight(winid, inline)
  -- Enhanced deletion colors describe filler rows in split diffs, but inline
  -- deletions are real code. Never modify shared highlight groups here.
  local highlights = {}
  local mappings = vim.split(vim.wo[winid].winhl, ',', { trimempty = true })

  for _, mapping in ipairs(mappings) do
    if not mapping:match('^DiffviewDiffDelete:') then
      highlights[#highlights + 1] = mapping
    end
  end

  if inline then
    highlights[#highlights + 1] = 'DiffviewDiffDelete:DiffDelete'
  end

  vim.wo[winid].winhl = table.concat(highlights, ',')
end

local function configure_diff_window(bufnr, winid, ctx)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  if vim.api.nvim_win_get_buf(winid) ~= bufnr then
    return
  end

  vim.wo[winid].foldcolumn = '0'
  vim.wo[winid].foldlevel = 0
  set_deletion_highlight(winid, ctx.layout_name == 'diff1_inline')
end

function M.config()
  local actions = require('diffview.actions')
  require('diffview').setup({
    enhanced_diff_hl = true,
    signs = {
      fold_closed = '',
      fold_open = '',
    },
    file_panel = {
      listing_style = 'tree',
      win_config = { width = 'auto' },
      always_show_marks = false,
      mark_placement = 'inline',
    },
    view = {
      default = { layout = preferred_layout() },
      file_history = { layout = preferred_layout() },
      foldlevel = 0,
      cycle_layouts = { default = { 'diff2_horizontal', 'diff1_inline' } },
      inline = { fold_unchanged = true },
    },
    hooks = {
      diff_buf_read = enable_diff_folding,
      diff_buf_win_enter = configure_diff_window,
    },
    keymaps = {
      view = { { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } } },
      file_panel = { { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } } },
      file_history_panel = {
        { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } },
      },
    },
  })

  vim.keymap.set('n', '<leader>gg', function()
    sync_layout()
    vim.cmd('DiffviewOpen')
  end, { desc = 'Git changes' })

  vim.keymap.set('n', '<leader>gf', function()
    sync_layout()
    require('plugins.git.diffview.history').open(false)
  end, { desc = 'Git file history' })

  vim.keymap.set('n', '<leader>gl', function()
    sync_layout()
    require('plugins.git.diffview.history').open(true)
  end, { desc = 'Git line history' })

  vim.keymap.set('x', '<leader>gl', function()
    local first, last = vim.fn.line('.'), vim.fn.line('v')
    sync_layout()
    require('plugins.git.diffview.history').open(true, math.min(first, last), math.max(first, last))
  end, { desc = 'Git selected lines history' })

  vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, {
    group = vim.api.nvim_create_augroup('DotkitDiffviewLayout', { clear = true }),
    callback = function()
      vim.schedule(sync_layout)
    end,
  })
end

return M

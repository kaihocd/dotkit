local M = {}

local WIDE_COLUMNS = 140
local INLINE_LAYOUT = 'diff1_inline'
local HORIZONTAL_LAYOUT = 'diff2_horizontal'

local function preferred_layout()
  return vim.o.columns < WIDE_COLUMNS and INLINE_LAYOUT or HORIZONTAL_LAYOUT
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
  if (current == INLINE_LAYOUT or current == HORIZONTAL_LAYOUT) and current ~= layout then
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
  set_deletion_highlight(winid, ctx.layout_name == INLINE_LAYOUT)
end

function M.config()
  local actions = require('diffview.actions')
  local history = require('plugins.git.diffview.history')
  local layout = preferred_layout()

  require('diffview').setup({
    show_help_hints = false,
    show_root_path = false,
    enhanced_diff_hl = true,
    icons = {
      folder_closed = '',
      folder_open = '',
    },
    signs = {
      fold_closed = '',
      fold_open = '',
      selected_file = '󰄮',
      unselected_file = '󰄱',
      selected_dir = '󰄮',
      partially_selected_dir = '󰡖',
      unselected_dir = '󰄱',
    },
    file_panel = {
      always_show_marks = true,
      mark_placement = 'inline',
    },
    view = {
      default = { layout = layout },
      file_history = { layout = layout },
      foldlevel = 0,
      cycle_layouts = { default = { HORIZONTAL_LAYOUT, INLINE_LAYOUT } },
      inline = { fold_unchanged = true },
    },
    hooks = {
      diff_buf_read = enable_diff_folding,
      diff_buf_win_enter = configure_diff_window,
    },
    keymaps = {
      view = {
        { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } },
        { 'n', '<C-r>', actions.refresh_files, { desc = 'Refresh diff' } },
      },
      file_panel = {
        { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } },
        { 'n', '<C-r>', actions.refresh_files, { desc = 'Refresh diff' } },
      },
      file_history_panel = {
        { 'n', '<leader>i', actions.cycle_layout, { desc = 'Switch diff layout' } },
        { 'n', '<C-r>', actions.refresh_files, { desc = 'Refresh history' } },
      },
    },
  })

  vim.keymap.set('n', '<leader>gg', function()
    sync_layout()
    vim.cmd('DiffviewOpen')
  end, { desc = 'Git changes' })

  vim.keymap.set('n', '<leader>gf', function()
    sync_layout()
    history.open_file()
  end, { desc = 'Git file history' })

  vim.keymap.set('n', '<leader>gl', function()
    sync_layout()
    history.open_lines()
  end, { desc = 'Git line history' })

  vim.keymap.set('x', '<leader>gl', function()
    local first, last = vim.fn.line('.'), vim.fn.line('v')
    sync_layout()
    history.open_lines(first, last)
  end, { desc = 'Git selected lines history' })

  vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, {
    group = vim.api.nvim_create_augroup('DotkitDiffviewLayout', { clear = true }),
    callback = function()
      vim.schedule(sync_layout)
    end,
  })
end

return M

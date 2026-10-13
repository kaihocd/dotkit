local M = {}

M.opts = {
  view = { style = 'sign', signs = { add = '┃', change = '┃', delete = '┃' } },
  mappings = {
    apply = '',
    reset = '',
    textobject = '',
    goto_first = '',
    goto_prev = '',
    goto_next = '',
    goto_last = '',
  },
}

local function apply_current_hunk(action)
  local diff = require('mini.diff')
  local data = diff.get_buf_data(0)
  local line = vim.fn.line('.')

  for _, hunk in ipairs(data and data.hunks or {}) do
    local first = math.max(1, hunk.buf_start)
    local last = math.max(first, hunk.buf_start + hunk.buf_count - 1)
    if first <= line and line <= last then
      diff.do_hunks(0, action, { line_start = first, line_end = last })
      return
    end
  end
  vim.notify('No hunk under cursor', vim.log.levels.INFO)
end

local function apply_selected_lines(action)
  local first, last = vim.fn.line('.'), vim.fn.line('v')
  require('mini.diff').do_hunks(0, action, {
    line_start = math.min(first, last),
    line_end = math.max(first, last),
  })
end

function M.config(opts)
  local diff = require('mini.diff')

  diff.setup(opts)

  vim.keymap.set('n', ']h', function()
    if vim.wo.diff then
      vim.cmd.normal({ ']c', bang = true })
    else
      diff.goto_hunk('next')
    end
  end, { desc = 'Next hunk' })
  vim.keymap.set('n', '[h', function()
    if vim.wo.diff then
      vim.cmd.normal({ '[c', bang = true })
    else
      diff.goto_hunk('prev')
    end
  end, { desc = 'Previous hunk' })
  vim.keymap.set('n', '<leader>hp', function()
    diff.toggle_overlay()
  end, { desc = 'Toggle diff overlay' })
  vim.keymap.set('n', '<leader>hs', function()
    apply_current_hunk('apply')
  end, { desc = 'Stage hunk' })
  vim.keymap.set('n', '<leader>hr', function()
    apply_current_hunk('reset')
  end, { desc = 'Reset hunk' })
  vim.keymap.set('n', '<leader>hS', function()
    diff.do_hunks(0, 'apply')
  end, { desc = 'Stage buffer' })
  vim.keymap.set('n', '<leader>hR', function()
    diff.do_hunks(0, 'reset')
  end, { desc = 'Reset buffer' })
  vim.keymap.set('x', '<leader>hs', function()
    apply_selected_lines('apply')
  end, { desc = 'Stage selected lines' })
  vim.keymap.set('x', '<leader>hr', function()
    apply_selected_lines('reset')
  end, { desc = 'Reset selected lines' })
end

return M

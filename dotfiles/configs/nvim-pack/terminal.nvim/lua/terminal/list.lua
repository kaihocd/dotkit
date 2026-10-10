local state = require('terminal.state')

-- Terminal list view rendering.
local M = {}

-- Create a scratch buffer for the left terminal list.
---@return integer
function M.create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })

  return buf
end

-- Create a scratch buffer for the left help pane.
---@return integer
function M.create_help_buffer()
  local config = require('terminal.config')
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.deepcopy(config.get().help_text)

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })

  local ns = vim.api.nvim_create_namespace('terminal-help')
  for i = 1, #lines do
    local line = lines[i]
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
      end_row = i - 1,
      end_col = #line,
      hl_group = 'TerminalHelp',
    })
  end

  return buf
end

-- Ensure list and help buffers exist and are bound to keymaps.
---@param api table
function M.ensure_buffers(api)
  local keymaps = require('terminal.keymaps')
  local recreated = false

  if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
    state.list_buf = M.create_buffer()
    keymaps.setup_list(state.list_buf, api)
    recreated = true

    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = state.list_buf,
      callback = function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        if cursor[2] ~= 0 then
          vim.api.nvim_win_set_cursor(0, { cursor[1], 0 })
        end
      end,
    })
  end

  if not state.help_buf or not vim.api.nvim_buf_is_valid(state.help_buf) then
    state.help_buf = M.create_help_buffer()
    recreated = true
  end

  if recreated then
    state.popup = nil
  end
end

-- Refresh the list line placeholders.
function M.refresh_lines()
  local buf = state.list_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local terminals = state.terminals

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  local lines = {}
  for _ in ipairs(terminals) do
    table.insert(lines, '')
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

-- Render terminal names as virtual text with active highlight.
function M.render_highlights()
  local buf = state.list_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local active = state.current_index
  local terminals = state.terminals

  vim.api.nvim_buf_clear_namespace(buf, state.list_ns, 0, -1)

  for i, term in ipairs(terminals) do
    local hl = i == active and 'TerminalListActive' or 'TerminalListNormal'
    vim.api.nvim_buf_set_extmark(buf, state.list_ns, i - 1, 0, {
      virt_text = { { ' ' .. term.name, hl } },
      virt_text_pos = 'inline',
    })
    vim.api.nvim_buf_set_extmark(buf, state.list_ns, i - 1, 0, {
      virt_text = { { tostring(i) .. ' ', hl } },
      virt_text_pos = 'right_align',
    })
  end
end

-- Move the list cursor to the given index.
---@param win? integer
---@param index integer
function M.set_cursor(win, index)
  if win and not state.syncing then
    state.syncing = true
    vim.api.nvim_win_set_cursor(win, { index, 0 })
    state.syncing = false
  end
end

-- Return the terminal index under the list cursor.
---@param win? integer
---@return integer?
function M.cursor_index(win)
  if not win then
    return nil
  end

  local row = vim.api.nvim_win_get_cursor(win)[1]
  if row < 1 or row > #state.terminals then
    return nil
  end

  return row
end

return M

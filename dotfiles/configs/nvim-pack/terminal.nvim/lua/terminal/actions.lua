local float = require('terminal.float')
local lifecycle = require('terminal.lifecycle')
local list = require('terminal.list')
local state = require('terminal.state')
local util = require('terminal.util')

-- User-facing terminal actions. This is the orchestration layer between state,
-- terminal lifecycle, list rendering, and the floating UI.
local M = {}

---@param index integer
function M.select(index)
  if not state.select(index) then
    return
  end

  local current = state.current()
  if current then
    float.set_term_buffer(current.buf)
  end

  list.render_highlights()
  list.set_cursor(float.list_win(), state.current_index)
end

-- Select the next terminal record.
function M.next()
  M.select(state.current_index + 1)
end

-- Select the previous terminal record.
function M.prev()
  M.select(state.current_index - 1)
end

-- Select the terminal under the list cursor and focus its pane.
function M.select_under_cursor()
  local index = list.cursor_index(float.list_win())
  if not index then
    return
  end

  M.select(index)
  float.focus_right()
end

-- Rename the terminal under the list cursor.
function M.rename_under_cursor()
  local index = list.cursor_index(float.list_win())
  if not index then
    return
  end

  local target_buf = state.terminals[index].buf
  vim.ui.input({ prompt = 'Rename terminal: ' }, function(input)
    if not input or input == '' then
      return
    end

    for current_index, term in ipairs(state.terminals) do
      if term.buf == target_buf then
        lifecycle.rename(current_index, input)
        list.render_highlights()
        break
      end
    end
  end)
end

-- Stop or remove the terminal under the list cursor.
---@param api table
function M.delete_under_cursor(api)
  local index = list.cursor_index(float.list_win())
  if not index then
    return
  end

  lifecycle.stop_or_remove(index, api)
end

-- Reconcile state and UI after a terminal job exits.
---@param buf integer
function M.on_term_close(buf)
  if util.is_exiting() then
    return
  end

  local removed = lifecycle.remove_closed(buf)
  if not removed then
    return
  end
  if state.count() == 0 then
    float.close()
  else
    list.refresh_lines()
    M.select(state.current_index)
  end
  util.delete_buffer_if_hidden(removed.buf)
end

return M

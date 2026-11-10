local actions = require('terminal.actions')
local config = require('terminal.config')
local float = require('terminal.float')
local highlights = require('terminal.highlights')
local lifecycle = require('terminal.lifecycle')
local list = require('terminal.list')
local state = require('terminal.state')

-- Terminal manager public API.
local M = {}

local setup_done = false

-- Configure the terminal plugin. Must be called before any other API.
---@param opts? table
function M.setup(opts)
  config.setup(opts)
  if setup_done then
    return
  end
  setup_done = true
  highlights.setup()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('TerminalLifecycle', { clear = true }),
    callback = function()
      M.shutdown()
    end,
  })
end

-- Create a new terminal session.
---@param opts? { name?: string, cwd?: string, command?: string[], env?: table<string, string>, keep?: boolean, on_exit?: fun(code: integer) }
---@return integer index
function M.new(opts)
  local index = lifecycle.create(opts, M)

  if float.is_open() then
    list.refresh_lines()
    M.select(index)
  end

  return index
end

-- Callback fired when a terminal job exits.
---@param buf integer
function M.on_term_close(buf)
  actions.on_term_close(buf)
end

-- Callback fired after the exit code is known, which is after `on_term_close`.
---@param buf integer
---@param code integer
function M.on_term_exit(buf, code)
  actions.on_term_exit(buf, code)
end

-- Remove a session, whether its job is still running or not.
---@param buf integer
function M.forget(buf)
  actions.forget(buf)
end

-- Open the terminal popup, reusing the existing instance if hidden.
function M.open()
  if
    state.popup
    and (
      not state.list_buf
      or not vim.api.nvim_buf_is_valid(state.list_buf)
      or not state.help_buf
      or not vim.api.nvim_buf_is_valid(state.help_buf)
    )
  then
    float.close()
  end
  if float.is_open() then
    return
  end

  lifecycle.ensure_one(M)
  state.settings = state.settings or config.get()
  local ok, failure = pcall(function()
    list.ensure_buffers(M)
    list.refresh_lines()
    list.render_highlights()
    float.open()
    list.set_cursor(float.list_win(), state.current_index)
  end)
  if not ok then
    -- Preserve shell jobs; discard the failed UI so a later open can retry.
    local instance = state.popup
    state.popup, state.settings = nil, nil
    if instance then
      pcall(instance.close, instance)
    end
    error(failure, 0)
  end
end

-- Close the terminal popup and release owned resources.
function M.close()
  float.close()
end

-- Hide the terminal popup but keep buffers alive.
function M.hide()
  float.hide()
end

-- Toggle the terminal popup open or hidden.
function M.toggle()
  if float.is_open() then
    M.hide()
  else
    M.open()
  end
end

-- Select the terminal at the given index.
---@param index integer
function M.select(index)
  actions.select(index)
end

-- Select the next terminal.
function M.next()
  actions.next()
end

-- Select the previous terminal.
function M.prev()
  actions.prev()
end

-- Move focus to the left list pane.
function M.focus_left()
  float.focus_left()
end

-- Move focus to the right terminal pane.
function M.focus_right()
  float.focus_right()
end

-- Rename the terminal under the list cursor.
function M.rename_under_cursor()
  actions.rename_under_cursor()
end

-- Select the terminal under the list cursor.
function M.select_under_cursor()
  actions.select_under_cursor()
end

-- Stop and remove the terminal under the list cursor.
function M.delete_under_cursor()
  actions.delete_under_cursor(M)
end

-- Release all owned resources, including shell jobs. Never creates replacements.
function M.shutdown()
  float.close()
  lifecycle.shutdown()
end

-- Expose pane window accessors.
M.list_win = float.list_win
M.term_win = float.term_win
M.help_win = float.help_win

return M

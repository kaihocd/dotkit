local Popup = require('popup')
local extensions = require('popup.extensions')
local highlights = require('terminal.highlights')
local state = require('terminal.state')

-- Terminal floating UI layer backed by the popup library.
local M = {}

-- Return the list pane window, if visible.
---@return integer?
function M.list_win()
  if not state.popup then
    return nil
  end

  local pane = state.popup:pane('list')
  if pane and pane.win and vim.api.nvim_win_is_valid(pane.win) then
    return pane.win
  end
  return nil
end

-- Return the terminal pane window, if visible.
---@return integer?
function M.term_win()
  if not state.popup then
    return nil
  end

  local pane = state.popup:pane('term')
  if pane and pane.win and vim.api.nvim_win_is_valid(pane.win) then
    return pane.win
  end
  return nil
end

-- Return the help pane window, if visible.
---@return integer?
function M.help_win()
  if not state.popup then
    return nil
  end

  local pane = state.popup:pane('help')
  if pane and pane.win and vim.api.nvim_win_is_valid(pane.win) then
    return pane.win
  end
  return nil
end

-- Return true when the floating terminal is open.
---@return boolean
function M.is_open()
  if not state.popup then
    return false
  end

  return state.popup:is_open()
end

-- Calculate the centered floating window geometry.
---@return { row: integer, col: integer, width: integer, height: integer }
local function geometry()
  local cfg = assert(state.settings)
  local width = math.max(1, math.floor(vim.o.columns * cfg.width_ratio))
  local height = math.max(3, math.floor(vim.o.lines * cfg.height_ratio))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  return { row = row, col = col, width = width, height = height }
end

-- Build the popup tree for the terminal layout.
---@return popup.instance
local function build()
  local cfg = assert(state.settings)
  local g = geometry()
  local current = assert(state.current(), 'terminal.float: no terminal available')
  local help_height = cfg.help_text and #cfg.help_text or 1

  local instance = Popup.root({
    row = g.row,
    col = g.col,
    width = g.width,
    height = g.height,
    layout = Popup.row({
      children = {
        Popup.col({
          size = { fixed = cfg.list_width },
          children = {
            Popup.pane({
              id = 'list',
              border = cfg.border,
              size = { flex = 1 },
              buf = state.list_buf,
              win_config = {
                title = cfg.list_title,
                title_pos = 'center',
              },
            }),
            Popup.pane({
              id = 'help',
              border = cfg.border,
              size = { fixed = help_height },
              buf = state.help_buf,
              enter = false,
              win_config = {
                title = cfg.help_title,
                title_pos = 'center',
                focusable = false,
              },
            }),
          },
        }),
        Popup.pane({
          id = 'term',
          border = cfg.border,
          size = { flex = 1 },
          buf = current.buf,
          enter = true,
          win_config = {
            title = cfg.term_title,
            title_pos = 'center',
          },
        }),
      },
    }),
  })

  instance:on('close', function()
    if state.popup == instance then
      state.popup = nil
      state.settings = nil
    end
  end)
  if cfg.group then
    instance:join_group(cfg.group)
  end
  instance:use(extensions.resize({ geometry = geometry }))

  return instance
end

-- Swap the right pane to display the selected terminal buffer.
---@param buf integer
function M.set_term_buffer(buf)
  if not state.popup then
    return
  end

  state.popup:set_pane_buf('term', buf)
  if M.is_open() then
    state.popup:render()
  end
end

-- Focus the terminal list pane.
function M.focus_left()
  local win = M.list_win()
  if win then
    vim.api.nvim_set_current_win(win)
  end
end

-- Focus the terminal pane and optionally enter insert mode.
function M.focus_right()
  local win = M.term_win()
  if win then
    vim.api.nvim_set_current_win(win)
    if assert(state.settings).auto_insert then
      vim.cmd('startinsert')
    end
  end
end

-- Open the floating terminal, building the popup instance when needed.
function M.open()
  if M.is_open() then
    return
  end

  local cfg = assert(state.settings)
  state.popup = state.popup or build()
  state.popup:open()

  local list_win = M.list_win()
  local term_win = M.term_win()
  local help_win = M.help_win()

  highlights.apply_winhl(list_win, term_win, help_win)

  if cfg.auto_insert and vim.api.nvim_get_current_win() == term_win then
    vim.cmd('startinsert')
  end

  if cfg.on_open then
    cfg.on_open(list_win, term_win, help_win)
  end
end

-- Close the floating terminal and release the popup instance.
function M.close()
  local cfg = state.settings

  if state.popup then
    state.popup:close()
    state.popup = nil
  end

  state.settings = nil
  if cfg and cfg.on_close then
    cfg.on_close()
  end
end

-- Hide the floating terminal while preserving buffers and state.
function M.hide()
  if state.popup then
    state.popup:hide()
  end
end

return M

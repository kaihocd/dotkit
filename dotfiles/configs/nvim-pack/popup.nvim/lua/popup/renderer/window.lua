local buffer = require('popup.renderer.buffer')

-- Window creation and management for popup nodes.
local M = {}

-- Buffer mappings must preserve native behavior when a shared buffer leaves the popup.
local DISABLED_NORMAL_KEYS = { '<C-o>', '<C-i>' }
local popup_windows = {}

local function apply_navigation_defaults(win, buf)
  popup_windows[win] = true
  vim.api.nvim_buf_call(buf, function()
    for _, key in ipairs(DISABLED_NORMAL_KEYS) do
      -- Explicit buffer/global mappings take precedence over these defaults.
      if vim.fn.maparg(key, 'n') == '' then
        local native_key = vim.api.nvim_replace_termcodes(key, true, false, true)
        vim.keymap.set('n', key, function()
          return popup_windows[vim.api.nvim_get_current_win()] and '' or native_key
        end, {
          buffer = buf,
          expr = true,
          replace_keycodes = false,
          desc = 'Popup: disable jump navigation',
        })
      end
    end
  end)
end

---@param node popup.config.root|popup.config.pane
---@param zindex integer
---@return vim.api.keyset.win_config
function M.make_win_config(node, zindex)
  local opts = {
    relative = 'editor',
    row = node.rect.row,
    col = node.rect.col,
    width = node.rect.width,
    height = node.rect.height,
    border = node.border,
    style = 'minimal',
    zindex = zindex,
  }

  for key, value in pairs(node.win_config) do
    opts[key] = value
  end

  opts.zindex = zindex

  if node.type == 'root' then
    -- Keep the background inside its layout rectangle; visible borders belong to panes.
    opts.border = 'none'
    opts.focusable = false
  end

  return opts
end

---@param instance popup.instance
---@param win integer
local function create_close_autocmd(instance, win)
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      popup_windows[win] = nil
      -- Layout updates detach removed panes before closing their windows.
      -- Only closing a window still owned by the popup ends its lifetime.
      if instance._root and instance._root.win == win then
        instance:close()
        return
      end
      for _, pane in ipairs(instance._panes.list) do
        if pane.win == win then
          instance:close()
          return
        end
      end
    end,
  })
end

---@param map table<string, popup.pane>
---@param id string
local function assert_unique_id(map, id)
  if map[id] then
    error('popup: duplicate pane id "' .. id .. '"')
  end
end

-- Ensure a window exists for the given node, reusing an existing window/buffer when possible.
---@param instance popup.instance
---@param node popup.config.root|popup.config.pane
---@param zindex integer
---@param existing_win? integer
---@param existing_buf? integer
---@param existing_scratch? boolean
---@return integer win
---@return integer buf
---@return boolean scratch
function M.ensure_window(instance, node, zindex, existing_win, existing_buf, existing_scratch)
  local buf
  local scratch

  if node.buf and vim.api.nvim_buf_is_valid(node.buf) then
    buf = node.buf
    scratch = false
  elseif existing_buf and vim.api.nvim_buf_is_valid(existing_buf) then
    buf = existing_buf
    scratch = existing_scratch or false
  else
    buf, scratch = buffer.create_buffer(node)
  end

  assert(buf, 'Popup buffer allocation must return a buffer')
  local win
  if existing_win and vim.api.nvim_win_is_valid(existing_win) then
    win = existing_win
    if vim.api.nvim_win_get_buf(win) ~= buf then
      vim.api.nvim_win_set_buf(win, buf)
    end
    vim.api.nvim_win_set_config(win, M.make_win_config(node, zindex))
  else
    win = vim.api.nvim_open_win(buf, node.enter, M.make_win_config(node, zindex))
    create_close_autocmd(instance, win)
  end

  apply_navigation_defaults(win, buf)
  return win, buf, scratch
end

-- Expose duplicate pane guard for the renderer orchestration.
M.assert_unique_id = assert_unique_id

return M

local tree = require('popup.tree')
local window = require('popup.renderer.window')

-- Popup renderer orchestration: mount, hide, unmount, and update windows.
local M = {}

---@param instance popup.instance
---@param config popup.config.root
function M.mount(instance, config)
  local nodes = tree.collect(config)
  local base_zindex = config.zindex or 50
  local old_root = instance._root or {}
  local old_panes = instance._panes.list

  do
    local node = nodes[1]
    local win, buf, scratch = window.ensure_window(
      instance,
      node,
      base_zindex,
      old_root.win,
      old_root.buf,
      old_root.scratch
    )
    instance._root = { win = win, buf = buf, scratch = scratch }
  end

  instance._panes = { list = {}, map = {} }

  for i = 2, #nodes do
    local node = nodes[i]
    local old_pane = old_panes[i - 1] or {}
    local win, buf, scratch = window.ensure_window(
      instance,
      node,
      base_zindex + i - 1,
      old_pane.win,
      old_pane.buf,
      old_pane.scratch
    )
    local pane = { win = win, buf = buf, id = node.id, scratch = scratch }

    table.insert(instance._panes.list, pane)

    if node.id and node.id ~= '' then
      window.assert_unique_id(instance._panes.map, node.id)
      instance._panes.map[node.id] = pane
    end
  end
end

-- Close popup windows without deleting buffers.
-- Use this for temporary hides; the caller can reopen the same instance.
---@param instance popup.instance
function M.hide(instance)
  if instance._root and instance._root.win and vim.api.nvim_win_is_valid(instance._root.win) then
    vim.api.nvim_win_close(instance._root.win, true)
  end

  if instance._root then
    instance._root.win = nil
  end

  for _, pane in ipairs(instance._panes.list) do
    if pane.win and vim.api.nvim_win_is_valid(pane.win) then
      vim.api.nvim_win_close(pane.win, true)
    end
    pane.win = nil
  end
end

-- Close popup windows and delete scratch buffers created by the popup.
-- Buffers provided by the caller are never deleted.
---@param instance popup.instance
function M.unmount(instance)
  M.hide(instance)

  if
    instance._root
    and instance._root.scratch
    and instance._root.buf
    and vim.api.nvim_buf_is_valid(instance._root.buf)
  then
    vim.api.nvim_buf_delete(instance._root.buf, { force = true })
  end
  instance._root = nil

  for _, pane in ipairs(instance._panes.list) do
    if pane.scratch and pane.buf and vim.api.nvim_buf_is_valid(pane.buf) then
      vim.api.nvim_buf_delete(pane.buf, { force = true })
    end
  end

  instance._panes = { list = {}, map = {} }
end

---@param instance popup.instance
---@param config popup.config.root
function M.update(instance, config)
  local nodes = tree.collect(config)
  local base_zindex = config.zindex or 50

  do
    local node = nodes[1]
    local root = instance._root or {}
    local win, buf, scratch =
      window.ensure_window(instance, node, base_zindex, root.win, root.buf, root.scratch)
    instance._root = { win = win, buf = buf, scratch = scratch }
  end

  local old_list = instance._panes.list
  local new_list = {}
  local new_map = {}

  for i = 2, #nodes do
    local node = nodes[i]
    local existing = old_list[i - 1] or {}
    local win, buf, scratch = window.ensure_window(
      instance,
      node,
      base_zindex + i - 1,
      existing.win,
      existing.buf,
      existing.scratch
    )
    local pane = { win = win, buf = buf, id = node.id, scratch = scratch }

    table.insert(new_list, pane)

    if node.id and node.id ~= '' then
      window.assert_unique_id(new_map, node.id)
      new_map[node.id] = pane
    end
  end

  for i = #new_list + 1, #old_list do
    local old_pane = old_list[i]
    if old_pane then
      if old_pane.win and vim.api.nvim_win_is_valid(old_pane.win) then
        vim.api.nvim_win_close(old_pane.win, true)
      end
      if old_pane.scratch and old_pane.buf and vim.api.nvim_buf_is_valid(old_pane.buf) then
        vim.api.nvim_buf_delete(old_pane.buf, { force = true })
      end
    end
  end

  instance._panes.list = new_list
  instance._panes.map = new_map
end

return M

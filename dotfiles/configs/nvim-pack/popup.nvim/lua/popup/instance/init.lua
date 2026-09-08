local layout = require('popup.layout')
local renderer = require('popup.renderer')
local tree = require('popup.tree')

local event = require('popup.instance.event')
local group = require('popup.instance.group')
local plugin = require('popup.instance.plugin')

-- Popup instance: public lifecycle API and runtime accessors.
local Instance = {}
Instance.__index = Instance

---@param node popup.node.root
---@return popup.instance
function Instance.new(node)
  return setmetatable({
    _node = node,
    _config = nil,
    _root = nil,
    _panes = { list = {}, map = {} },
    _closing = false,
    _listeners = {},
  }, Instance)
end

---@return boolean
function Instance:is_open()
  return self._root and self._root.win and vim.api.nvim_win_is_valid(self._root.win) or false
end

---Subscribe to an instance lifecycle event.
---@param event_name popup.event
---@param callback fun(...)
---@return popup.instance
function Instance:on(event_name, callback)
  event.on(self, event_name, callback)
  return self
end

---Unsubscribe from an instance lifecycle event.
---@param event_name popup.event
---@param callback fun(...)
---@return popup.instance
function Instance:off(event_name, callback)
  event.off(self, event_name, callback)
  return self
end

---Emit an event to all subscribers.
---@param event_name popup.event
---@param ... any
---@return popup.instance
function Instance:emit(event_name, ...)
  event.emit(self, event_name, ...)
  return self
end

---Apply a plugin to this instance.
---@param p popup.plugin
---@return popup.instance
function Instance:use(p)
  plugin.use(self, p)
  return self
end

---Open the popup.
---If the popup was hidden, existing buffers are reused.
---If no resolved config exists, the current node tree is resolved first.
---@return popup.instance
function Instance:open()
  if self:is_open() then
    return self
  end

  if not self._config then
    self._config = layout.resolve(self._node)
  end

  renderer.mount(self, self._config)

  self:emit('open')

  return self
end

---Hide the popup windows while preserving buffers and configuration.
---@return popup.instance
function Instance:hide()
  if self._closing or not self:is_open() then
    return self
  end

  self._closing = true
  renderer.hide(self)
  self._closing = false

  self:emit('hide')

  return self
end

---Close all windows and release scratch buffers created by the popup.
---The source node tree is preserved, so the instance may be opened again.
---@return popup.instance
function Instance:close()
  if self._closing then
    return self
  end

  self._closing = true
  renderer.unmount(self)
  self._config = nil
  self._closing = false

  self:emit('close')
  self._listeners = {}

  return self
end

---Update the source node tree without rendering.
---Call render() explicitly to apply the changes.
---@param fn fun(root: popup.node.root)
---@return popup.instance
function Instance:update(fn)
  fn(self._node)
  self:emit('update')
  return self
end

---Resolve the current node tree and apply it to the popup.
---If the popup is currently open, existing windows are updated.
---If it is hidden or closed, only the resolved config is refreshed.
---@return popup.instance
function Instance:render()
  local config = layout.resolve(self._node)

  if self:is_open() then
    renderer.update(self, config)
  end

  self._config = config

  self:emit('render')

  return self
end

---Return the root background pane entry.
---@return popup.pane?
function Instance:root()
  return self._root
end

---Return all pane entries in layout order.
---@return popup.pane[]
function Instance:panes()
  return self._panes.list
end

---Find a pane by id.
---@param id string
---@return popup.pane?
function Instance:pane(id)
  return self._panes.map[id]
end

---Set the buffer of a pane by id and return the instance for chaining.
---@param id string
---@param buf integer
---@return popup.instance
function Instance:set_pane_buf(id, buf)
  local pane = tree.find_pane(self._node, id)
  if pane then
    pane.buf = buf
  end
  return self
end

---Join an existing popup group.
---@param name string
---@return popup.instance
function Instance:join_group(name)
  group.join_group(self, name)
  return self
end

---Leave the current popup group.
---@return popup.instance
function Instance:leave_group()
  group.leave_group(self)
  return self
end

return Instance

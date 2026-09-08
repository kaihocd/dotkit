-- Popup event subsystem: instance lifecycle subscriptions.
local M = {}

---@param instance popup.instance
---@param event popup.event
---@param callback fun(...)
function M.on(instance, event, callback)
  instance._listeners[event] = instance._listeners[event] or {}
  table.insert(instance._listeners[event], callback)
end

---@param instance popup.instance
---@param event popup.event
---@param callback fun(...)
function M.off(instance, event, callback)
  local listeners = instance._listeners[event]
  if not listeners then
    return
  end

  for i, cb in ipairs(listeners) do
    if cb == callback then
      table.remove(listeners, i)
      break
    end
  end
end

---@param instance popup.instance
---@param event popup.event
---@param ... any
function M.emit(instance, event, ...)
  local listeners = instance._listeners[event]
  if not listeners then
    return
  end

  for _, callback in ipairs(listeners) do
    callback(...)
  end
end

return M

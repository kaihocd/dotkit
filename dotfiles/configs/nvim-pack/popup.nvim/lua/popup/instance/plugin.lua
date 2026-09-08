-- Popup plugin subsystem: apply third-party extensions to an instance.
local M = {}

---@param instance popup.instance
---@param plugin popup.plugin
function M.use(instance, plugin)
  if type(plugin) == 'function' then
    plugin(instance)
  elseif type(plugin) == 'table' and plugin.apply then
    plugin.apply(instance, plugin.opts)
  end
end

return M

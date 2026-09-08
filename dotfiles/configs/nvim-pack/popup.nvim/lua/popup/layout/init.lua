local resolve = require('popup.layout.resolve')

-- Popup layout facade: resolve a node tree into absolute screen coordinates.
local M = {}

---@param node popup.node.root
---@return popup.config.root
function M.resolve(node)
  return resolve.resolve(node)
end

return M

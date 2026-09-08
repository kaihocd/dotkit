local rect = require('popup.rect')

-- Tree traversal helpers for popup node and config trees.
local M = {}

---Find a pane by id in a node tree.
---@param root popup.node | popup.node.root
---@param id string
---@return popup.node.pane?
function M.find_pane(root, id)
  if root.type == 'pane' and root.id == id then
    return root
  end

  if root.layout then
    local found = M.find_pane(root.layout, id)
    if found then
      return found
    end
  end

  if root.children then
    for _, child in ipairs(root.children) do
      local found = M.find_pane(child, id)
      if found then
        return found
      end
    end
  end

  return nil
end

---@param node popup.config.child
---@param result popup.config.pane[]
local function collect_panes(node, result)
  if node.type == 'pane' then
    result[#result + 1] = node
    return
  end

  for _, child in ipairs(node.children) do
    collect_panes(child, result)
  end
end

---Collect the root and all descendant panes for rendering.
---@param config popup.config.root
---@return (popup.config.root|popup.config.pane)[]
function M.collect(config)
  local result = { config }

  if config.layout then
    collect_panes(config.layout, result)
  end

  return result
end

return M

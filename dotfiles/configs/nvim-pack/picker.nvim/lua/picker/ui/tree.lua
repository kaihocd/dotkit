-- Validation of the tree a user `layout` callback returns.
--
-- Both entry points hand the callback the same kind of object: a root spec plus a
-- table of panes this plugin created. The callback may rearrange those panes but
-- not replace, duplicate, drop or re-buffer them, so the checks are identical.
-- Only the supplied roles and the wording of the failures differ.

local M = {}

---@class picker.ui.TreeSpec
---@field prefix string Message prefix, e.g. `picker` or `picker.select`.
---@field roles string[] Supplied panes; position + 1 is the buffer index.
---@field optional? table<string, boolean> Roles a caller may leave unsupplied.
---@field requires fun(used: table<string, boolean>): string? Failure when a role is missing.

---@param tree any
---@param panes table<string, any> Possibly mutated by the callback.
---@param originals table<string, any> Identities and buffers before the callback ran.
---@param buffers integer[]
---@param spec picker.ui.TreeSpec
---@return any tree
function M.validate(tree, panes, originals, buffers, spec)
  local optional = spec.optional or {}
  local index_of = {}

  -- Compare against pre-callback identities, never the role table the callback held.
  for index, role in ipairs(spec.roles) do
    index_of[role] = index
    local pane = originals[role]
    if panes[role] ~= pane then
      error(spec.prefix .. ': layout cannot replace supplied panes', 0)
    end
    if pane == nil then
      if not optional[role] then
        error(spec.prefix .. ': layout requires every supplied pane', 0)
      end
    elseif
      pane.id ~= role
      or pane.type ~= 'pane'
      or pane.buf ~= buffers[index]
      or not vim.api.nvim_buf_is_valid(buffers[index])
    then
      error(spec.prefix .. ': layout must preserve pane identity and buffer', 0)
    end
  end

  local seen, used = {}, {}

  local function visit(node)
    if type(node) ~= 'table' or seen[node] then
      error(spec.prefix .. ': layout must return a tree without repeated nodes', 0)
    end
    seen[node] = true

    if node.type == 'pane' then
      local id = node.id
      if not index_of[id] or node ~= originals[id] or used[id] then
        error(spec.prefix .. ': layout must use each supplied pane exactly once', 0)
      end
      used[id] = true
      return
    end

    if node.type ~= 'row' and node.type ~= 'col' then
      error(spec.prefix .. ': layout expects native pane, row or col nodes', 0)
    end
    if type(node.children) ~= 'table' or #node.children == 0 then
      error(spec.prefix .. ': layout containers require a nonempty children array', 0)
    end

    -- ipairs alone would silently skip holes and named children.
    local count = 0
    for index in pairs(node.children) do
      if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > #node.children then
        error(spec.prefix .. ': layout children must be a dense array', 0)
      end
      count = count + 1
    end
    if count ~= #node.children then
      error(spec.prefix .. ': layout children must be a dense array', 0)
    end

    for _, child in ipairs(node.children) do
      visit(child)
    end
  end

  visit(tree)

  local problem = spec.requires(used)
  if problem then
    error(spec.prefix .. ': ' .. problem, 0)
  end
  return tree
end

return M

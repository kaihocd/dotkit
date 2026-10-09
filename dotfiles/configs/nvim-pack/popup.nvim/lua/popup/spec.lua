-- User-facing layout spec builders.
-- Specs describe intent; nodes are passed to the layout engine.

---@class (exact) popup.spec.pane
---@field id? string
---@field size? popup.size
---@field border? popup.border
---@field enter? boolean
---@field win_config? popup.win_config
---@field content? string[]
---@field buf? integer

---@class (exact) popup.spec.flex
---@field size? popup.size
---@field gap? integer
---@field children popup.node[]

---@class (exact) popup.spec.root
---@field row integer
---@field col integer
---@field width integer
---@field height integer
---@field zindex? integer
---@field layout? popup.node

local M = {}

---@param spec? popup.spec.pane
---@return popup.node.pane
function M.pane(spec)
  spec = spec or {}

  return {
    type = 'pane',
    id = spec.id,
    size = spec.size,
    border = spec.border or 'none',
    enter = spec.enter or false,
    win_config = spec.win_config or {},
    content = spec.content,
    buf = spec.buf,
  }
end

---@param spec popup.spec.flex
---@return popup.node.row
function M.row(spec)
  return {
    type = 'row',
    size = spec.size,
    gap = spec.gap or 0,
    children = spec.children,
  }
end

---@param spec popup.spec.flex
---@return popup.node.col
function M.col(spec)
  return {
    type = 'col',
    size = spec.size,
    gap = spec.gap or 0,
    children = spec.children,
  }
end

---@param spec popup.spec.root
---@return popup.node.root
function M.root(spec)
  -- Root is a background covering the layout area, not a bordered content pane.
  -- Pane borders consume allocated space; a root border would expand the outer size.
  return {
    type = 'root',
    row = spec.row,
    col = spec.col,
    width = spec.width,
    height = spec.height,
    border = 'none',
    enter = false,
    win_config = {},
    zindex = spec.zindex or 50,
    layout = spec.layout,
  }
end

return M

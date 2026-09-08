local calc = require('popup.layout.calc')
local rect = require('popup.rect')

-- Resolve a node tree into absolute screen coordinates for the renderer.
local M = {}

local resolve_node

---@param node popup.node.pane
---@param area popup.resolved_rect
---@return popup.config.pane
local function resolve_pane(node, area)
  local border = rect.normalize(node.border)
  local bw = border.width
  return {
    type = 'pane',
    id = node.id,
    rect = {
      row = area.visual_rect.row,
      col = area.visual_rect.col,
      width = area.visual_rect.width - bw.left - bw.right,
      height = area.visual_rect.height - bw.top - bw.bottom,
    },
    border = node.border,
    enter = node.enter,
    win_config = node.win_config,
    content = node.content,
    buf = node.buf,
  }
end

---@param node popup.node.row|popup.node.col
---@param area popup.resolved_rect
---@return popup.config.row|popup.config.col
local function resolve_container(node, area)
  local result = {
    type = node.type,
    rect = {
      row = area.content_rect.row,
      col = area.content_rect.col,
      width = area.content_rect.width,
      height = area.content_rect.height,
    },
    gap = node.gap,
    children = {},
  }

  local child_areas = calc.calculate_children_areas(node, area)

  for index, child in ipairs(node.children) do
    result.children[index] = resolve_node(child, child_areas[index])
  end

  return result
end

---@param node popup.node
---@param area popup.resolved_rect
---@return popup.config.child
resolve_node = function(node, area)
  if node.type == 'pane' then
    return resolve_pane(node, area)
  end

  if node.type == 'row' or node.type == 'col' then
    return resolve_container(node, area)
  end

  error('popup.layout: unknown node type ' .. tostring(node.type --[[@as string]]))
end

---@param node popup.node.root
---@return popup.config.root
function M.resolve(node)
  local area = rect.resolve({
    row = node.row,
    col = node.col,
    width = node.width,
    height = node.height,
    border = node.border,
  })

  local result = {
    type = 'root',
    rect = {
      row = area.visual_rect.row,
      col = area.visual_rect.col,
      width = area.content_rect.width,
      height = area.content_rect.height,
    },
    border = node.border,
    enter = node.enter,
    win_config = node.win_config,
    zindex = node.zindex,
    layout = nil,
  }

  if node.layout then
    result.layout = resolve_node(node.layout, rect.from_content(area.content_rect))
  end

  return result
end

return M

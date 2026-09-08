local rect = require('popup.rect')

-- Layout allocation: distribute available space to children.
local M = {}

---@param node popup.node
---@return popup.size?
local function get_size(node)
  return node.size
end

---@param node popup.node
---@return integer
local function get_flex(node)
  local size = get_size(node)
  return size and size.flex or 1
end

---@param node popup.node
---@return popup.border
local function get_border(node)
  return node.border or 'none'
end

---@param node popup.node
---@return popup.border_info
local function get_border_info(node)
  return rect.normalize(get_border(node))
end

---@param node popup.node.row|popup.node.col
---@param area popup.resolved_rect
---@return popup.resolved_rect[]
function M.calculate_children_areas(node, area)
  local horizontal = node.type == 'row'
  local parent = area.content_rect
  local available = horizontal and parent.width or parent.height
  local gap_total = node.gap * math.max(#node.children - 1, 0)
  local fixed_visual = 0
  local flex_border_total = 0
  local flex_total = 0
  local flex_count = 0
  local meta = {}

  for index, child in ipairs(node.children) do
    local size = get_size(child)
    local border = get_border_info(child)
    local border_main = horizontal and border.width.left + border.width.right
      or border.width.top + border.width.bottom

    if size and size.fixed then
      meta[index] = {
        fixed = true,
        content = size.fixed,
        visual = size.fixed + border_main,
        border = border,
      }
      fixed_visual = fixed_visual + size.fixed + border_main
    else
      local flex = get_flex(child)
      meta[index] = {
        fixed = false,
        flex = flex,
        border = border,
        border_main = border_main,
      }
      flex_total = flex_total + flex
      flex_border_total = flex_border_total + border_main
      flex_count = flex_count + 1
    end
  end

  local flex_content = available - gap_total - fixed_visual - flex_border_total

  assert(flex_content >= 0, 'popup.layout: children exceed parent content area')

  local cursor = horizontal and parent.col or parent.row
  local allocated = 0
  local seen_flex = 0
  local result = {}

  for index, child in ipairs(node.children) do
    local item = meta[index]
    local content_main

    if item.fixed then
      content_main = item.content
    else
      seen_flex = seen_flex + 1

      if seen_flex == flex_count then
        content_main = flex_content - allocated
      else
        content_main = math.floor(flex_content * item.flex / flex_total)
      end

      allocated = allocated + content_main
    end

    local bw = item.border.width
    local content_width
    local content_height

    if horizontal then
      content_width = content_main
      content_height = parent.height - bw.top - bw.bottom
    else
      content_width = parent.width - bw.left - bw.right
      content_height = content_main
    end

    assert(
      content_width >= 0 and content_height >= 0,
      'popup.layout: child border exceeds allocated area'
    )

    result[index] = rect.resolve({
      row = horizontal and parent.row or cursor,
      col = horizontal and cursor or parent.col,
      width = content_width,
      height = content_height,
      border = get_border(child),
    })

    local visual_main = horizontal and result[index].visual_rect.width
      or result[index].visual_rect.height

    cursor = cursor + visual_main + node.gap
  end

  return result
end

return M

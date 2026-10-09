local M = {}

---Place an outer rectangle below an anchor, or above when more room is needed.
---Coordinates are zero-based cells. Viewport dimensions must be positive.
---If the viewport cannot fit min_height, staying inside it takes precedence.
---@param size { width: integer, height: integer, min_height?: integer }
---@param anchor { row: integer, col: integer }
---@param viewport { width: integer, height: integer }
---@return { row: integer, col: integer, width: integer, height: integer }
function M.below_or_above(size, anchor, viewport)
  local row = math.max(0, math.min(anchor.row, viewport.height - 1))
  local above = row
  local below = viewport.height - row - 1
  local space = below
  local place_above = size.height > below and above > below
  if place_above then
    space = above
  end

  local height = math.max(size.min_height or 1, math.min(size.height, space))
  height = math.min(height, viewport.height)
  local width = math.min(size.width, viewport.width)
  local top = row + 1
  if place_above then
    top = row - height
  end

  return {
    row = math.max(0, math.min(top, viewport.height - height)),
    col = math.max(0, math.min(anchor.col, viewport.width - width)),
    width = width,
    height = height,
  }
end

return M

-- Border and rectangle utilities for popup layout resolution.

local BUILTIN = {
  single = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
  double = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' },
  rounded = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  solid = { '█', '▀', '█', '▐', '█', '▄', '█', '▌' },
  shadow = { '', '', '', '', '', '', '', '' },
  none = { '', '', '', '', '', '', '', '' },
}

local M = {}

---@param char string
---@return boolean
local function empty_char(char)
  return char == ''
end

---@param chars string[]
---@return popup.border_info
local function get_border_info(chars)
  return {
    chars = chars,
    width = {
      top = empty_char(chars[2]) and 0 or 1,
      right = empty_char(chars[4]) and 0 or 1,
      bottom = empty_char(chars[6]) and 0 or 1,
      left = empty_char(chars[8]) and 0 or 1,
    },
  }
end

---@param border popup.border
---@return popup.border_info
function M.normalize(border)
  local chars

  if type(border) == 'string' then
    chars = BUILTIN[border]

    if not chars then
      error('popup.rect: unknown border ' .. border)
    end
  elseif type(border) == 'table' then
    if #border ~= 8 then
      error('popup.rect: custom border requires 8 chars')
    end

    chars = border
  else
    error('popup.rect: invalid border type')
  end

  return get_border_info(chars)
end

---@param cfg { row: integer, col: integer, width: integer, height: integer, border?: popup.border }
---@return popup.resolved_rect
function M.resolve(cfg)
  local border = M.normalize(cfg.border or 'none')
  local width = border.width
  local rect = {
    row = cfg.row,
    col = cfg.col,
    width = cfg.width,
    height = cfg.height,
  }

  return {
    visual_rect = {
      row = rect.row,
      col = rect.col,
      width = rect.width + width.left + width.right,
      height = rect.height + width.top + width.bottom,
    },
    content_rect = {
      row = rect.row + width.top,
      col = rect.col + width.left,
      width = rect.width,
      height = rect.height,
    },
    border = border,
  }
end

---@param rect popup.rect
---@return popup.resolved_rect
function M.from_content(rect)
  return {
    visual_rect = rect,
    content_rect = rect,
    border = M.normalize('none'),
  }
end

return M

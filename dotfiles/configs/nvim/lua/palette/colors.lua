local M = {}

---@param color palette.HexColor
---@return palette.Rgb
local function rgb(color)
  return {
    tonumber(color:sub(2, 3), 16),
    tonumber(color:sub(4, 5), 16),
    tonumber(color:sub(6, 7), 16),
  }
end

---@param color palette.HexColor
---@return number
local function relative_luminance(color)
  local channels = rgb(color)

  for index, channel in ipairs(channels) do
    local normalized = channel / 255
    channels[index] = normalized <= 0.04045 and normalized / 12.92
      or ((normalized + 0.055) / 1.055) ^ 2.4
  end

  return 0.2126 * channels[1] + 0.7152 * channels[2] + 0.0722 * channels[3]
end

---@param left palette.HexColor
---@param right palette.HexColor
---@return number
local function contrast_ratio(left, right)
  local left_luminance = relative_luminance(left)
  local right_luminance = relative_luminance(right)
  local lighter = math.max(left_luminance, right_luminance)
  local darker = math.min(left_luminance, right_luminance)
  return (lighter + 0.05) / (darker + 0.05)
end

---@param background palette.HexColor
---@param first palette.HexColor
---@param second palette.HexColor
---@return palette.HexColor
function M.most_contrasting(background, first, second)
  return contrast_ratio(background, first) >= contrast_ratio(background, second) and first or second
end

---@param foreground palette.HexColor
---@param alpha number
---@param background palette.HexColor
---@return palette.HexColor
function M.blend(foreground, alpha, background)
  local fg = rgb(foreground)
  local bg = rgb(background)

  local function channel(index)
    return math.floor(alpha * fg[index] + (1 - alpha) * bg[index] + 0.5)
  end

  return string.format('#%02x%02x%02x', channel(1), channel(2), channel(3))
end

---@param theme palette.PaletteTheme
---@return palette.SemanticPalette
function M.semantic(theme)
  local base = theme.palette

  return {
    id = theme.id,
    name = theme.name,
    variant = theme.variant,
    bgDeep = base.base10,
    bg = base.base00,
    bgHigher = base.base01,
    bgHighest = base.base02,
    fgGhost = base.base03,
    fgDim = base.base04,
    fg = base.base05,
    fgBright = base.base06,
    fgMax = base.base07,
    red = base.base08,
    orange = base.base09,
    yellow = base.base0A,
    green = base.base0B,
    cyan = base.base0C,
    blue = base.base0D,
    purple = base.base0E,
    brown = base.base0F,
    redBright = base.base12,
    yellowBright = base.base13,
    greenBright = base.base14,
    cyanBright = base.base15,
    blueBright = base.base16,
    purpleBright = base.base17,
  }
end

return M

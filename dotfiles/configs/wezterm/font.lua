local wezterm = require('wezterm')

local M = {}

local MAIN_FONT = 'JetBrainsMono Nerd Font'
-- WezTerm sees italic text, not application-level comment semantics.
local ITALIC_FONT = 'FiraCode Nerd Font'
local FONT_LINE_HEIGHT = 1.25

local MACOS_FONT_SIZE = 12
local WINDOWS_FONT_SIZE = 10
local UNIX_FONT_SIZE = 12

local MACOS_FALLBACK_FONTS = { 'PingFang SC', 'Apple Color Emoji', 'Symbols Nerd Font Mono' }
local WINDOWS_FALLBACK_FONTS = { 'Microsoft YaHei', 'Segoe UI Emoji', 'Symbols Nerd Font Mono' }
local UNIX_FALLBACK_FONTS = { 'WenQuanYi Micro Hei', 'Symbols Nerd Font Mono' }

local function platform_settings()
  if wezterm.target_triple:find('apple%-darwin$') then
    return MACOS_FONT_SIZE, MACOS_FALLBACK_FONTS
  end
  if wezterm.target_triple:find('windows') then
    return WINDOWS_FONT_SIZE, WINDOWS_FALLBACK_FONTS
  end
  return UNIX_FONT_SIZE, UNIX_FALLBACK_FONTS
end

local function font_with_fallback(family, fallback, weight, italic)
  local candidates = {
    { family = family, weight = weight, italic = italic },
  }
  for _, fallbackFamily in ipairs(fallback) do
    table.insert(candidates, fallbackFamily)
  end
  return wezterm.font_with_fallback(candidates)
end

function M.setup(config)
  local fontSize, fallback = platform_settings()
  config.font = font_with_fallback(MAIN_FONT, fallback, 'Regular', false)
  config.font_size = fontSize
  config.line_height = FONT_LINE_HEIGHT
  config.font_rules = {
    {
      intensity = 'Bold',
      italic = false,
      font = font_with_fallback(MAIN_FONT, fallback, 'Bold', false),
    },
    {
      intensity = 'Normal',
      italic = true,
      font = font_with_fallback(ITALIC_FONT, fallback, 'Regular', true),
    },
    {
      intensity = 'Bold',
      italic = true,
      font = font_with_fallback(ITALIC_FONT, fallback, 'Bold', true),
    },
    {
      intensity = 'Half',
      italic = false,
      font = font_with_fallback(MAIN_FONT, fallback, 'Regular', false),
    },
    {
      intensity = 'Half',
      italic = true,
      font = font_with_fallback(ITALIC_FONT, fallback, 'Regular', true),
    },
  }
end

return M

local M = {}

---Font size for the integrated title and fancy tab bar.
local TITLE_BAR_FONT_SIZE = 14

---Create colors for each tab bar state.
---@param palette Base24Palette
---@return WezTermTabBarColors
local function create_tab_bar_colors(palette)
  return {
    background = palette.base01,
    active_tab = {
      bg_color = palette.base00,
      fg_color = palette.base05,
    },
    inactive_tab = {
      bg_color = palette.base01,
      fg_color = palette.base04,
    },
    inactive_tab_hover = {
      bg_color = palette.base00,
      fg_color = palette.base05,
    },
    new_tab = {
      bg_color = palette.base01,
      fg_color = palette.base04,
    },
    new_tab_hover = {
      bg_color = palette.base01,
      fg_color = palette.base05,
    },
    inactive_tab_edge = palette.base03,
  }
end

---Create terminal and tab bar colors.
---@param palette Base24Palette
---@return WezTermColors
local function create_colors(palette)
  return {
    foreground = palette.base05,
    background = palette.base00,
    cursor_bg = palette.base05,
    cursor_fg = palette.base00,
    cursor_border = palette.base05,
    selection_bg = palette.base02,
    selection_fg = palette.base05,
    ansi = {
      palette.base00,
      palette.base08,
      palette.base0B,
      palette.base0A,
      palette.base0D,
      palette.base0E,
      palette.base0C,
      palette.base05,
    },
    brights = {
      palette.base03,
      palette.base12,
      palette.base14,
      palette.base13,
      palette.base16,
      palette.base17,
      palette.base15,
      palette.base07,
    },
    tab_bar = create_tab_bar_colors(palette),
  }
end

---Create window frame colors for the fancy tab bar.
---@param palette Base24Palette
---@return WezTermWindowFrame
local function create_window_frame(palette)
  return {
    font_size = TITLE_BAR_FONT_SIZE,
    active_titlebar_bg = palette.base01,
    inactive_titlebar_bg = palette.base01,
    active_titlebar_fg = palette.base05,
    inactive_titlebar_fg = palette.base04,
    active_titlebar_border_bottom = palette.base02,
    inactive_titlebar_border_bottom = palette.base02,
    button_bg = palette.base01,
    button_fg = palette.base04,
    button_hover_bg = palette.base01,
    button_hover_fg = palette.base05,
  }
end

---Apply a Base24 palette to all WezTerm colors.
---@param config table
---@param palette Base24Palette
function M.apply(config, palette)
  config.colors = create_colors(palette)
  config.window_frame = create_window_frame(palette)
end

return M

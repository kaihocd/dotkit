local font = require('font')
local keymapping = require('keymaps')
local palette = require('palette')
local tab = require('tab-bar')
local theme = require('theme')
local wezterm = require('wezterm')

---Use WebGPU for accelerated rendering.
local FRONT_END = 'WebGpu'

---Status refresh and Palette polling interval in milliseconds.
local STATUS_UPDATE_INTERVAL_MS = 250

---Show integrated title-bar buttons and resize borders.
local WINDOW_DECORATIONS = 'INTEGRATED_BUTTONS|RESIZE'

---Align the terminal grid within the window.
local WINDOW_CONTENT_ALIGNMENT = {
  horizontal = 'Center',
  vertical = 'Center',
}

---Set space between terminal content and window edges.
local WINDOW_PADDING = {
  left = '0.5cell',
  right = '0.5cell',
  top = 0,
  bottom = 0,
}

---Set foreground text hsb
local FOREGROUND_TEXT_HSB = {
  hue = 1.0,
  saturation = 1.0,
  brightness = 1.25,
}

local config = wezterm.config_builder()

font.setup(config)
keymapping.apply(config)
local active_palette = palette.current()
if active_palette then
  theme.apply(config, active_palette)
end
tab.setup(config)

config.front_end = FRONT_END
config.automatically_reload_config = true
config.status_update_interval = STATUS_UPDATE_INTERVAL_MS
config.adjust_window_size_when_changing_font_size = false
config.show_close_tab_button_in_tabs = true
config.window_decorations = WINDOW_DECORATIONS
config.window_content_alignment = WINDOW_CONTENT_ALIGNMENT
config.window_padding = WINDOW_PADDING
config.foreground_text_hsb = FOREGROUND_TEXT_HSB

return config

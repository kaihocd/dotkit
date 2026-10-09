local theme = require('theme')
local wezterm = require('wezterm')
local xdg = require('xdg')

local M = {}

---Active Palette snapshot relative to XDG State Home.
---Open windows apply changes during the next status refresh.
local ACTIVE_THEME_RELATIVE_PATH = 'palette/active-theme.json'

local state_path = xdg.state_path(ACTIVE_THEME_RELATIVE_PATH)
local last_contents = nil
local last_palette = nil
local applied_windows = {}

local function read_active_palette()
  local file, open_error = io.open(state_path, 'r')
  if not file then
    wezterm.log_error(
      'Failed to read Palette active theme: ' .. state_path .. ': ' .. tostring(open_error)
    )
    return nil
  end

  local contents = file:read('*a')
  file:close()
  if contents == last_contents then
    return last_palette
  end

  local parsed_ok, active_theme = pcall(wezterm.json_parse, contents)
  if not parsed_ok or type(active_theme) ~= 'table' or type(active_theme.palette) ~= 'table' then
    wezterm.log_error('Invalid Palette active theme: ' .. state_path)
    return nil
  end

  last_contents = contents
  last_palette = active_theme.palette
  return last_palette
end

function M.current()
  return read_active_palette()
end

local function apply_to_window(window, palette)
  local overrides = window:get_config_overrides() or {}
  theme.apply(overrides, palette)
  window:set_config_overrides(overrides)
  applied_windows[window:window_id()] = last_contents
end

local function apply_current_to_window(window)
  local palette = read_active_palette()
  if palette and applied_windows[window:window_id()] ~= last_contents then
    apply_to_window(window, palette)
  end
end

wezterm.on('update-status', function(window)
  apply_current_to_window(window)
  window:set_right_status('')
end)

wezterm.on('window-focus-changed', function(window)
  if window:is_focused() then
    apply_current_to_window(window)
  end
end)

return M

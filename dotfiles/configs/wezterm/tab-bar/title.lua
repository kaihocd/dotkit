local keymap = require('tab-bar.keymap')
local wezterm = require('wezterm')

local M = {}

---Minimum tab title width in terminal columns.
local MINIMUM_TAB_WIDTH = 12

---Horizontal padding added to title width, in columns.
local TAB_HORIZONTAL_PADDING = 2

local function directory_name(path)
  if path == wezterm.home_dir then
    return '~'
  end

  local normalized = path:gsub('/+$', '')
  return normalized:match('([^/]+)$') or '/'
end

local function title_for(tab)
  local pane = tab.active_pane
  local cwd = pane.current_working_dir

  if cwd and cwd.scheme == 'file' then
    return directory_name(cwd.file_path)
  end

  return pane.title
end

local function label_for(tab)
  local key = keymap.label_for(tab.tab_index)

  if key then
    return key .. '. ' .. title_for(tab)
  end

  return title_for(tab)
end

local function align_left(title)
  local width = wezterm.column_width(title)
  local target_width = math.max(MINIMUM_TAB_WIDTH, width + TAB_HORIZONTAL_PADDING)

  return wezterm.pad_right(title, target_width)
end

function M.register()
  wezterm.on('format-tab-title', function(tab)
    return align_left(label_for(tab))
  end)
end

return M

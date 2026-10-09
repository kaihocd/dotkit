local wezterm = require('wezterm')

local M = {}
local act = wezterm.action

---Leader binding and timeout in milliseconds.
local LEADER_KEY = ' '
local LEADER_MODIFIERS = 'SHIFT'
local LEADER_TIMEOUT_MS = 1500

---Number of cells changed by each pane resize.
local PANE_RESIZE_STEP = 3

---Idle timeout for continuous pane resizing, in milliseconds.
local PANE_RESIZE_TIMEOUT_MS = 1000

---Percentage of the current pane given to a new pane.
local SPLIT_PERCENT = 50

---Map Vim direction keys to WezTerm pane directions.
local DIRECTION_KEYS = {
  { key = 'h', direction = 'Left' },
  { key = 'j', direction = 'Down' },
  { key = 'k', direction = 'Up' },
  { key = 'l', direction = 'Right' },
}

local function map(keys, key, mods, action)
  table.insert(keys, {
    key = key,
    mods = mods,
    action = action,
  })
end

-- Let macOS Command+direction trigger Neovim's portable Alt+direction mappings.
local function apply_macos_key_adapters(keys)
  if wezterm.target_triple:find('apple%-darwin$') then
    for _, binding in ipairs(DIRECTION_KEYS) do
      map(keys, binding.key, 'SUPER', act.SendKey({ key = binding.key, mods = 'ALT' }))
    end
  end
end

-- Bind the shared direction keys to pane focus and continuous pane resizing.
local function apply_pane_keys(keys)
  for _, binding in ipairs(DIRECTION_KEYS) do
    map(keys, binding.key, 'LEADER', act.ActivatePaneDirection(binding.direction))
    map(
      keys,
      binding.key:upper(),
      'LEADER|SHIFT',
      act.Multiple({
        act.AdjustPaneSize({ binding.direction, PANE_RESIZE_STEP }),
        act.ActivateKeyTable({
          name = 'resize_pane',
          one_shot = false,
          timeout_milliseconds = PANE_RESIZE_TIMEOUT_MS,
          until_unknown = true,
        }),
      })
    )
  end
end

-- Build the temporary key table used for repeated pane resizing.
local function resize_pane_key_table()
  local keys = {}

  for _, binding in ipairs(DIRECTION_KEYS) do
    map(
      keys,
      binding.key:upper(),
      'SHIFT',
      act.AdjustPaneSize({ binding.direction, PANE_RESIZE_STEP })
    )
  end

  map(keys, 'Escape', nil, act.PopKeyTable)
  return keys
end

-- On macOS keep native Cmd font shortcuts, without the duplicate Ctrl bindings.
local function apply_font_keys(config)
  if wezterm.target_triple:find('apple%-darwin$') then
    for _, mods in ipairs({ 'CTRL', 'SHIFT|CTRL' }) do
      for _, key in ipairs({ '=', '+', '-', '_', '0', ')' }) do
        map(config.keys, key, mods, act.DisableDefaultAssignment)
      end
    end
  end
end

function M.apply(config)
  config.leader = {
    key = LEADER_KEY,
    mods = LEADER_MODIFIERS,
    timeout_milliseconds = LEADER_TIMEOUT_MS,
  }

  config.keys = config.keys or {}
  config.key_tables = config.key_tables or {}
  config.key_tables.resize_pane = resize_pane_key_table()

  -- stylua: ignore start
  map(config.keys, 'y', 'LEADER', act.ActivateCopyMode)
  map(config.keys, 'f', 'LEADER', act.Search({ CaseSensitiveString = '' }))
  map(config.keys, 'c', 'LEADER', act.CloseCurrentPane({ confirm = true }))
  map(config.keys, 'v', 'LEADER', act.SplitPane({ direction = 'Right', size = { Percent = SPLIT_PERCENT } }))
  map(config.keys, 's', 'LEADER', act.SplitPane({ direction = 'Down', size = { Percent = SPLIT_PERCENT } }))
  map(config.keys, 'z', 'LEADER', act.TogglePaneZoomState)
  -- stylua: ignore end

  apply_font_keys(config)
  apply_macos_key_adapters(config.keys)
  apply_pane_keys(config.keys)
end

return M

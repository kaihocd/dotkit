local wezterm = require('wezterm')

local M = {}

---Leader keys by tab index, also used as title prefixes.
---The list supports shortcuts for up to 20 tabs.
local TAB_KEYS = {
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '0',
  '!',
  '@',
  '#',
  '$',
  '%',
  '^',
  '&',
  '*',
  '(',
  ')',
}

function M.label_for(tab_index)
  return TAB_KEYS[tab_index + 1]
end

function M.apply(config)
  config.keys = config.keys or {}

  table.insert(config.keys, {
    key = 't',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab('CurrentPaneDomain'),
  })
  table.insert(config.keys, {
    key = '[',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(-1),
  })
  table.insert(config.keys, {
    key = ']',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(1),
  })
  table.insert(config.keys, {
    key = 'LeftArrow',
    mods = 'LEADER',
    action = wezterm.action.MoveTabRelative(-1),
  })
  table.insert(config.keys, {
    key = 'RightArrow',
    mods = 'LEADER',
    action = wezterm.action.MoveTabRelative(1),
  })

  for tab_index, key in ipairs(TAB_KEYS) do
    table.insert(config.keys, {
      key = key,
      mods = 'LEADER',
      action = wezterm.action.ActivateTab(tab_index - 1),
    })
  end
end

return M

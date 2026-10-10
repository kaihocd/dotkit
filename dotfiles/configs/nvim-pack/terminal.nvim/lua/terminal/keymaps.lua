-- Buffer-local keymaps for the terminal plugin.
local config = require('terminal.config')
local M = {}

-- Parse a keymap value into mode and action.
-- Default mode is 'n' for both list and term buffers.
-- Action functions receive the terminal API as their first argument.
---@param value function|false|{ mode: string|string[], action: fun(terminal: table)|false }
---@return string|string[] mode
---@return fun(terminal: table)|false action
local function parse_keymap(value)
  if type(value) == 'table' then
    return value.mode, value.action
  end
  return 'n', value
end

-- Setup keymaps for the left list pane.
---@param buf integer
---@param terminal table
function M.setup_list(buf, terminal)
  for key, value in pairs(config.get().keymaps.list) do
    local mode, action = parse_keymap(value)
    if action == false then
      vim.keymap.set(mode, key, '<Nop>', { buffer = buf, nowait = true })
    else
      vim.keymap.set(mode, key, function()
        action(terminal)
      end, { buffer = buf, nowait = true })
    end
  end
end

-- Setup keymaps for the right terminal pane.
---@param buf integer
---@param terminal table
function M.setup_term(buf, terminal)
  for key, value in pairs(config.get().keymaps.term) do
    local mode, action = parse_keymap(value)
    if action == false then
      vim.keymap.set(mode, key, '<Nop>', { buffer = buf, nowait = true })
    else
      vim.keymap.set(mode, key, function()
        action(terminal)
      end, { buffer = buf, nowait = true })
    end
  end
end

return M

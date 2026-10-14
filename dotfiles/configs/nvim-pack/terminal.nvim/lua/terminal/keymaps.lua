-- Buffer-local mappings owned by the terminal UI.
local config = require('terminal.config')
local state = require('terminal.state')
local M = {}
local installed = {}

local function clear(buf)
  for _, mapping in ipairs(installed[buf] or {}) do
    for _, current in ipairs(vim.api.nvim_buf_get_keymap(buf, mapping.mode)) do
      if current.callback == mapping.callback then
        vim.keymap.del(mapping.mode, current.lhs, { buffer = buf })
      end
    end
  end
  if not installed[buf] then
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = buf,
      once = true,
      callback = function()
        installed[buf] = nil
      end,
    })
  end
  installed[buf] = {}
end

local function setup(buf, terminal, mappings)
  clear(buf)
  for key, value in pairs(mappings) do
    local mode = type(value) == 'table' and value.mode or 'n'
    local action = value
    if type(value) == 'table' then
      action = value.action
    end
    -- A unique callback also identifies disabled mappings without relying on RHS text.
    local callback = function()
      if action ~= false then
        action(terminal)
      end
    end
    vim.keymap.set(mode, key, callback, { buffer = buf, nowait = true })
    for _, item in ipairs(type(mode) == 'table' and mode or { mode }) do
      table.insert(installed[buf], { mode = item, callback = callback })
    end
  end
end

---@param buf integer
---@param terminal table
function M.setup_list(buf, terminal)
  setup(buf, terminal, assert(state.settings).keymaps.list)
end

---@param buf integer
---@param terminal table
function M.setup_term(buf, terminal)
  setup(buf, terminal, (state.settings or config.get()).keymaps.term)
end

return M

local commands = require('pack.commands')
local loader = require('pack.loader')
local spec = require('pack.spec')
local sync = require('pack.sync')

local M = {}
local state = spec.build({})

---@param user_specs? pack.UserSpec[]
function M.setup(user_specs)
  state = spec.build(user_specs)
  commands.setup(M, state)
  loader.setup(state)
end

---@return pack.Status
function M.status()
  return sync.status(state)
end

---@param names? string[]
function M.sync(names)
  sync.sync(state, names)
end

---@param names? string[]
function M.build(names)
  sync.build(state, names)
end

---@param apply? boolean
---@return table
function M.clean(apply)
  return sync.clean(state, apply == true)
end

return M

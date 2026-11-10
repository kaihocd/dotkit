local check = require('cli-cmd.guard')('cli-cmd.context')

---Snapshot one invocation. argv is already parsed; no shell expansion occurs here.
---@class cli-cmd.Context
---@field executable string
---@field argv string[] Arguments excluding the executable.
---@field raw_input string Original arguments after the user command name.
---@field cwd string Explicit execution directory.
---@field env? table<string, string> Per-invocation environment overrides.
---@field route_key? string Supplied by the CLI adapter, never inferred from argv[1].

local M = {}

local function string_value(value, field, allow_empty)
  local message = 'invalid ' .. field
  check(type(value) == 'string', message)
  check(not value:find('\0', 1, true) and (allow_empty or value ~= ''), message)
end

---@param input cli-cmd.Context
---@return cli-cmd.Context
function M.new(input)
  check(type(input) == 'table', 'invalid input')
  string_value(input.executable, 'executable')
  string_value(input.raw_input, 'raw_input', true)
  string_value(input.cwd, 'cwd')
  check(type(input.argv) == 'table' and vim.islist(input.argv), 'invalid argv')
  local argv = {}
  for i, arg in ipairs(input.argv) do
    string_value(arg, 'argv[' .. i .. ']', true)
    argv[i] = arg
  end
  local env
  if input.env ~= nil then
    check(type(input.env) == 'table', 'invalid env')
    env = {}
    for key, value in pairs(input.env) do
      string_value(key, 'env key')
      check(not key:find('=', 1, true), 'invalid env key')
      string_value(value, 'env value', true)
      env[key] = value
    end
  end
  if input.route_key ~= nil then
    string_value(input.route_key, 'route_key')
  end
  return {
    executable = input.executable,
    argv = argv,
    raw_input = input.raw_input,
    cwd = input.cwd,
    env = env,
    route_key = input.route_key,
  }
end

return M

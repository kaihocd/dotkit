---Root module: install a CLI as a Neovim command.
---
---Two ways in, one installer behind both:
---
---```lua
---require('cli-cmd').install('git', { alias = 'G' })  -- a built-in tool
---require('cli-cmd').define('mine', { executable = 'mine' })  -- your own
---```
---
---A built-in tool is a directory under `lua/cli-cmd/tools/` whose `init.lua`
---returns the spec `cli-cmd.tool` validates. Installing one adds or overrides
---what a caller has an opinion about; nothing else about the tool is spelled out
---twice.
local Installer = require('cli-cmd.install')
local check = require('cli-cmd.guard')('cli-cmd')

local M = {}

---Load the spec a built-in tool declares.
---
---Existence is decided by the file, not by catching a `require` failure, so a
---tool whose module is genuinely broken reports its own error instead of
---pretending to be missing.
---@param name string
---@return cli-cmd.ToolSpec
local function builtin(name)
  check(
    type(name) == 'string' and name:match('^[%a_][%w_%-]*$') ~= nil,
    'invalid tool name: ' .. tostring(name)
  )
  local found = vim.api.nvim_get_runtime_file('lua/cli-cmd/tools/' .. name .. '/init.lua', false)
  check(#found > 0, 'no built-in tool: ' .. name)
  return require('cli-cmd.tools.' .. name)
end

---Install a built-in tool under the names it declares.
---
---With no options this installs the tool's default command: for Git that is
---`:Git`, running Git in the current directory, editing commit messages in this
---Neovim and completing from Git's own output.
---@param name string Tool directory under `lua/cli-cmd/tools/`.
---@param opts? cli-cmd.ToolOptions What the caller overrides.
---@return cli-cmd.Tool
function M.install(name, opts)
  check(opts == nil or type(opts) == 'table', 'options must be a table')
  return Installer.install(vim.tbl_extend('force', builtin(name), opts or {}))
end

---Install a tool that does not live in this repository.
---
---The spec is the whole description; `name` is the identity the tool installs
---under, so re-installing it replaces the previous one.
---@param name string
---@param spec cli-cmd.ToolOptions
---@return cli-cmd.Tool
function M.define(name, spec)
  check(type(name) == 'string' and name ~= '', 'name must be a non-empty string')
  check(type(spec) == 'table', 'spec is required')
  return Installer.install(vim.tbl_extend('force', spec, { name = name }))
end

return M

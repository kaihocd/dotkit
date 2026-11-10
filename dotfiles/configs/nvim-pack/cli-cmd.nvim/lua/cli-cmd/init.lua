---Root module: install a CLI tool that ships no preset of its own.
---
---Git has one (`cli-cmd.git`). Everything else goes through `define`, which takes
---the spec `cli-cmd.tool` validates and adds the only thing a bare tool needs: an
---executable to run.
local Commands = require('cli-cmd.commands')
local check = require('cli-cmd.guard')('cli-cmd')

local M = {}

---Install `name` as a Neovim user command.
---@param name string Tool identity; the default command name derives from it.
---@param spec cli-cmd.ToolSpec
---@return cli-cmd.Tool
function M.define(name, spec)
  check(type(name) == 'string' and name ~= '', 'name must be a non-empty string')
  check(type(spec) == 'table', 'spec is required')
  return Commands.install(vim.tbl_extend('force', spec, { name = name }))
end

return M

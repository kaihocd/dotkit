---The Brew tool: Homebrew as `:Brew`.
---
---A declaration and nothing else: the routing rule lives in `command.lua`, the
---candidate lists in `completion/`, and this file only says which tool it is.
---@type cli-cmd.ToolSpec
return {
  name = 'brew',
  executable = 'brew',
  command = 'Brew',
  route_key = require('cli-cmd.tools.brew.command').route_key,
  completion = function(cwd)
    return require('cli-cmd.tools.brew.completion').new({ cwd = cwd })
  end,
}

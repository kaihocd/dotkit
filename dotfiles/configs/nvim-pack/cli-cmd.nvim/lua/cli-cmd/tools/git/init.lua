---The Git tool: its whole declaration, and nothing else.
---
---What makes Git different from another tool lives in this directory and goes no
---further: the argv rules that decide whether an invocation needs a terminal
---(`command`), the completion provider that asks Git itself (`completion`), and
---this file, which binds them into the one table `cli-cmd.install` understands.
---
---A caller adds or overrides anything here:
---
---```lua
---require('cli-cmd').install('git', { command = 'G' })
---```
local Command = require('cli-cmd.tools.git.command')

---@type cli-cmd.ToolSpec
return {
  name = 'git',
  executable = 'git',
  command = 'Git',
  editor = true,
  route_key = Command.route_key,
  build = Command.build,
  completion = function(cwd)
    return require('cli-cmd.tools.git.completion').new({ cwd = cwd })
  end,
}

---The Palette tool: `require('cli-cmd').install('palette')` registers `:Palette`.
---
---Palette reads and writes which theme is active and never asks a question, so it
---declares no routes at all: every invocation is unrouted and the fallback runs it
---captured. No `command.lua`, no editor bridge — the declaration and the provider
---that offers theme ids are the whole tool.
---@type cli-cmd.ToolSpec
return {
  name = 'palette',
  executable = 'palette',
  command = 'Palette',
  fallback = 'process',
  completion = function(cwd)
    return require('cli-cmd.tools.palette.completion').new({ cwd = cwd })
  end,
}

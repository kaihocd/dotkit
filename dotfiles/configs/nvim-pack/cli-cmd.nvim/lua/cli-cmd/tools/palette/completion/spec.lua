---What `palette --help` says, kept as data because Palette reports no
---machine-readable contract of its own.
---
---`completion` and `tests/tools/palette/contract.lua` read the same table, and
---the test compares it with the help Palette actually prints, so the copy cannot
---quietly drift from the tool.
local M = {}

---@alias cli-cmd.palette.Argument 'theme' | 'command'

---Every command Palette accepts, with the argument it takes and the options it
---is willing to see.
---@type table<string, {argument?: cli-cmd.palette.Argument, options?: string[]}>
M.commands = {
  list = { options = { '--json' } },
  get = { argument = 'theme', options = { '--json' } },
  set = { argument = 'theme' },
  help = { argument = 'command' },
}

---Command order as the help lists it, which is also the order Tab offers.
M.order = { 'list', 'get', 'set', 'help' }

---`palette help` is a command the parser accepts but `palette --help` does not
---advertise, and `palette help help` is a usage error — so it is the one name its
---own argument list must not contain.
M.help_command = 'help'

---Options Palette accepts before or after a subcommand.
M.global_options = { '-h', '--help' }

return M

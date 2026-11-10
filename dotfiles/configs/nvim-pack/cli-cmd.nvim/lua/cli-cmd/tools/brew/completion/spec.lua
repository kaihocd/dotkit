---What Brew can list about itself, and which command takes which list.
---
---Every candidate a user sees comes from one of these four commands; nothing is
---hand-written except the mapping below, which `tests/tools/brew/completion.lua`
---holds against `brew commands --quiet`.
local M = {}

---The command that answers each list. Costs measured on Homebrew 7: `commands`
---0.6s / 117 lines, `formulae` 0.1s / 8610, `casks` 0.1s / 7742, installed 0.05s.
M.sources = {
  commands = { 'commands', '--quiet' },
  formulae = { 'formulae' },
  installed = { 'list', '--formula' },
  casks = { 'casks' },
}

---Commands whose argument may be any formula Brew knows, installed or not.
M.any_formula = {
  cat = true,
  deps = true,
  edit = true,
  fetch = true,
  formula = true,
  home = true,
  info = true,
  install = true,
  log = true,
  uses = true,
}

---Commands that act on what is already installed.
M.installed_formula = {
  extract = true,
  link = true,
  pin = true,
  postinstall = true,
  reinstall = true,
  services = true,
  uninstall = true,
  unpin = true,
  unlink = true,
  upgrade = true,
}

---Selects casks instead of formulae as the argument list.
M.cask_flag = '--cask'

---Options Brew accepts everywhere. Only the ones it documents in `brew --help`:
---a command's own options are not invented here, they are recognized if typed.
M.global_options = { '-h', '--help' }

return M

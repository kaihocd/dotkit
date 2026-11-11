---Brew's argv rules.
---
---One rule decides the surface: a command that changes what is installed, or that
---opens an editor, gets a terminal — it prints progress for an unbounded time and
---may stop for a password, which a captured pipe cannot answer. Queries run
---captured and are reported.
---
---Brew's options never take a value as a separate word, so reading argv needs no
---dissection: the first word that is not an option is the command.

local M = {}

---Commands that need a keyboard. This is a claim about the installed Homebrew, so
---`tests/tools/brew/install.lua` checks every entry against `brew commands --quiet`.
M.needs_a_terminal = {
  autoremove = true,
  bundle = true,
  cleanup = true,
  create = true,
  edit = true,
  extract = true,
  fetch = true,
  install = true,
  ['install-bundler-gems'] = true,
  link = true,
  migrate = true,
  pin = true,
  postinstall = true,
  reinstall = true,
  services = true,
  tap = true,
  uninstall = true,
  unpin = true,
  unlink = true,
  untap = true,
  update = true,
  upgrade = true,
}

---What an invocation needs from its surface.
---@param argv string[]
---@return 'interactive'|'capture'
function M.route_key(argv)
  for _, word in ipairs(argv) do
    if word:sub(1, 1) ~= '-' then
      return M.needs_a_terminal[word] and 'interactive' or 'capture'
    end
  end
  return 'capture'
end

return M

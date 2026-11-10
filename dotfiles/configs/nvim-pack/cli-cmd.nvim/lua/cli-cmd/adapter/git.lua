local Command = require('cli-cmd.command')
local check = require('cli-cmd.guard')('cli-cmd.git')

local M = {}

local value_options = {
  ['-C'] = true,
  ['--config-env'] = true,
  ['--exec-path'] = true,
  ['--git-dir'] = true,
  ['--namespace'] = true,
  ['--work-tree'] = true,
}

local function takes_value(arg)
  return value_options[arg] or arg == '-c'
end

---Read a complete argv the way Git does: the first bare word is the subcommand,
---and options may appear on either side of it. Everything a route can depend on
---lives in these two answers.
---@param argv string[]
---@return string? subcommand, string[] options
local function dissect(argv)
  check(type(argv) == 'table' and vim.islist(argv), 'argv must be a list')
  local subcommand
  local options = {}
  local index = 1
  while index <= #argv do
    local arg = argv[index]
    check(type(arg) == 'string', 'argv values must be strings')
    if arg == '--' then
      break
    elseif takes_value(arg) then
      check(index < #argv, 'missing value for ' .. arg)
      options[#options + 1] = arg
      index = index + 2
    elseif arg:sub(1, 2) == '--' and not arg:find('=', 1, true) then
      if arg == '--config' then
        check(index < #argv, 'missing value for ' .. arg)
        index = index + 2
      else
        options[#options + 1] = arg
        index = index + 1
      end
    elseif arg:sub(1, 1) == '-' then
      options[#options + 1] = arg
      index = index + 1
    else
      subcommand = subcommand or arg
      index = index + 1
    end
  end
  return subcommand, options
end

---The subcommand an argv names, or nil when it names none. Identity, not policy:
---completion asks this to know which vocabulary applies.
---@param argv string[]
---@return string?
function M.subcommand(argv)
  return (dissect(argv))
end

---Options that turn a subcommand into a conversation: patch mode, Git's own
---interactive menus, the pager, and man pages.
local conversational = {
  ['-p'] = true,
  ['--patch'] = true,
  ['-i'] = true,
  ['--interactive'] = true,
  ['--paginate'] = true,
  ['--help'] = true,
}

---Subcommands whose whole point is a human at the keyboard.
local keyboard_only = {
  bisect = true,
  help = true,
  mergetool = true,
}

---Subcommands that can stop and wait for a password, which no pipe can answer.
local may_ask_for_a_password = {
  clone = true,
  fetch = true,
  pull = true,
  push = true,
  submodule = true,
  ['ls-remote'] = true,
}

---What a complete argv needs from its output surface.
---
---`interactive` means the child must talk to a human — it pages, prompts, or
---holds the keyboard — so it gets a real terminal. `capture` means it runs
---unattended and the framework reports the result. The answer belongs to the
---invocation rather than to the subcommand: `add .` is quiet while `add -p` asks
---questions, and only argv tells them apart.
---@param argv string[]
---@return 'interactive'|'capture'
function M.route_key(argv)
  local subcommand, options = dissect(argv)
  for _, option in ipairs(options) do
    if conversational[option] then
      return 'interactive'
    end
  end
  if subcommand and (keyboard_only[subcommand] or may_ask_for_a_password[subcommand]) then
    return 'interactive'
  end
  return 'capture'
end

---Default route preset: the two surfaces every adapter answers with.
---
---`capture` runs the child without a terminal and reports its output through the
---presenter; `interactive` hands it a real tty. Route values are backend names,
---so a user-supplied backend can take either place.
local default_routes = {
  interactive = 'terminal',
  capture = 'process',
}

---The surface used when an adapter names no known route.
M.default_fallback = 'terminal'

---Return a copy of the default route preset, safe to mutate and extend.
---@return table<string, string>
function M.default_routes()
  return vim.deepcopy(default_routes)
end

---Defaults merged with `opts.routes`, or `opts.routes` alone when
---`opts.replace_routes` is true.
---@param opts table
---@return table<string, string|function>
local function resolve_routes(opts)
  check(opts.routes == nil or type(opts.routes) == 'table', 'routes must be a table')
  check(
    opts.replace_routes == nil or type(opts.replace_routes) == 'boolean',
    'replace_routes must be a boolean'
  )
  local routes = opts.replace_routes == true and {} or vim.deepcopy(default_routes)
  for key, target in pairs(opts.routes or {}) do
    check(type(key) == 'string' and key ~= '', 'route keys must be non-empty strings')
    check(
      (type(target) == 'string' and target ~= '') or type(target) == 'function',
      'route target must be a backend name or a function: ' .. key
    )
    routes[key] = target
  end
  return routes
end

---Build a Git command definition.
---`opts.editor` is an optional `cli-cmd.bridge.editor` instance; when present its
---environment is injected per dispatch so Git asks this Neovim instance to edit
---commit messages and sequences. Git still owns hook and editor ordering.
---@param opts table
function M.new(opts)
  check(type(opts) == 'table', 'options are required')
  check(type(opts.cwd) == 'string' and opts.cwd ~= '', 'cwd is required')
  local command_opts = vim.deepcopy(opts)
  command_opts.executable = command_opts.executable or 'git'
  command_opts.routes = resolve_routes(command_opts)
  command_opts.replace_routes = nil
  command_opts.fallback = command_opts.fallback or M.default_fallback

  local editor = command_opts.editor
  local base_env = command_opts.env
  if editor ~= nil then
    check(
      type(editor) == 'table' and type(editor.env) == 'function',
      'editor must be an editor bridge'
    )
    ---A table is copied, a function is evaluated, and either may yield nothing.
    ---Written out rather than folded into one `and`/`or` chain: when the function
    ---returns nil, the chain would hand the *function* to `deepcopy`.
    local function base_environment()
      if type(base_env) == 'function' then
        return vim.deepcopy(base_env() or {})
      end
      return vim.deepcopy(base_env or {})
    end
    command_opts.env = function()
      local env = base_environment()
      for key, value in pairs(editor:env()) do
        env[key] = value
      end
      return env
    end
  end
  return Command.new(command_opts)
end

return M

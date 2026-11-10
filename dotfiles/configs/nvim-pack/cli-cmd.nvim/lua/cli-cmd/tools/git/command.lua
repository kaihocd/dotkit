---Git's argv rules, and the one place a Git invocation becomes a Command.
---
---Nothing here is Neovim-facing: `route_key` answers what an invocation needs
---from its output surface, and `build` turns the tool's spec into the Command the
---framework runs. Both are declared by `cli-cmd.tools.git`.
local Command = require('cli-cmd.command')
local check = require('cli-cmd.guard')('cli-cmd.tools.git.command')

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

---Build the Command this tool's spec describes.
---
---`parts.editor` is the bridge installation created for the tool; when it exists
---its environment is injected per dispatch, so Git asks this Neovim instance to
---edit commit messages and sequences. Git still owns hook and editor ordering.
---@param spec cli-cmd.ToolSpec
---@param parts cli-cmd.ToolParts
---@return table command
function M.build(spec, parts)
  check(type(spec) == 'table', 'spec is required')
  check(type(parts) == 'table', 'parts are required')
  check(type(parts.cwd) == 'string' and parts.cwd ~= '', 'cwd is required')

  local opts = {
    executable = spec.executable or 'git',
    cwd = parts.cwd,
    routes = resolve_routes(spec),
    fallback = spec.fallback or M.default_fallback,
    backends = spec.backends,
    presenter = parts.presenter,
    terminal_capability = spec.terminal_capability,
    terminal_layout = spec.terminal_layout,
    env = spec.env,
    editor = parts.editor,
  }

  local editor = opts.editor
  local base_env = opts.env
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
    opts.env = function()
      local env = base_environment()
      for key, value in pairs(editor:env()) do
        env[key] = value
      end
      return env
    end
  end
  return Command.new(opts)
end

return M

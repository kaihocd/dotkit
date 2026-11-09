---Installation of a CLI tool as Neovim user commands.
---
---An app is described, not wired. `install` resolves the working directory on
---every invocation, owns the completion cache and the editor bridge, and tears
---the previous instance down before installing a new one under the same name.
---Nothing here knows the word Git: the Git preset lives in `cli.git`.
local check = require('cli.guard')('cli.app')
local Command = require('cli.command')
local Completion = require('cli.completion')

local M = {}

---@alias cli.CommandSpec {argv?: string[], desc?: string}

---@class cli.AppSpec
---@field name string Tool identity; installing the same name replaces the app.
---@field executable? string Required unless `build` is given.
---@field build? fun(spec: cli.AppSpec, assembled: cli.AppParts): table Builds the Command.
---@field commands? table<string, cli.CommandSpec> Defaults to one command named after the tool.
---@field route_key? fun(argv: string[]): string? Handler key for a complete argv.
---@field cwd? string Pinned directory; the current one is used by default.
---@field editor? false|table Editor bridge options; off unless asked for.
---@field completion? fun(cwd: string): fun(query: table): string[]? Provider per directory.
---@field presenter? false|table Defaults to a `vim.notify` presenter.
---@field routes? table<string, string|function>
---@field replace_routes? boolean
---@field fallback? string
---@field backends? table<string, function>
---@field env? table<string, string>|fun(): table<string, string>?
---@field terminal_capability? table
---@field terminal_layout? string

---What `install` resolves before asking the tool to build its Command.
---@class cli.AppParts
---@field cwd string
---@field presenter cli.NotifyPresenter|false|nil
---@field editor cli.EditorBridge?

---@class cli.App
---@field name string
---@field command table
---@field commands string[] Names this app registered.
---@field editor cli.EditorBridge?
---@field presenter cli.NotifyPresenter|false|nil

---Installed apps by name, so a second install can dispose the first.
---@type table<string, cli.App>
local installed = {}

---@param option false|table|nil
---@return cli.NotifyPresenter|false|nil
local function presenter_of(option)
  check(
    option == nil or option == false or type(option) == 'table',
    'presenter must be a presenter, false, or nil'
  )
  if option == false then
    return false
  end
  return option or require('cli.presenter.notify').new()
end

---@param option false|table|nil
---@param cwd string
---@return cli.EditorBridge?
local function editor_of(option, cwd)
  check(
    option == nil or option == false or type(option) == 'table',
    'editor must be a table, false, or nil'
  )
  if option == nil or option == false then
    return nil
  end
  local options = vim.tbl_extend('force', option, { cwd = option.cwd or cwd })
  return require('cli.bridge.editor').new(options)
end

---`brew` becomes `:Brew`, the same way Neovim requires a capital letter.
---@param name string
---@return string
local function command_name(name)
  return (name:gsub('^%l', string.upper))
end

---@param spec cli.AppSpec
---@return table<string, cli.CommandSpec>
local function commands_of(spec)
  local commands = spec.commands or { [command_name(spec.name)] = {} }
  check(type(commands) == 'table' and not vim.islist(commands), 'commands must be a table')
  for name, entry in pairs(commands) do
    check(type(name) == 'string' and name ~= '', 'command names must be non-empty strings')
    check(type(entry) == 'table', 'command entries must be tables: ' .. name)
    check(entry.desc == nil or type(entry.desc) == 'string', 'desc must be a string: ' .. name)
    if entry.argv ~= nil then
      check(vim.islist(entry.argv), 'argv must be a list: ' .. name)
      for _, value in ipairs(entry.argv) do
        check(type(value) == 'string', 'argv values must be strings: ' .. name)
      end
    end
  end
  return commands
end

---Build a Command definition for a tool that needs nothing beyond an executable.
---Tools with their own preset replace this through `spec.build`.
---@param spec cli.AppSpec
---@param parts cli.AppParts
---@return table command
function M.default_build(spec, parts)
  return Command.new({
    executable = spec.executable,
    cwd = parts.cwd,
    routes = spec.routes,
    fallback = spec.fallback,
    backends = spec.backends,
    env = spec.env,
    presenter = parts.presenter,
    terminal_capability = spec.terminal_capability,
    terminal_layout = spec.terminal_layout,
  })
end

---Preset arguments are already typed by the user, so they must reach the
---provider as tokens before whatever is on the command line.
---@param provider fun(query: table): string[]?
---@param prefix string[]
---@return fun(query: table): string[]?
local function prefixed(provider, prefix)
  if #prefix == 0 then
    return provider
  end
  return function(query)
    return provider({
      tokens = vim.list_extend(vim.deepcopy(prefix), query.tokens or {}),
      arglead = query.arglead,
      cmdline = query.cmdline,
    })
  end
end

---One provider per directory, so a completion request in another repository
---never answers with the previous one's refs.
---@param factory fun(cwd: string): fun(query: table): string[]?
---@param prefix string[]
---@return fun(arglead: string, cmdline: string, cursorpos: integer): string[]
local function completion_of(factory, prefix)
  local providers = {}
  local function provider(query)
    local cwd = vim.fn.getcwd()
    if providers[cwd] == nil then
      providers[cwd] = factory(cwd)
      check(type(providers[cwd]) == 'function', 'completion factory must return a provider')
    end
    return providers[cwd](query)
  end
  return Completion.callback(prefixed(provider, prefix))
end

---@param app cli.App
---@param spec cli.AppSpec
---@param entry cli.CommandSpec
---@return fun(command: table)
local function invoke(app, spec, entry)
  return function(command)
    local argv = vim.list_extend(vim.deepcopy(entry.argv or {}), command.fargs)
    local route_key
    if spec.route_key then
      route_key = spec.route_key(argv)
    end
    app.command:dispatch({
      argv = argv,
      raw_input = table.concat(argv, ' '),
      route_key = route_key,
      cwd = spec.cwd or vim.fn.getcwd(),
    })
  end
end

---Release the commands and the editor bridge this name owns. Safe to call for
---a name that was never installed.
---@param name string
function M.dispose(name)
  local app = installed[name]
  if not app then
    return nil
  end
  installed[name] = nil
  for _, command in ipairs(app.commands) do
    pcall(vim.api.nvim_del_user_command, command)
  end
  if app.editor then
    app.editor:dispose()
  end
  return app
end

---Install the commands described by `spec`, replacing an app of the same name.
---@param spec cli.AppSpec
---@return cli.App
function M.install(spec)
  check(type(spec) == 'table', 'spec is required')
  check(type(spec.name) == 'string' and spec.name ~= '', 'name is required')
  check(spec.build == nil or type(spec.build) == 'function', 'build must be a function')
  check(spec.route_key == nil or type(spec.route_key) == 'function', 'route_key must be a function')
  check(spec.cwd == nil or (type(spec.cwd) == 'string' and spec.cwd ~= ''), 'cwd must be a string')
  local build = spec.build or M.default_build
  if spec.build == nil then
    check(type(spec.executable) == 'string' and spec.executable ~= '', 'executable is required')
  end

  local commands = commands_of(spec)
  M.dispose(spec.name)

  local parts = {
    cwd = spec.cwd or vim.fn.getcwd(),
    presenter = presenter_of(spec.presenter),
  }
  parts.editor = editor_of(spec.editor, parts.cwd)
  local app = {
    name = spec.name,
    command = build(spec, parts),
    commands = {},
    editor = parts.editor,
    presenter = parts.presenter,
  }

  -- Registering can fail on a name someone else owns; report it as it happened
  -- instead of leaving half of the declared commands behind.
  local ok, err = pcall(function()
    for name, entry in pairs(commands) do
      local complete
      if spec.completion then
        complete = completion_of(spec.completion, entry.argv or {})
      end
      vim.api.nvim_create_user_command(name, invoke(app, spec, entry), {
        nargs = '*',
        desc = entry.desc,
        complete = complete,
      })
      app.commands[#app.commands + 1] = name
    end
  end)
  if not ok then
    for _, name in ipairs(app.commands) do
      pcall(vim.api.nvim_del_user_command, name)
    end
    if app.editor then
      app.editor:dispose()
    end
    error(err, 0)
  end

  table.sort(app.commands)
  installed[spec.name] = app
  return app
end

return M

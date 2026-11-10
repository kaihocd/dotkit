---Turning a tool description into Neovim user commands.
---
---Everything that leaves a trace happens here: the presenter and the editor
---bridge are created, the Command is built, user commands are registered with
---rollback on failure, completion is cached per directory, and a second install
---under the same name disposes the first. Nothing here knows the word Git: the
---Git preset lives in `cli-cmd.git`.
local Command = require('cli-cmd.command')
local Completion = require('cli-cmd.completion')
local Tool = require('cli-cmd.tool')
local check = require('cli-cmd.guard')('cli-cmd.tool')

local M = {}

---What an installation owns: the Command it built, the names it registered and
---the objects it is responsible for releasing.
---@class cli-cmd.Tool
---@field name string
---@field command table
---@field commands string[] Registered names, the main one first.
---@field editor cli-cmd.EditorBridge?
---@field presenter cli-cmd.OutputPresenter|false|nil

---Installed tools by name, so re-installing a name replaces it instead of
---colliding with it. This is the one module that keeps module-level state: the
---name is the identity a user writes in their config, and it has to outlive the
---call that installed it.
---@type table<string, cli-cmd.Tool>
local installed = {}

---@param option false|table|nil
---@return cli-cmd.OutputPresenter|false|nil
local function presenter_of(option)
  check(
    option == nil or option == false or type(option) == 'table',
    'presenter must be a presenter, false, or nil'
  )
  if option == false then
    return false
  end
  return option or require('cli-cmd.presenter.output').new()
end

---@param option false|table|nil
---@param cwd string
---@return cli-cmd.EditorBridge?
local function editor_of(option, cwd)
  check(
    option == nil or type(option) == 'boolean' or type(option) == 'table',
    'editor must be a table, a boolean, or nil'
  )
  if option == nil or option == false then
    return nil
  end
  local options = type(option) == 'table' and option or {}
  options = vim.tbl_extend('force', options, { cwd = options.cwd or cwd })
  return require('cli-cmd.bridge.editor').new(options)
end

---Build a Command definition for a tool that needs nothing beyond an executable.
---Tools with their own preset replace this through `spec.build`.
---@param spec cli-cmd.ToolSpec
---@param parts cli-cmd.ToolParts
---@return table command
local function default_build(spec, parts)
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

---@param tool cli-cmd.Tool
---@param spec cli-cmd.ToolSpec
---@param entry cli-cmd.CommandSpec
---@return fun(command: table)
local function invoke(tool, spec, entry)
  return function(command)
    local argv = vim.list_extend(vim.deepcopy(entry.argv or {}), command.fargs)
    local route_key
    if spec.route_key then
      route_key = spec.route_key(argv)
    end
    tool.command:dispatch({
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
---@return cli-cmd.Tool?
function M.dispose(name)
  local tool = installed[name]
  if not tool then
    return nil
  end
  installed[name] = nil
  for _, command in ipairs(tool.commands) do
    pcall(vim.api.nvim_del_user_command, command)
  end
  if tool.editor then
    tool.editor:dispose()
  end
  return tool
end

---Install the commands described by `spec`, replacing a tool of the same name.
---@param spec cli-cmd.ToolSpec
---@return cli-cmd.Tool
function M.install(spec)
  Tool.validate(spec)
  local entries, order = Tool.names(spec)
  M.dispose(spec.name)

  local parts = {
    cwd = spec.cwd or vim.fn.getcwd(),
    presenter = presenter_of(spec.presenter),
  }
  parts.editor = editor_of(spec.editor, parts.cwd)
  local tool = {
    name = spec.name,
    command = (spec.build or default_build)(spec, parts),
    commands = {},
    editor = parts.editor,
    presenter = parts.presenter,
  }

  -- The API replaces an existing command without a word, so check first: a name
  -- this tool does not own belongs to someone else and must fail loudly instead
  -- of being taken over silently.
  local ok, err = pcall(function()
    for _, name in ipairs(order) do
      local entry = entries[name]
      check(vim.api.nvim_get_commands({})[name] == nil, 'command already exists: ' .. name)
      local complete
      if spec.completion then
        complete = completion_of(spec.completion, entry.argv or {})
      end
      vim.api.nvim_create_user_command(name, invoke(tool, spec, entry), {
        nargs = '*',
        desc = entry.desc,
        complete = complete,
      })
      tool.commands[#tool.commands + 1] = name
    end
  end)
  if not ok then
    for _, name in ipairs(tool.commands) do
      pcall(vim.api.nvim_del_user_command, name)
    end
    if tool.editor then
      tool.editor:dispose()
    end
    error(err, 0)
  end

  installed[spec.name] = tool
  return tool
end

return M

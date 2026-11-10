---What a user says a tool is.
---
---Only the description lives here: validation, defaults and the names the tool
---answers to. Nothing is created, nothing is started, and no Neovim state is
---touched, so this module can be exercised without installing anything.
local check = require('cli.guard')('cli.tool')

local M = {}

---@alias cli.CommandSpec {argv?: string[], desc?: string}

---What a user describes: everything a tool decides, nothing about identity.
---@class cli.ToolOptions
---@field command? string Name of the main command; defaults to the tool name with a capital letter.
---@field alias? string|string[] Extra names for the same command.
---@field presets? table<string, cli.CommandSpec> Extra commands with fixed leading arguments.
---@field executable? string Required unless `build` is given.
---@field cwd? string Pinned directory; the current one is used by default.
---@field editor? boolean|table `true` uses the bridge defaults; off unless asked for.
---@field completion? false|table|fun(cwd: string): fun(query: table): string[]? Provider per directory.
---@field presenter? false|table Defaults to a `vim.notify` presenter.
---@field routes? table<string, string|function>
---@field replace_routes? boolean
---@field fallback? string
---@field backends? table<string, function>
---@field env? table<string, string>|fun(): table<string, string>?
---@field terminal_capability? table
---@field terminal_layout? string

---A tool under installation: its options plus the identity and the two hooks
---that are a tool's own business rather than a caller's.
---@class cli.ToolSpec : cli.ToolOptions
---@field name string Tool identity; installing the same name replaces the tool.
---@field build? fun(spec: cli.ToolSpec, parts: cli.ToolParts): table Builds the Command.
---@field route_key? fun(argv: string[]): string? Handler key for a complete argv.
---@field completion? fun(cwd: string): fun(query: table): string[]? A preset decides its own provider.

---What installation resolves before asking the tool to build its Command.
---@class cli.ToolParts
---@field cwd string
---@field presenter cli.OutputPresenter|false|nil
---@field editor cli.EditorBridge?

---Options a spec may carry; anything else is a typo, not a feature.
local known = {
  alias = true,
  backends = true,
  build = true,
  command = true,
  completion = true,
  cwd = true,
  editor = true,
  env = true,
  executable = true,
  fallback = true,
  name = true,
  presets = true,
  presenter = true,
  replace_routes = true,
  route_key = true,
  routes = true,
  terminal_capability = true,
  terminal_layout = true,
}

---`brew` becomes `:Brew`, the same way Neovim requires a capital letter.
---@param name string
---@return string
function M.command_name(name)
  return (name:gsub('^%l', string.upper))
end

---Every name the main command answers to: its own name first, then aliases.
---An alias that repeats a name already listed is not an error, only redundant.
---@param spec cli.ToolSpec
---@return string[]
local function names_of(spec)
  local alias = spec.alias
  if type(alias) == 'string' then
    alias = { alias }
  end
  check(
    alias == nil or (type(alias) == 'table' and vim.islist(alias)),
    'alias must be a string or a list'
  )

  local names, seen = {}, {}
  local function add(name)
    check(type(name) == 'string' and name ~= '', 'command names must be non-empty strings')
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  add(spec.command or M.command_name(spec.name))
  for _, name in ipairs(alias or {}) do
    add(name)
  end
  return names
end

---@param name string
---@param entry any
local function check_entry(name, entry)
  check(type(entry) == 'table', 'command entries must be tables: ' .. name)
  check(entry.desc == nil or type(entry.desc) == 'string', 'desc must be a string: ' .. name)
  check(entry.argv == nil or vim.islist(entry.argv), 'argv must be a list: ' .. name)
  for _, value in ipairs(entry.argv or {}) do
    check(type(value) == 'string', 'argv values must be strings: ' .. name)
  end
end

---The main names plus the presets, each with the arguments it starts from, and
---the order to register them in: the main name first, so the recorded names
---read like the spec did.
---@param spec cli.ToolSpec
---@return table<string, cli.CommandSpec> entries, string[] order
function M.names(spec)
  local entries, order = {}, {}
  for _, name in ipairs(names_of(spec)) do
    entries[name] = {}
    order[#order + 1] = name
  end
  check(
    spec.presets == nil or (type(spec.presets) == 'table' and not vim.islist(spec.presets)),
    'presets must be a table'
  )
  local extra = {}
  for name, entry in pairs(spec.presets or {}) do
    check(type(name) == 'string' and name ~= '', 'command names must be non-empty strings')
    check_entry(name, entry)
    if entries[name] == nil then
      extra[#extra + 1] = name
    end
    entries[name] = entry
  end
  table.sort(extra)
  vim.list_extend(order, extra)
  return entries, order
end

---Reject a spec that cannot be installed, before anything is created.
---@param spec cli.ToolSpec
function M.validate(spec)
  check(type(spec) == 'table' and not vim.islist(spec), 'spec must be a table')
  check(type(spec.name) == 'string' and spec.name ~= '', 'name is required')
  for key in pairs(spec) do
    check(known[key], 'unknown option: ' .. tostring(key))
  end
  check(spec.build == nil or type(spec.build) == 'function', 'build must be a function')
  check(spec.route_key == nil or type(spec.route_key) == 'function', 'route_key must be a function')
  check(spec.cwd == nil or (type(spec.cwd) == 'string' and spec.cwd ~= ''), 'cwd must be a string')
  check(
    spec.completion == nil or spec.completion == false or type(spec.completion) == 'function',
    'completion must be a factory (fun(cwd): provider) or false'
  )
  -- A tool that builds its own Command is not required to name an executable;
  -- the default builder is not that lucky.
  if spec.build == nil then
    check(type(spec.executable) == 'string' and spec.executable ~= '', 'executable is required')
  end
end

return M

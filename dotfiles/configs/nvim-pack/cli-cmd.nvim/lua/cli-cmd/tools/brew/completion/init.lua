---Brew completion provider.
---
---Three lists answer everything: Brew's own commands, the formulae it knows, and
---the casks it knows. Each is read once per provider and only when the command line
---actually needs it, so `:Brew <Tab>` costs one `brew commands` and
---`:Brew uninstall <Tab>` costs one `brew list`.
local Spec = require('cli-cmd.tools.brew.completion.spec')
local check = require('cli-cmd.guard')('cli-cmd.tools.brew.completion')

local M = {}
local Provider = {}
Provider.__index = Provider

---Ask Brew for a list. A failure is an empty list: completion must never turn into
---an error message while the user is typing.
---@param argv string[]
---@param cwd? string
---@return string[]
local function run(argv, cwd)
  local ok, process = pcall(vim.system, argv, { cwd = cwd, text = true })
  if not ok then
    return {}
  end
  local finished = process:wait(10000)
  if not finished then
    pcall(function()
      process:kill('sigkill')
    end)
    return {}
  end
  if finished.code ~= 0 then
    return {}
  end
  return vim.split(finished.stdout or '', '\n', { trimempty = true })
end

---@param opts? {cwd?: string, run?: fun(argv: string[], cwd?: string): string[]}
---@return fun(query: table): string[]
function M.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  check(opts.cwd == nil or type(opts.cwd) == 'string', 'cwd must be a string')
  check(opts.run == nil or type(opts.run) == 'function', 'run must be a function')
  local provider = setmetatable({ _cwd = opts.cwd, _run = opts.run or run, _lists = {} }, Provider)
  return function(query)
    return provider:candidates(query)
  end
end

---One list, read at most once per provider.
---@param source string key of `Spec.sources`
---@return string[]
function Provider:_list(source)
  if self._lists[source] == nil then
    local argv = Spec.sources[source]
    check(argv ~= nil, 'unknown source: ' .. tostring(source))
    local ok, lines = pcall(self._run, vim.list_extend({ 'brew' }, argv), self._cwd)
    self._lists[source] = (ok and type(lines) == 'table') and lines or {}
  end
  return self._lists[source]
end

---@param list string[]
---@param value string
---@return boolean
local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

---@param candidates string[]
---@param typed string[]
---@param extra string[]
local function add(candidates, typed, extra)
  local seen = {}
  for _, candidate in ipairs(candidates) do
    seen[candidate] = true
  end
  for _, candidate in ipairs(extra) do
    if not seen[candidate] and not contains(typed, candidate) then
      candidates[#candidates + 1] = candidate
      seen[candidate] = true
    end
  end
end

---The first word that is not an option: Brew's global options come before the
---command they apply to.
---@param tokens string[]
---@return string? command, string[] typed Words already given to that command
local function split(tokens)
  for index, token in ipairs(tokens) do
    if token:sub(1, 1) ~= '-' then
      return token, vim.list_slice(tokens, index + 1)
    end
  end
  return nil, {}
end

---Candidates for the position being typed in; the framework filters by prefix and
---escapes what it inserts, so this only answers "what could go here".
---@param query {tokens?: string[]}
---@return string[]
function Provider:candidates(query)
  local tokens = query.tokens or {}
  local command, typed = split(tokens)

  if command == nil then
    local candidates = {}
    add(candidates, typed, Spec.global_options)
    add(candidates, typed, self:_list('commands'))
    return candidates
  end

  local candidates = {}
  add(candidates, typed, Spec.global_options)
  local wants_cask = contains(tokens, Spec.cask_flag)
  if wants_cask or Spec.installed_formula[command] then
    add(candidates, typed, self:_list(wants_cask and 'casks' or 'installed'))
  elseif Spec.any_formula[command] then
    add(candidates, typed, self:_list('formulae'))
  end
  return candidates
end

return M

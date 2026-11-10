---Palette completion provider.
---
---Two sources decide a candidate list: the contract Palette's own help describes
---(`cli-cmd.tools.palette.completion.spec`) and the catalog Palette itself
---reports (`palette list`). Nothing is hard-coded that the tool can answer.
---
---The catalog costs one process start, so it is read once per provider; the
---installer already keeps one provider per directory.
local Spec = require('cli-cmd.tools.palette.completion.spec')
local check = require('cli-cmd.guard')('cli-cmd.tools.palette.completion')

local M = {}
local Provider = {}
Provider.__index = Provider

---Ask Palette which themes exist. A failure is an empty list: completion must
---never turn into an error message while the user is typing.
---@param cwd? string
---@return string[]
local function catalog(cwd)
  local ok, process = pcall(vim.system, { 'palette', 'list' }, { cwd = cwd, text = true })
  if not ok then
    return {}
  end
  local finished = process:wait(5000)
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

---@param opts? {cwd?: string, list?: fun(cwd?: string): string[]}
---@return fun(query: table): string[] The provider the installer expects.
function M.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  check(opts.cwd == nil or type(opts.cwd) == 'string', 'cwd must be a string')
  check(opts.list == nil or type(opts.list) == 'function', 'list must be a function')
  local provider = setmetatable({ _cwd = opts.cwd, _list = opts.list or catalog }, Provider)
  return function(query)
    return provider:candidates(query)
  end
end

---The catalog, read at most once per provider.
---@return string[]
function Provider:_themes()
  if self._catalog == nil then
    local ok, themes = pcall(self._list, self._cwd)
    self._catalog = (ok and type(themes) == 'table') and themes or {}
  end
  return self._catalog
end

---Commands that may follow `help`. `helped` names itself nowhere: `palette help
---help` is a usage error, and offering it would be a candidate the tool rejects.
---@return string[]
local function documented()
  local names = {}
  for _, name in ipairs(Spec.order) do
    if name ~= Spec.help_command then
      names[#names + 1] = name
    end
  end
  return names
end

---An argument already occupies the position after the command: any token that is
---not an option is that argument, whatever the user meant by it.
---@param tokens string[]
---@return boolean
local function has_argument(tokens)
  for index = 2, #tokens do
    if tokens[index]:sub(1, 1) ~= '-' then
      return true
    end
  end
  return false
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
---@param tokens string[] Already typed words, so nothing is offered twice.
---@param extra string[]
local function add(candidates, tokens, extra)
  local seen = {}
  for _, candidate in ipairs(candidates) do
    seen[candidate] = true
  end
  for _, candidate in ipairs(extra) do
    if not seen[candidate] and not contains(tokens, candidate) then
      candidates[#candidates + 1] = candidate
      seen[candidate] = true
    end
  end
end

---Candidates for the position the user is typing in. The framework filters them
---by prefix and escapes what it inserts, so this only answers "what could go
---here".
---@param query {tokens?: string[], arglead?: string, cmdline?: string}
---@return string[]
function Provider:candidates(query)
  local tokens = query.tokens or {}
  local command = tokens[1]

  if command == nil then
    local candidates = {}
    add(candidates, tokens, Spec.order)
    add(candidates, tokens, Spec.global_options)
    return candidates
  end

  local spec = Spec.commands[command]
  if spec == nil then
    return {}
  end

  -- Only the words after the command are "already typed": `help help` asks for
  -- help about help, so the command name itself is not a duplicate.
  local typed = vim.list_slice(tokens, 2)
  local candidates = {}
  add(candidates, typed, Spec.global_options)
  add(candidates, typed, spec.options or {})
  if spec.argument == 'theme' and not has_argument(tokens) then
    add(candidates, typed, self:_themes())
  elseif spec.argument == 'command' and not has_argument(tokens) then
    add(candidates, typed, documented())
  end
  return candidates
end

return M

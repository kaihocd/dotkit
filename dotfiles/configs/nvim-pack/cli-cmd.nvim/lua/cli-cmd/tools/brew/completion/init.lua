---Brew completion provider.
---
---Three lists answer everything: Brew's own commands, the formulae it knows, and
---the casks it knows. Each is read once per provider and only when the command line
---actually needs it, so `:Brew <Tab>` costs one `brew commands` and
---`:Brew uninstall <Tab>` costs one `brew list`.
local Spec = require('cli-cmd.tools.brew.completion.spec')

local M = {}
local Provider = {}
Provider.__index = Provider

---How long the editor may wait for a list. A warm Brew answers in 0.1–0.9s
---(`commands --quiet` is the slow one); a machine that has never run Brew downloads
---43MB of API data on the first call (2.7s here, as long as the network takes
---anywhere else), so the budget only covers the answers that are already there.
local budget = 1500

---Ask Brew for a list, waiting at most `budget` for the answer.
---
---`nil` means "no answer yet" and `{}` means Brew answered nothing — a cache that
---has never been filled really does print nothing and exit 0. Neither is an error:
---completion must never turn into a message while the user is typing.
---
---The child is not killed when it is too slow. `vim.system().wait()` would do that
---(after waiting twice the timeout it is given), and killing Brew mid-download throws
---away the work that makes the next Tab fast. Left alone, it finishes and fills the
---cache.
---@param argv string[]
---@param cwd? string
---@return string[]?
local function run(argv, cwd)
  local lines
  local ok = pcall(vim.system, argv, { cwd = cwd, text = true }, function(obj)
    lines = obj.code == 0 and vim.split(obj.stdout or '', '\n', { trimempty = true }) or {}
  end)
  if not ok then
    return {}
  end
  vim.wait(budget, function()
    return lines ~= nil
  end, 10)
  return lines
end

---@param opts? {cwd?: string, run?: fun(argv: string[], cwd?: string): string[]?}
---@return fun(query: table): string[]
function M.new(opts)
  opts = opts or {}
  local provider = setmetatable({ _cwd = opts.cwd, _run = opts.run or run, _lists = {} }, Provider)
  return function(query)
    return provider:candidates(query)
  end
end

---One list, read at most once per provider. An answer is remembered; "no answer
---yet" is not, so the next Tab asks again.
---@param source string key of `Spec.sources`
---@return string[]
function Provider:_list(source)
  if self._lists[source] == nil then
    local argv = Spec.sources[source]
    local ok, lines = pcall(self._run, vim.list_extend({ 'brew' }, argv), self._cwd)
    if ok and type(lines) == 'table' then
      self._lists[source] = lines
    end
  end
  return self._lists[source] or {}
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

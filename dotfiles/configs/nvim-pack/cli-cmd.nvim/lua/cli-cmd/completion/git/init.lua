---Git completion provider.
---
---Three inputs decide a candidate list: what the user typed, the vocabulary the
---installed Git reports (`cli-cmd.completion.git.discover`), and the small amount of
---semantics Git does not express (`cli-cmd.completion.git.spec`). Escaping and
---Neovim plumbing live in `cli-cmd.completion`.
local Completion = require('cli-cmd.completion')
local Discover = require('cli-cmd.completion.git.discover')
local Git = require('cli-cmd.adapter.git')
local Spec = require('cli-cmd.completion.git.spec')
local check = require('cli-cmd.guard')('cli-cmd.completion.git')

local M = {}

---Relative path candidates rooted at `base`.
local function paths(prefix, base)
  local ok, matched = pcall(vim.fn.globpath, base, prefix .. '*', false, true)
  if not ok then
    return {}
  end
  local root = base:gsub('/+$', '') .. '/'
  local result = {}
  for _, path in ipairs(matched) do
    local relative = vim.startswith(path, root) and path:sub(#root + 1) or path
    if vim.fn.isdirectory(path) == 1 then
      relative = relative .. '/'
    end
    result[#result + 1] = relative
  end
  return result
end

---Last value of an option inside the token list, or nil.
local function option_value(tokens, name)
  local value
  for index, token in ipairs(tokens) do
    if token == name and tokens[index + 1] then
      value = tokens[index + 1]
    elseif vim.startswith(token, name .. '=') then
      value = token:sub(#name + 2)
    end
  end
  return value
end

local function split_lines(text)
  return vim.split(text, '\n', { trimempty = true })
end

local function unique(list)
  local seen, result = {}, {}
  for _, value in ipairs(list) do
    local trimmed = vim.trim(value)
    if trimmed ~= '' and not seen[trimmed] then
      seen[trimmed] = true
      result[#result + 1] = trimmed
    end
  end
  return result
end

local function starts_with_dash(token)
  return token:sub(1, 1) == '-'
end

---A token that can be an option of its own; `-` and `--` are arguments.
local function option_token(token)
  return starts_with_dash(token) and token ~= '-' and token ~= '--'
end

---Option name without an attached value, for `--author=` or `--author=x`.
local function bare(name)
  return (name:gsub('=.*$', ''))
end

---Default candidate sources, all asked through the discovery runner so that
---timeout, failure, and injection have one implementation. Each source receives
---a working directory and returns candidate strings; `opts.sources` replaces
---what is asked, not how.
local function default_sources(discover)
  local function source(argv, transform)
    return function(cwd)
      local stdout = discover:run(argv, cwd)
      return stdout and transform(stdout) or {}
    end
  end
  return {
    paths = paths,
    refs = source({
      'for-each-ref',
      '--format=%(refname:short)',
      'refs/heads',
      'refs/tags',
      'refs/remotes',
    }, split_lines),
    remotes = source({ 'remote' }, split_lines),
    authors = source({ 'log', '--no-merges', '-n', '500', '--format=%an' }, function(stdout)
      local names = unique(split_lines(stdout))
      table.sort(names)
      return names
    end),
  }
end

---Wrap sources with a short-lived memo so completion never spawns Git twice for
---the same directory within one keystroke burst.
local function memoize(sources, ttl)
  local cache = {}
  local wrapped = {}
  for name, source in pairs(sources) do
    wrapped[name] = function(cwd)
      local key = name .. '\0' .. cwd
      local entry = cache[key]
      local now = vim.loop.hrtime() / 1e6
      if entry and now - entry.at < ttl then
        return entry.value
      end
      local value = source(cwd) or {}
      cache[key] = { at = now, value = value }
      return value
    end
  end
  return wrapped
end

---What one subcommand accepts, as sets instead of scan targets: `values` maps an
---option to the kind of value it takes, `options` holds every name this Git is
---known to accept, `words` are the subwords it reports (`stash` -> `pop`).
---Built once per route rather than rebuilt for every keystroke.
local function build_knowledge(route, vocabulary)
  local values = {}
  for name, kind in pairs(Spec.value_kinds) do
    values[name] = kind
  end
  for name, kind in pairs(Spec.global_values) do
    values[name] = kind
  end
  for name in pairs((vocabulary and vocabulary.values) or {}) do
    values[name] = values[name] or 'none'
  end

  -- A trailing `=` is how both Git and `cli-cmd.completion.git.spec` mark an option
  -- as taking a value, so it is also the record of "a value goes here". Without
  -- it, `--grep=` fell through to the option list and offered itself back; the
  -- value source is 'none' until something better is known.
  local options = {}
  local function accept(name)
    options[bare(name)] = true
    if name:sub(-1) == '=' then
      values[bare(name)] = values[bare(name)] or 'none'
    end
  end
  for _, name in ipairs(Spec.global_options) do
    accept(name)
  end
  for _, name in ipairs(Spec.extra_options[route] or {}) do
    accept(name)
  end
  for _, name in ipairs((vocabulary and vocabulary.options) or {}) do
    accept(name)
  end
  for name in pairs(values) do
    options[name] = true
  end

  return { values = values, options = options, words = (vocabulary and vocabulary.words) or {} }
end

---Candidates for one value position. Paths are never cached: a file created a
---moment ago must still complete. Everything else comes from Git and is memoized
---for the keystroke burst.
local function value_candidates(facts, kind, prefix)
  if kind == 'none' then
    return {}
  elseif kind == 'strategies' then
    return Spec.strategies
  elseif kind == 'dates' then
    return Spec.dates
  elseif kind == 'paths' then
    return facts.sources.paths(prefix, facts.directory)
  end
  local source = facts.cached[kind]
  check(source ~= nil, 'unknown value source: ' .. tostring(kind))
  return source(facts.directory)
end

---How many positional arguments the subcommand has already received. Options and
---their values do not count; an option whose arity Git never reported is assumed
---not to take one, which is why `pending_option` refuses to guess past it.
local function filled_positionals(facts)
  local filled, after, previous = 0, false, nil
  for _, token in ipairs(facts.tokens) do
    if after then
      if not starts_with_dash(token) and not (previous and facts.knowledge.values[previous]) then
        filled = filled + 1
      end
      previous = token
    elseif token == facts.route then
      after = true
    end
  end
  return filled
end

---One rule per way of deciding. Each returns a candidate list, or nil to let the
---next rule decide; the order of this list *is* the priority, so the winner is
---readable without following nested branches.
local rules = {
  -- An option right before the cursor either takes its value here, or is one
  -- this Git never reported: unknown arity, so a positional guess would be wrong.
  function(facts)
    local pending = facts.tokens[#facts.tokens]
    if not pending or not option_token(pending) then
      return nil
    end
    local kind = facts.knowledge.values[pending]
    if kind then
      return value_candidates(facts, kind, facts.current)
    end
    if not facts.knowledge.options[bare(pending)] then
      return {}
    end
  end,

  -- `--author=` and friends complete their value, keeping the prefix attached.
  function(facts)
    local option, prefix = facts.current:match('^(%-%-[%w%-]+)=(.*)$')
    local kind = option and facts.knowledge.values[option]
    if not kind then
      return nil
    end
    local candidates = {}
    for _, value in ipairs(value_candidates(facts, kind, prefix)) do
      candidates[#candidates + 1] = option .. '=' .. value
    end
    return candidates
  end,

  -- After `--` Git reads paths only, for the rest of the invocation.
  function(facts)
    for _, token in ipairs(facts.tokens) do
      if token == '--' then
        return facts.sources.paths(facts.current, facts.directory)
      end
    end
  end,

  -- Option names: global ones before the subcommand, the subcommand's own after
  -- it. `-` alone is an argument, but its completions are still option names.
  function(facts)
    if not starts_with_dash(facts.current) then
      return nil
    end
    if facts.route == nil then
      return Spec.global_options
    end
    local candidates = vim.deepcopy(facts.vocabulary.options)
    vim.list_extend(candidates, Spec.extra_options[facts.route] or {})
    return candidates
  end,

  -- Before the subcommand, the subcommands Git reports are the answer.
  function(facts)
    if facts.route == nil then
      return facts.discover:subcommands()
    end
  end,

  -- A positional means whatever the specification says, by position when the
  -- meaning changes (`git push <remote> <refspec>`).
  function(facts)
    local kinds = Spec.positionals[facts.route]
    if not kinds then
      return nil
    end
    local kind = kinds
    if type(kinds) == 'table' then
      kind = kinds[math.min(filled_positionals(facts) + 1, #kinds)]
    end
    return value_candidates(facts, kind, facts.current)
  end,

  -- Last resort: the subwords this Git reports for the current subcommand.
  function(facts)
    return facts.knowledge.words
  end,
}

---Working directory implied by `-C` inside the token list.
local function effective_cwd(tokens, cwd)
  local directory = option_value(tokens, '-C')
  if not directory or directory == '' then
    return cwd
  end
  return vim.fn.fnamemodify(directory, ':p'):gsub('/+$', '')
end

---@param opts? {cwd?: string, executable?: string, timeout?: integer, cache_ttl?: integer, sources?: table, discover?: table}
---@return fun(query: table): string[]
function M.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  local cwd = opts.cwd or vim.fn.getcwd()
  check(type(cwd) == 'string' and cwd ~= '', 'cwd must be a non-empty string')
  local executable = opts.executable or 'git'
  check(type(executable) == 'string' and executable ~= '', 'executable must be a non-empty string')
  check(opts.sources == nil or type(opts.sources) == 'table', 'sources must be a table')
  check(opts.discover == nil or type(opts.discover) == 'table', 'discover must be a table')

  local discover = opts.discover
    or Discover.new({ executable = executable, cwd = cwd, timeout = opts.timeout or 1000 })
  local sources = default_sources(discover)
  for name, source in pairs(opts.sources or {}) do
    check(type(source) == 'function', 'source must be a function: ' .. name)
    sources[name] = source
  end
  local cached = memoize(sources, opts.cache_ttl or 2000)

  local knowledges = {}
  local function knowledge_of(route, vocabulary)
    local key = route or '\0'
    if not knowledges[key] then
      knowledges[key] = build_knowledge(route, vocabulary)
    end
    return knowledges[key]
  end

  return function(query)
    check(type(query) == 'table', 'query must be a table')
    local tokens = query.tokens or {}
    local directory = effective_cwd(tokens, cwd)
    local route = Git.subcommand(tokens)
    local vocabulary = route and discover:vocabulary(route, directory) or nil
    local facts = {
      tokens = tokens,
      current = query.arglead or '',
      directory = directory,
      route = route,
      vocabulary = vocabulary,
      knowledge = knowledge_of(route, vocabulary),
      discover = discover,
      sources = sources,
      cached = cached,
    }
    for _, rule in ipairs(rules) do
      local candidates = rule(facts)
      if candidates then
        return candidates
      end
    end
    return {}
  end
end

---Build a Neovim command-completion callback for a Git command definition.
---@param opts? {cwd?: string, executable?: string, timeout?: integer, cache_ttl?: integer, sources?: table, discover?: table}
---@return fun(arglead: string, cmdline: string, cursorpos: integer): string[]
function M.callback(opts)
  return Completion.callback(M.new(opts))
end

return M

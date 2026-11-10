---Git vocabulary discovery.
---
---Asks the installed Git instead of shipping hand-written command and option
---lists: `git --list-cmds` for subcommands and `git <cmd> --git-completion-helper`
---for the words and options a subcommand accepts. Options ending in `=` take a
---value, which is how value-taking options are detected without a curated table.
---
---`--git-completion-helper` refuses to run outside a repository. That is a
---deliberate limitation: outside a repository Git has no refs, so there is
---nothing meaningful to complete and no fallback list is kept.
local check = require('cli-cmd.guard')('cli-cmd.completion.git.discover')
local M = {}

local function default_run(executable, timeout)
  return function(argv, cwd)
    local command = { executable, unpack(argv) }
    local ok, process = pcall(vim.system, command, { cwd = cwd, text = true })
    if not ok then
      return nil
    end
    local finished = process:wait(timeout)
    if not finished then
      pcall(function()
        process:kill('sigkill')
      end)
      return nil
    end
    if finished.code ~= 0 then
      return nil
    end
    return finished.stdout
  end
end

---@param word string candidate as Git reported it
---@return string option name without the trailing marker
local function option_name(word)
  return (word:gsub('[=<]$', ''))
end

---Split helper output into option and word lists. Bare `--` is a separator, not
---a candidate.
---@param output string
---@return {options: string[], values: table<string, true>, words: string[]}
function M.parse_helper(output)
  check(type(output) == 'string', 'helper output must be a string')
  local options, values, words = {}, {}, {}
  local seen = {}
  for word in output:gmatch('%S+') do
    if word ~= '--' and not seen[word] then
      seen[word] = true
      if word:sub(1, 1) == '-' then
        options[#options + 1] = word
        if word:sub(-1) == '=' then
          values[option_name(word)] = true
        end
      else
        words[#words + 1] = word
      end
    end
  end
  return { options = options, values = values, words = words }
end

---@param opts? {executable?: string, cwd?: string, timeout?: integer, run?: fun(argv: string[], cwd: string): string?}
---@return table discovery instance
function M.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  local executable = opts.executable or 'git'
  check(type(executable) == 'string' and executable ~= '', 'executable must be a non-empty string')
  local cwd = opts.cwd or vim.fn.getcwd()
  check(type(cwd) == 'string' and cwd ~= '', 'cwd must be a non-empty string')
  local timeout = opts.timeout or 1000
  check(type(timeout) == 'number' and timeout > 0, 'timeout must be a positive number')
  check(opts.run == nil or type(opts.run) == 'function', 'run must be a function')
  return setmetatable({
    _executable = executable,
    _cwd = cwd,
    _run = opts.run or default_run(executable, timeout),
    _version = nil,
    _subcommands = nil,
    _cache = {},
  }, { __index = M })
end

---Git version string, cached. Used as part of every cache key so an upgraded Git
---is picked up.
---@return string
function M:_resolve_version()
  if self._version == nil then
    local output = self._run({ '--version' }, self._cwd)
    self._version = output and vim.trim(output) or 'unknown'
  end
  return self._version
end

---Ask Git and capture stdout. `nil` means Git could not answer: it failed to
---spawn, exited non-zero, or timed out and was killed. Every caller in this
---package treats `nil` as "no candidates", and every caller goes through here,
---so timeout and failure handling has one implementation.
---@param argv string[]
---@param cwd string
---@return string?
function M:run(argv, cwd)
  return self._run(argv, cwd)
end

---Subcommand names from Git itself.
---@return string[]
function M:subcommands()
  if self._subcommands == nil then
    local output = self._run({ '--list-cmds=main,others' }, self._cwd)
    local names = {}
    for name in (output or ''):gmatch('%S+') do
      names[#names + 1] = name
    end
    self._subcommands = names
  end
  return self._subcommands
end

---Options and words a subcommand accepts, cached per repository root.
---@param command string
---@param cwd string
---@return {options: string[], values: table<string, true>, words: string[]}
function M:vocabulary(command, cwd)
  check(type(command) == 'string' and command ~= '', 'command is required')
  check(type(cwd) == 'string' and cwd ~= '', 'cwd is required')
  local key = table.concat({ self:_resolve_version(), cwd, command }, '\0')
  local cached = self._cache[key]
  if cached == nil then
    local output = self._run({ command, '--git-completion-helper' }, cwd)
    cached = M.parse_helper(output or '')
    self._cache[key] = cached
  end
  return cached
end

return M

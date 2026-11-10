---Neovim command-line completion plumbing.
---Independent of routing and execution: a provider only maps a parsed command
---line to candidate strings.
local check = require('cli-cmd.guard')('cli-cmd.completion')
local M = {}

---Split text with native user-command rules: an unquoted backslash escapes the
---next byte and unescaped whitespace separates arguments. Quotes do not group.
---@param text string
---@return string[] tokens Completed arguments
---@return string current Unfinished argument at the end of the line
function M.split(text)
  check(type(text) == 'string', 'text must be a string')
  local tokens, current = {}, {}
  local escaped = false
  for i = 1, #text do
    local char = text:sub(i, i)
    if escaped then
      current[#current + 1] = char
      escaped = false
    elseif char == '\\' then
      escaped = true
    elseif char:match('%s') then
      if #current > 0 then
        tokens[#tokens + 1] = table.concat(current)
        current = {}
      end
    else
      current[#current + 1] = char
    end
  end
  return tokens, table.concat(current)
end

local function escape_candidate(candidate)
  return (candidate:gsub('\\', '\\\\'):gsub('%s', '\\%0'))
end

---Adapt a provider to Neovim's command-completion callback signature.
---The provider receives `{ tokens = string[], arglead = string, cmdline = string }`
---where `tokens` excludes the user command name and `arglead` is the unfinished
---argument. Candidates are returned unescaped by providers and escaped here so
---that Neovim inserts them as a single native `fargs` argument.
---@param provider fun(query: table): string[]|nil
---@return fun(arglead: string, cmdline: string, cursorpos: integer): string[]
function M.callback(provider)
  check(type(provider) == 'function', 'provider must be a function')
  return function(arglead, cmdline, cursorpos)
    cmdline = type(cmdline) == 'string' and cmdline or ''
    cursorpos =
      math.max(0, math.min(type(cursorpos) == 'number' and cursorpos or #cmdline, #cmdline))
    local before = cmdline:sub(1, cursorpos)
    local tokens, current = M.split(before)
    local prefix = current
    if prefix == '' and type(arglead) == 'string' and before:match('%s$') == nil then
      prefix = arglead
    end
    local candidates = provider({
      tokens = vim.list_slice(tokens, 2),
      arglead = prefix,
      cmdline = before,
    })
    check(
      candidates == nil or (type(candidates) == 'table' and vim.islist(candidates)),
      'provider must return a list or nil'
    )
    local result, seen = {}, {}
    for _, candidate in ipairs(candidates or {}) do
      check(type(candidate) == 'string', 'candidates must be strings')
      if vim.startswith(candidate, prefix) and not seen[candidate] then
        seen[candidate] = true
        result[#result + 1] = escape_candidate(candidate)
      end
    end
    return result
  end
end

return M

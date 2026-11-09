---Entry point for callers that only want a working command.
---
---`setup` assembles the pieces in the one order that works (presenter and
---completion before the command, editor bridge before the adapter) so callers
---describe what they want instead of how it is wired. Every module stays public
---and independently usable; this module adds convenience, not a second API.
local check = require('cli.guard')('cli')
local M = {}

local function resolve_presenter(option)
  check(
    option == nil or option == false or type(option) == 'table',
    'presenter must be a presenter, false, or nil'
  )
  if option == false then
    return false
  end
  return option or require('cli.presenter.notify').new()
end

---`true`/`nil` builds the default provider, a table passes options through, and
---`false` disables completion.
local function resolve_completion(option, defaults)
  check(
    option == nil or option == false or type(option) == 'table',
    'completion must be a table, false, or nil'
  )
  if option == false then
    return nil
  end
  local options = vim.tbl_extend('force', defaults, option or {})
  return require('cli.completion.git').callback(options)
end

---`false`/`nil` leaves the editor alone, which is the safest default: the bridge
---needs a reachable Neovim server and fails loudly without one.
local function resolve_editor(option, cwd)
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

local function resolve_adapter(option)
  check(option == nil or type(option) == 'string', 'adapter must be a string')
  local name = option or 'git'
  check(name == 'git', 'unknown adapter: ' .. tostring(name))
  return require('cli.adapter.git')
end

---Assemble a command definition.
---@param opts table
--- * `cwd` — working directory, defaults to the current one
--- * `adapter` — `'git'` (default); the only adapter with a preset today
--- * `editor` — `false` (default) or options for `cli.bridge.editor`
--- * `completion` — `true` (default), `false`, or `cli.completion.git` options
--- * `presenter` — `true` (default), `false`, or a presenter instance
--- * everything else (`executable`, `routes`, `replace_routes`, `fallback`,
---   `backends`, `env`, `terminal_capability`, `terminal_layout`) is forwarded
function M.setup(opts)
  check(opts == nil or type(opts) == 'table', 'options must be a table')
  opts = opts or {}

  local cwd = opts.cwd or vim.fn.getcwd()
  check(type(cwd) == 'string' and cwd ~= '', 'cwd must be a non-empty string')

  local adapter = resolve_adapter(opts.adapter)
  ---@type cli.NotifyPresenter|false?
  local presenter = resolve_presenter(opts.presenter)
  local executable = opts.executable or 'git'
  local completion = resolve_completion(opts.completion, {
    cwd = cwd,
    executable = executable,
  })
  ---@type cli.EditorBridge?
  local editor = resolve_editor(opts.editor, cwd)

  local command = adapter.new({
    cwd = cwd,
    executable = executable,
    routes = opts.routes,
    replace_routes = opts.replace_routes,
    fallback = opts.fallback,
    backends = opts.backends,
    env = opts.env,
    complete = completion,
    presenter = presenter,
    terminal_capability = opts.terminal_capability,
    terminal_layout = opts.terminal_layout,
    editor = editor,
  })

  local registered, disposed = {}, false
  local facade = {
    cwd = cwd,
    command = command,
    editor = editor,
    completion = completion,
    presenter = presenter,
  }

  ---Register a user command. Nothing is registered implicitly; this only fills
  ---in the route key so callers do not have to reach for the adapter module.
  function facade.register(name, options)
    check(type(name) == 'string' and name ~= '', 'command name is required')
    local merged = vim.tbl_extend('force', options or {}, {
      route_key = (options or {}).route_key or adapter.route_key,
    })
    command:register(name, merged)
    registered[#registered + 1] = name
    return command
  end

  ---Release what `setup` created: user commands it registered and the editor
  ---bridge if one was requested. Safe to call twice.
  function facade.dispose()
    if disposed then
      return
    end
    disposed = true
    for _, name in ipairs(registered) do
      pcall(vim.api.nvim_del_user_command, name)
    end
    registered = {}
    if editor then
      editor:dispose()
    end
    return facade
  end

  return facade
end

return M

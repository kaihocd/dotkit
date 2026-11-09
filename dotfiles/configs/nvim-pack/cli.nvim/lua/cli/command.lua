local Context = require('cli.context')
local Dispatcher = require('cli.dispatcher')
local NativeTerminal = require('cli.backend.native_terminal')
local Notify = require('cli.presenter.notify')
local Process = require('cli.backend.process')
local Router = require('cli.router')
local Task = require('cli.task')
local Terminal = require('cli.backend.terminal')
local check = require('cli.guard')('cli.command')

local Command = {}
Command.__index = Command

local terminal_layouts = { tab = true, split = true, vsplit = true }

local function validate(opts)
  check(type(opts) == 'table', 'expected options table')
  check(type(opts.executable) == 'string' and opts.executable ~= '', 'executable is required')
  check(type(opts.cwd) == 'string' and opts.cwd ~= '', 'cwd is required')
  check(
    opts.presenter == nil or opts.presenter == false or type(opts.presenter) == 'table',
    'presenter must be a presenter, false, or nil'
  )
  check(
    opts.terminal_layout == nil or terminal_layouts[opts.terminal_layout] == true,
    'terminal_layout must be one of tab, split, vsplit'
  )
  check(
    opts.complete == nil or type(opts.complete) == 'function' or type(opts.complete) == 'string',
    'complete must be a function or function name'
  )
end

local function copy_handlers(handlers)
  local result = {}
  for name, handler in pairs(handlers or {}) do
    check(type(name) == 'string' and name ~= '', 'invalid backend name')
    check(type(handler) == 'function', 'backend must be a function: ' .. name)
    result[name] = handler
  end
  return result
end

---`process` is the built-in non-interactive backend; `terminal` is either the
---injected capability or the native implementation. Both are constructed even
---when a caller supplies its own handler, so a bad configuration still fails
---here instead of being silently ignored.
local function build_backends(opts)
  local terminal
  if opts.terminal_capability then
    terminal = Terminal.new(opts.terminal_capability)
  else
    terminal = NativeTerminal.new({ layout = opts.terminal_layout })
  end
  local handlers = copy_handlers(opts.backends)
  handlers.process = handlers.process or Process.run
  handlers.terminal = handlers.terminal
    or function(context, task)
      terminal:run(context, task)
    end
  return handlers
end

---A table is snapshotted; a function is evaluated per dispatch, which is how a
---capability such as the editor bridge injects per-invocation variables.
local function normalize_env(env)
  if type(env) == 'function' then
    return env
  end
  return env and vim.deepcopy(env) or nil
end

local function normalize_presenter(presenter)
  if presenter == false then
    return false
  end
  return presenter or Notify.new()
end

function Command.new(opts)
  validate(opts)
  local router = Router.new({
    handlers = build_backends(opts),
    routes = opts.routes,
    fallback = opts.fallback,
  })
  return setmetatable({
    _executable = opts.executable,
    _cwd = opts.cwd,
    _env = normalize_env(opts.env),
    _complete = opts.complete,
    _presenter = normalize_presenter(opts.presenter),
    _router = router,
    _dispatcher = Dispatcher.new({ router = router, task = Task }),
  }, Command)
end

---@return table<string, string>?
function Command:_resolve_env()
  if type(self._env) ~= 'function' then
    return self._env
  end
  local env = self._env()
  check(env == nil or type(env) == 'table', 'env function must return a table or nil')
  return env
end

function Command:dispatch(input)
  check(type(input) == 'table', 'input is required')
  local context = Context.new({
    executable = self._executable,
    argv = input.argv,
    raw_input = input.raw_input,
    cwd = input.cwd or self._cwd,
    env = input.env or self:_resolve_env(),
    route_key = input.route_key,
  })
  local presenter = self._presenter
  if not presenter then
    return self._dispatcher:dispatch(context)
  end
  return self._dispatcher:dispatch(context, {
    on_create = function(task)
      presenter:attach(task)
    end,
  })
end

function Command:register(name, opts)
  check(type(name) == 'string' and name ~= '', 'command name is required')
  check(type(opts) == 'table', 'registration options are required')
  check(
    opts.route_key == nil or type(opts.route_key) == 'string' or type(opts.route_key) == 'function',
    'route_key must be a string or function'
  )
  check(
    opts.complete == nil or type(opts.complete) == 'function' or type(opts.complete) == 'string',
    'complete must be a function or function name'
  )
  check(opts.force == nil or type(opts.force) == 'boolean', 'force must be a boolean')

  local command = self
  local complete = opts.complete or self._complete
  vim.api.nvim_create_user_command(name, function(command_opts)
    local route_key = opts.route_key
    if type(route_key) == 'function' then
      route_key = route_key(command_opts.fargs, command_opts)
    end
    command:dispatch({
      argv = command_opts.fargs,
      raw_input = command_opts.args,
      route_key = route_key,
    })
  end, {
    nargs = '*',
    complete = complete,
    bang = opts.bang == true,
    force = opts.force == true,
  })
end

return Command

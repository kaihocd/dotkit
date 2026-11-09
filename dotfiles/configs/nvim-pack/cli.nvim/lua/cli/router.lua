local check = require('cli.guard')('cli.router')

---Pure route resolver. Execution and Terminal semantics belong to the caller.
---@class cli.Router
---@field private _routes table<string, function>
---@field private _fallback function
local Router = {}
Router.__index = Router

local function valid_name(value)
  return type(value) == 'string' and value ~= '' and not value:find('\0', 1, true)
end

---Validate and snapshot registrations. The fallback must represent Terminal
---delegation; the resolver deliberately does not inspect handler implementations.
---@param opts {handlers?: table<string, function>, routes?: table<string, string|function>, fallback?: string|function}
---@return cli.Router
function Router.new(opts)
  check(type(opts) == 'table', 'expected options table')
  local handlers = opts.handlers
  if handlers == nil then
    handlers = {}
  end
  check(type(handlers) == 'table', 'handlers must be a table')
  for name, handler in pairs(handlers) do
    check(valid_name(name), 'invalid handler name')
    check(type(handler) == 'function', 'handler must be a function: ' .. name)
  end

  local function resolve(reference)
    if type(reference) == 'function' then
      return reference
    end
    check(valid_name(reference), 'handler reference must be a name or function')
    local handler = handlers[reference]
    check(handler ~= nil, 'unknown handler: ' .. reference)
    return handler
  end

  local definitions = opts.routes
  if definitions == nil then
    definitions = {}
  end
  check(type(definitions) == 'table', 'routes must be a table')
  local routes = {}
  for key, reference in pairs(definitions) do
    check(valid_name(key), 'invalid route key')
    routes[key] = resolve(reference)
  end
  local fallback = opts.fallback
  if fallback == nil then
    fallback = 'terminal'
  end
  return setmetatable({ _routes = routes, _fallback = resolve(fallback) }, Router)
end

---Return the selected handler without invoking it or mutating Context. The
---router reads one field, so it takes that much of a Context and not more:
---`route_key` is set by the adapter, `argv[1]` is the fallback signal.
---@param ctx {route_key?: string, argv?: string[]}
---@return function handler
function Router:resolve(ctx)
  return self._routes[ctx.route_key] or self._fallback
end

return Router

local check = require('cli-cmd.guard')('cli-cmd.dispatcher')
local Dispatcher = {}
Dispatcher.__index = Dispatcher

function Dispatcher.new(opts)
  check(type(opts) == 'table', 'expected options table')
  check(
    type(opts.router) == 'table' and type(opts.router.resolve) == 'function',
    'router is required'
  )
  check(
    type(opts.task) == 'table' and type(opts.task.new) == 'function',
    'task factory is required'
  )
  return setmetatable({ _router = opts.router, _task = opts.task }, Dispatcher)
end

---@param context table
---@param opts? {on_create?: fun(task: table)}
function Dispatcher:dispatch(context, opts)
  opts = opts or {}
  check(type(opts) == 'table', 'dispatch options must be a table')
  check(opts.on_create == nil or type(opts.on_create) == 'function', 'on_create must be a function')
  local task = self._task.new({ context = context })
  if opts.on_create then
    opts.on_create(task)
  end
  task:start()
  local ok, err = pcall(function()
    local handler = self._router:resolve(context)
    check(type(handler) == 'function', 'router returned a non-function handler')
    handler(context, task)
  end)
  if not ok then
    task:finish({ kind = 'error', message = tostring(err) })
    error(err, 0)
  end
  return task
end

return Dispatcher

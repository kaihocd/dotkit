local check = require('cli.guard')('cli.process')
local M = {}

---Both streams report the same way: a read error ends the task, data is
---forwarded while the task still accepts it.
local function stream(task, name)
  return function(err, data)
    if err then
      task:finish({ kind = 'error', message = name .. ': ' .. tostring(err) })
    elseif data then
      task:output(name, data)
    end
  end
end

---Translate the child's termination into a result. A signal is not success, so
---it is reported the way a shell does (128 + signal): a Ctrl-C or a
---self-terminated command never looks like exit 0.
local function result_of(out)
  if out.signal and out.signal ~= 0 then
    return { kind = 'exit', code = 128 + out.signal }
  end
  if type(out.code) == 'number' then
    return { kind = 'exit', code = out.code }
  end
  return { kind = 'error', message = 'process reported neither exit code nor signal' }
end

---Run a command without a tty: stdin is `/dev/null`, so interactive commands
---must not be routed here.
function M.run(context, task)
  check(type(context) == 'table', 'context is required')
  check(task and type(task.finish) == 'function', 'task is required')

  local process
  local ok, result = pcall(vim.system, { context.executable, unpack(context.argv) }, {
    cwd = context.cwd,
    env = context.env,
    text = true,
    stdout = stream(task, 'stdout'),
    stderr = stream(task, 'stderr'),
  }, function(out)
    vim.schedule(function()
      task:finish(result_of(out))
    end)
  end)
  if not ok then
    task:finish({ kind = 'error', message = tostring(result) })
    error(result, 0)
  end
  process = result

  task:on(function(event)
    if event.kind == 'cancel' and not process:is_closing() then
      process:kill('sigterm')
    end
  end)
  return process
end

return M

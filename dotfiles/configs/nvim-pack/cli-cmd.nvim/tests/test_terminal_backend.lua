return function(test)
  test('delegates through an injected capability and preserves the context', function()
    local Terminal = require('cli-cmd.backend.external_terminal')
    local Task = require('cli-cmd.task')
    local received_context
    local received_task
    local capability = {
      delegate = function(context, task)
        received_context, received_task = context, task
        return { cancel = function() end }
      end,
    }
    local task = Task.new()
    task:start()
    local handle = Terminal.new(capability):run({ executable = 'git', argv = { 'status' } }, task)
    assert(received_context.executable == 'git')
    assert(received_context.argv[1] == 'status')
    assert(received_task == task)
    assert(type(handle.cancel) == 'function')
    assert(vim.deep_equal(task:result(), { kind = 'delegated', target = 'terminal' }))
  end)

  ---A capability that can see the exit code is the only one that can: without
  ---`owns_result` the adapter claims `delegated`, which is a statement about what it
  ---knows rather than about the command.
  test('lets a capability report the real outcome instead of delegated', function()
    local Terminal = require('cli-cmd.backend.external_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local handle = Terminal.new({
      delegate = function(_, current)
        vim.defer_fn(function()
          current:finish({ kind = 'exit', code = 3 })
        end, 10)
        return { owns_result = true }
      end,
    }):run({ executable = 'sh', argv = { '-c', 'exit 3' } }, task)
    assert(handle.owns_result == true)
    assert(task:status() == 'running', 'the adapter must not close a task it cannot judge')
    vim.wait(2000, function()
      return task:status() == 'finished'
    end, 10)
    assert(vim.deep_equal(task:result(), { kind = 'exit', code = 3 }), vim.inspect(task:result()))
  end)

  test('rejects a handle whose owns_result is not a boolean', function()
    local Terminal = require('cli-cmd.backend.external_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local ok, err = pcall(function()
      Terminal.new({
        delegate = function()
          return { owns_result = 'yes' }
        end,
      }):run({ executable = 'sh', argv = {} }, task)
    end)
    assert(not ok)
    assert(tostring(err):find('owns_result must be a boolean', 1, true), tostring(err))
  end)

  test('reports capability failure and rethrows it', function()
    local Terminal = require('cli-cmd.backend.external_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local ok = pcall(function()
      Terminal.new({
        delegate = function()
          error('cannot send command')
        end,
      }):run({}, task)
    end)
    assert(not ok)
    assert(task:result().kind == 'error')
    assert(task:result().message:find('cannot send command', 1, true))
  end)

  test('rejects malformed capabilities before dispatch', function()
    local Terminal = require('cli-cmd.backend.external_terminal')
    local ok, err = pcall(Terminal.new, {})
    assert(not ok)
    assert(tostring(err):find('cli-cmd.backend.external_terminal:', 1, true))
  end)
end

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

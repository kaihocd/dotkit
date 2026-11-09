return function(test)
  local function wait_for(task)
    vim.wait(3000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished', 'process did not finish')
  end

  test('runs argv directly, streams stdout and stderr, and reports exit code', function()
    local Process = require('cli.backend.process')
    local Task = require('cli.task')
    local events = {}
    local task = Task.new()
    task:on(function(event)
      events[#events + 1] = event
    end)
    task:start()
    local process = Process.run({
      executable = 'sh',
      argv = { '-c', 'printf out; printf err >&2; exit 3' },
      cwd = vim.fn.getcwd(),
      env = { CLI_PROCESS_TEST = 'present' },
    }, task)
    assert(type(process.kill) == 'function')
    wait_for(task)
    assert(task:result().kind == 'exit' and task:result().code == 3)
    assert(events[2].kind == 'output' and events[2].stream == 'stdout' and events[2].data == 'out')
    assert(events[3].kind == 'output' and events[3].stream == 'stderr' and events[3].data == 'err')
  end)

  test('reports a signal-terminated process as a nonzero exit, never as success', function()
    local Process = require('cli.backend.process')
    local Task = require('cli.task')
    local task = Task.new()
    task:start()
    Process.run({ executable = 'sh', argv = { '-c', 'kill -INT $$' }, cwd = vim.fn.getcwd() }, task)
    vim.wait(5000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished')
    assert(
      vim.deep_equal(task:result(), { kind = 'exit', code = 130 }),
      'SIGINT must map to 130, not 0: ' .. vim.inspect(task:result())
    )
  end)

  test('cancellation kills the child and reports cancelled instead of success', function()
    local Process = require('cli.backend.process')
    local Task = require('cli.task')
    local task = Task.new()
    task:start()
    Process.run({ executable = 'sh', argv = { '-c', 'sleep 5' }, cwd = vim.fn.getcwd() }, task)
    assert(task:cancel() == true)
    wait_for(task)
    assert(task:result().kind == 'cancelled')
  end)

  test('reports a spawn failure as an error', function()
    local Process = require('cli.backend.process')
    local Task = require('cli.task')
    local task = Task.new()
    task:start()
    local ok = pcall(
      Process.run,
      { executable = '/path/that/does/not/exist', argv = {}, cwd = vim.fn.getcwd() },
      task
    )
    assert(not ok)
    assert(task:status() == 'finished')
    assert(task:result().kind == 'error')
  end)
end

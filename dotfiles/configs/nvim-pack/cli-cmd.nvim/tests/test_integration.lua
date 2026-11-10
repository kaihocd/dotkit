return function(test)
  local function wait_for(task)
    vim.wait(3000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished', 'integration task did not finish')
  end

  test('dispatches through Router and Process Backend to a real process', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Process = require('cli-cmd.backend.process')
    local Router = require('cli-cmd.router')
    local Task = require('cli-cmd.task')
    local output = {}
    local seen_context
    local seen_task
    local router = Router.new({
      handlers = {
        process = function(context, task)
          seen_context, seen_task = context, task
          task:on(function(event)
            if event.kind == 'output' then
              output[event.stream] = (output[event.stream] or '') .. event.data
            end
          end)
          Process.run(context, task)
        end,
        terminal = function(_, task)
          task:complete({ kind = 'delegated', target = 'terminal' })
        end,
      },
      routes = { inspect = 'process' },
    })
    local context = {
      executable = 'sh',
      argv = { '-c', 'printf integration-out; printf integration-err >&2; exit 7' },
      cwd = vim.fn.getcwd(),
      route_key = 'inspect',
    }
    local task = Dispatcher.new({ router = router, task = Task }):dispatch(context)
    wait_for(task)
    assert(seen_context == context)
    assert(seen_task == task)
    assert(output.stdout == 'integration-out')
    assert(output.stderr == 'integration-err')
    assert(vim.deep_equal(task:result(), { kind = 'exit', code = 7 }))
  end)

  test('dispatches through Router and Native Terminal Backend to a real TTY process', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Native = require('cli-cmd.backend.native_terminal')
    local Router = require('cli-cmd.router')
    local Task = require('cli-cmd.task')
    local buffer
    local router = Router.new({
      handlers = {
        native = function(context, task)
          local handle = Native.run(context, task)
          buffer = handle.buf
        end,
      },
      routes = { interactive = 'native' },
      fallback = function(_, task)
        task:complete({ kind = 'delegated', target = 'terminal' })
      end,
    })
    local task = Dispatcher.new({ router = router, task = Task }):dispatch({
      executable = 'sh',
      argv = { '-c', 'printf tty-integration; exit 0' },
      cwd = vim.fn.getcwd(),
      route_key = 'interactive',
    })
    wait_for(task)
    assert(vim.deep_equal(task:result(), { kind = 'exit', code = 0 }))
    assert(vim.api.nvim_buf_is_valid(buffer))
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    assert(table.concat(lines, '\n'):find('tty%-integration'))
    vim.api.nvim_buf_delete(buffer, { force = true })
  end)

  test('uses Router fallback through Dispatcher and reports delegation distinctly', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Router = require('cli-cmd.router')
    local Task = require('cli-cmd.task')
    local called = false
    local router = Router.new({
      handlers = {
        terminal = function(context, task)
          called = context.route_key == 'fallback'
          task:complete({ kind = 'delegated', target = 'terminal' })
        end,
      },
    })
    local task = Dispatcher.new({ router = router, task = Task })
      :dispatch({ route_key = 'fallback' })
    assert(called)
    assert(vim.deep_equal(task:result(), { kind = 'delegated', target = 'terminal' }))
  end)
end

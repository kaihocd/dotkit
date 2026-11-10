return function(test)
  test('creates and starts one Task before invoking the routed handler', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Task = require('cli-cmd.task')
    local order = {}
    local received
    local router = {
      resolve = function(_, ctx)
        order[#order + 1] = 'resolve'
        assert(ctx.route_key == 'commit')
        return function(context, task)
          order[#order + 1] = 'handler'
          received = { context = context, task = task }
        end
      end,
    }
    local dispatcher = Dispatcher.new({ router = router, task = Task })
    local context = { route_key = 'commit' }
    local task = dispatcher:dispatch(context)
    assert(vim.deep_equal(order, { 'resolve', 'handler' }))
    assert(received.task == task)
    assert(received.context == context)
    assert(task:status() == 'running')
  end)

  test('completes Task with error when routing or handler dispatch fails', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Task = require('cli-cmd.task')
    local function assert_failure(router)
      local dispatcher = Dispatcher.new({ router = router, task = Task })
      local ok, err = pcall(dispatcher.dispatch, dispatcher, {})
      assert(not ok and tostring(err):find('failed', 1, true), tostring(err))
    end
    assert_failure({
      resolve = function()
        error('routing failed')
      end,
    })
    assert_failure({
      resolve = function()
        return function()
          error('handler failed')
        end
      end,
    })
  end)

  test('does not replace a handler result when a handler errors after completing', function()
    local Dispatcher = require('cli-cmd.dispatcher')
    local Task = require('cli-cmd.task')
    local dispatcher = Dispatcher.new({
      router = {
        resolve = function()
          return function(_, task)
            task:complete({ kind = 'delegated', target = 'terminal' })
            error('late failure')
          end
        end,
      },
      task = Task,
    })
    local ok = pcall(dispatcher.dispatch, dispatcher, {})
    assert(not ok)
  end)
end

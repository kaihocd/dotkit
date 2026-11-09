return function(test)
  test('resolves named routes without executing handlers or interpreting argv', function()
    local function handler()
      error('resolver must not execute handlers')
    end
    local router = require('cli.router').new({
      handlers = { process = handler, terminal = function() end },
      routes = { commit = 'process' },
    })
    local ctx = { route_key = 'commit', argv = { '-C', 'some directory', 'commit' } }
    local before = vim.deepcopy(ctx)
    assert(router:resolve(ctx) == handler)
    assert(vim.deep_equal(ctx, before))
  end)

  test('supports custom route handlers and configurable Terminal fallback', function()
    local function terminal()
      error('must not execute')
    end
    local function custom()
      error('must not execute')
    end
    local router = require('cli.router').new({
      handlers = { popup = terminal },
      routes = { inspect = custom },
      fallback = 'popup',
    })
    assert(router:resolve({ route_key = 'inspect' }) == custom)
    assert(router:resolve({ route_key = 'unknown' }) == terminal)
    assert(router:resolve({ argv = { 'inspect' } }) == terminal)
    assert(router:resolve({ route_key = 'Inspect' }) == terminal)
    local direct = require('cli.router').new({ fallback = terminal })
    assert(direct:resolve({}) == terminal)
  end)

  test('rejects invalid registrations at construction, not by silently falling back', function()
    local function terminal() end
    local function rejects(opts)
      local ok, err = pcall(require('cli.router').new, opts)
      assert(not ok, 'accepted invalid registration: ' .. vim.inspect(opts))
      assert(tostring(err):find('cli.router:', 1, true), tostring(err))
    end
    rejects(nil)
    rejects(false)
    rejects({})
    rejects({ handlers = false })
    rejects({ handlers = { terminal = true } })
    rejects({ handlers = { terminal = terminal, [''] = terminal } })
    rejects({ handlers = { terminal = terminal, [1] = terminal } })
    rejects({ handlers = { terminal = terminal }, routes = false })
    rejects({ handlers = { terminal = terminal }, routes = { commit = 'missing' } })
    rejects({ handlers = { terminal = terminal }, routes = { commit = false } })
    rejects({ handlers = { terminal = terminal }, routes = { [''] = terminal } })
    rejects({ handlers = { terminal = terminal }, routes = { [1] = terminal } })
    rejects({ handlers = { terminal = terminal }, fallback = false })
    rejects({ handlers = { terminal = terminal }, fallback = 'missing' })
  end)

  test('snapshots registrations and keeps router instances independent', function()
    local function terminal() end
    local function process() end
    local opts =
      { handlers = { terminal = terminal, process = process }, routes = { commit = 'process' } }
    local first = require('cli.router').new(opts)
    opts.handlers.process = terminal
    opts.handlers.terminal = process
    opts.routes.commit = 'terminal'
    local second = require('cli.router').new(opts)
    assert(first:resolve({ route_key = 'commit' }) == process)
    assert(first:resolve({}) == terminal)
    assert(second:resolve({}) == process)
    assert(opts.routes.commit == 'terminal')
  end)
end

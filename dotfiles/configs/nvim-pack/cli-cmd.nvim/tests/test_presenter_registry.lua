---Configuring a sink and choosing one are separate, so this is where the two
---meet: `setup` names presenters, `install` picks one by name.
return function(test)
  local Registry = require('cli-cmd.presenter.registry')
  local cli = require('cli-cmd')
  local Output = require('cli-cmd.presenter.output')

  test('has the three built-in kinds even before setup', function()
    Registry.setup(nil)
    for _, name in ipairs({ 'split', 'tab', 'notify' }) do
      local presenter = Registry.get(name)
      assert(type(presenter.attach) == 'function', name .. ' is usable without setup')
    end
    assert(type(Registry.get().attach) == 'function', 'no name means the default kind')
  end)

  test('treats a built-in name as its own kind', function()
    local seen = {}
    Registry.setup({
      presenters = {
        split = {
          min_height = 4,
          -- A window option, which is what `tab` and `split` have in common.
          number = true,
        },
      },
    })
    local presenter = Registry.get('split')
    assert(getmetatable(presenter) == Output, 'the registry builds a presenter')
    presenter:attach(require('cli-cmd.task').new())
    seen.min_height = presenter:_height(1)
    assert(seen.min_height == 4, 'min_height = 4 reaches the split')
  end)

  test('lets any other name reuse a kind', function()
    Registry.setup({ presenters = { log = { kind = 'split', max_height = 6 } } })
    local presenter = Registry.get('log')
    assert(presenter:_height(100) == 6, 'the named presenter carries its own height')
    assert(Registry.get('split') ~= presenter, 'the built-in split is still its own')
  end)

  test('takes a function as the whole presenter', function()
    local seen = {}
    Registry.setup({
      presenters = {
        page = function(message, level)
          seen[#seen + 1] = { message = message, level = level }
        end,
      },
    })
    Registry.get('page'):report('hello', vim.log.levels.WARN)
    assert(#seen == 1 and seen[1].message == 'hello', 'the function is the sink')
  end)

  test('refuses a name it was never told about', function()
    Registry.setup(nil)
    local ok, err = pcall(Registry.get, 'missing')
    assert(not ok and tostring(err):find("no presenter named 'missing'", 1, true), tostring(err))
  end)

  test('refuses a name that neither is built in nor says its kind', function()
    local ok, err = pcall(Registry.setup, { presenters = { log = { max_height = 6 } } })
    assert(not ok and tostring(err):find("presenter 'log' must set kind", 1, true), tostring(err))
  end)

  test('refuses an entry that is neither a config nor a function', function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Registry.setup, { presenters = { log = 'split' } })
    assert(
      not ok and tostring(err):find("presenter 'log' must be a config table", 1, true),
      tostring(err)
    )
  end)

  test('reports a bad field through the same rules as the presenter', function()
    local ok, err = pcall(Registry.setup, { presenters = { tab = { min_height = 3 } } })
    assert(not ok and tostring(err):find('does not apply to kind', 1, true), tostring(err))
  end)

  test('takes the default presenter name from the declaration', function()
    Registry.setup(nil)
    local presenter = Registry.get()
    ---@diagnostic disable-next-line: invisible
    local kind = presenter._kind
    assert(kind == Output.defaults.kind, 'an unnamed tool lands in the declared default kind')
  end)

  test('is the only thing install reads, so a name is enough', function()
    local Installer = require('cli-cmd.install')
    Registry.setup({ presenters = { quiet = { kind = 'notify' } } })
    Installer.dispose('probe')
    local tool = cli.define('probe', { executable = 'sh', presenter = 'quiet' })
    assert(type(tool.presenter.attach) == 'function')
    Installer.dispose('probe')

    Registry.setup(nil)
    local stale = pcall(cli.define, 'probe', { executable = 'sh', presenter = 'quiet' })
    assert(not stale, 'a name from a replaced set is gone')
    Installer.dispose('probe')
  end)
end

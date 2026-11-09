return function(test)
  ---Dispatch through `Git` with recording backends so route resolution is
  ---observable without running Git.
  local function make_harness(opts)
    local Git = require('cli.adapter.git')
    local repo = _G.cli_test.temp_repo()
    local calls = {}
    local function record(name)
      return function(_, task)
        calls[#calls + 1] = name
        task:complete({ kind = 'exit', code = 0 })
      end
    end
    local options = vim.tbl_extend('force', {
      cwd = repo,
      backends = { process = record('process'), terminal = record('terminal') },
      presenter = false,
    }, opts or {})
    local git = Git.new(options)
    return {
      run = function(argv)
        calls = {}
        git:dispatch({
          argv = argv,
          raw_input = table.concat(argv, ' '),
          route_key = Git.route_key(argv),
        })
        return calls[1]
      end,
    }
  end

  test('finds the subcommand after global options and option values', function()
    local Git = require('cli.adapter.git')
    assert(
      Git.route_key({ '--no-pager', '-C', '/repo', '-c', 'user.name=Name', 'status' }) == 'status'
    )
    assert(
      Git.route_key({ '--git-dir=/tmp/repo.git', '--work-tree', '/tmp/work', 'commit' }) == 'commit'
    )
  end)

  test('handles short and long boolean global options without consuming the command', function()
    local Git = require('cli.adapter.git')
    assert(Git.route_key({ '--bare', '--literal-pathspecs', 'log' }) == 'log')
    assert(Git.route_key({ '-p', 'diff' }) == 'diff')
  end)

  test('returns nil when no subcommand is present', function()
    local Git = require('cli.adapter.git')
    assert(Git.route_key({}) == nil)
    assert(Git.route_key({ '--no-pager', '-C', '/repo' }) == nil)
    assert(Git.route_key({ '--' }) == nil)
  end)

  test('routes subcommands through the default preset', function()
    local Git = require('cli.adapter.git')
    local harness = make_harness()
    assert(harness.run({ 'status', '--short' }) == 'process')
    assert(harness.run({ 'commit', '-m', 'x' }) == 'process')
    assert(harness.run({ 'log', '-1', '--oneline' }) == 'terminal')
    assert(harness.run({ 'diff' }) == 'terminal')
    assert(harness.run({ 'push' }) == 'terminal')
    assert(harness.run({}) == 'terminal')
  end)

  test('merges user routes over the defaults and can replace them entirely', function()
    local Git = require('cli.adapter.git')
    local merged = make_harness({ routes = { log = 'process' } })
    assert(merged.run({ 'log' }) == 'process')
    assert(merged.run({ 'status' }) == 'process', 'untouched defaults must survive the merge')

    local replaced = make_harness({ replace_routes = true, routes = { status = 'terminal' } })
    assert(replaced.run({ 'status' }) == 'terminal')
    assert(replaced.run({ 'commit' }) == 'terminal', 'replaced presets must not keep defaults')
  end)

  test('exposes a copy of the default preset and honours a custom fallback', function()
    local Git = require('cli.adapter.git')
    local preset = Git.default_routes()
    assert(preset.status == 'process')
    assert(preset.log == nil)
    preset.status = 'terminal'
    assert(Git.default_routes().status == 'process', 'the preset copy must be decoupled')
    assert(Git.default_fallback == 'terminal')
    assert(make_harness({ fallback = 'process' }).run({ 'log' }) == 'process')
  end)

  test('rejects malformed route definitions', function()
    local Git = require('cli.adapter.git')
    local cwd = vim.fn.getcwd()
    assert(not pcall(Git.new, { cwd = cwd, routes = 'status' }))
    assert(not pcall(Git.new, { cwd = cwd, routes = { status = 5 } }))
    assert(not pcall(Git.new, { cwd = cwd, routes = { [''] = 'process' } }))
    assert(not pcall(Git.new, { cwd = cwd, replace_routes = 'yes' }))
    local ok, err = pcall(Git.new, { cwd = cwd, routes = { status = '' } })
    assert(not ok)
    assert(tostring(err):find('route target must be a backend name or a function', 1, true))
  end)

  test('does not mutate argv and rejects malformed input', function()
    local Git = require('cli.adapter.git')
    local argv = { '-C', '/repo', 'status' }
    assert(Git.route_key(argv) == 'status')
    assert(vim.deep_equal(argv, { '-C', '/repo', 'status' }))
    local ok, err = pcall(Git.route_key, { '-C' })
    assert(not ok)
    assert(tostring(err):find('cli.git:', 1, true))
  end)
end

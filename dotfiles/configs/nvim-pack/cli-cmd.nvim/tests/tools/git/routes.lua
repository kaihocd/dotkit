return function(test)
  ---Dispatch through Git's command with recording backends so route resolution
  ---is observable without running GitCommand.
  local function make_harness(opts)
    local GitCommand = require('cli-cmd.tools.git.command')
    local repo = _G.cli_cmd_test.temp_repo()
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
    local git = GitCommand.build(options, {
      cwd = options.cwd,
      presenter = options.presenter,
      editor = options.editor,
    })
    return {
      run = function(argv)
        calls = {}
        git:dispatch({
          argv = argv,
          route_key = GitCommand.route_key(argv),
        })
        return calls[1]
      end,
    }
  end

  test('finds the subcommand after global options and option values', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(
      GitCommand.subcommand({ '--no-pager', '-C', '/repo', '-c', 'user.name=Name', 'status' })
        == 'status'
    )
    assert(
      GitCommand.subcommand({ '--git-dir=/tmp/repo.git', '--work-tree', '/tmp/work', 'commit' })
        == 'commit'
    )
  end)

  test('handles short and long boolean global options without consuming the command', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.subcommand({ '--bare', '--literal-pathspecs', 'log' }) == 'log')
    assert(GitCommand.subcommand({ '-p', 'diff' }) == 'diff')
    assert(GitCommand.subcommand({ '--paginate', 'log' }) == 'log', '--paginate takes no value')
  end)

  test('returns nil when no subcommand is present', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.subcommand({}) == nil)
    assert(GitCommand.subcommand({ '--no-pager', '-C', '/repo' }) == nil)
    assert(GitCommand.subcommand({ '--' }) == nil)
  end)

  test('routes a quiet invocation to capture', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.route_key({ 'add', '.' }) == 'capture')
    assert(GitCommand.route_key({ 'status', '--short' }) == 'capture')
    assert(GitCommand.route_key({ 'commit', '-m', 'x' }) == 'capture')
    assert(GitCommand.route_key({ 'log', '--oneline' }) == 'capture')
    assert(GitCommand.route_key({}) == 'capture')
  end)

  test('routes an invocation that asks for a conversation to interactive', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.route_key({ 'add', '-p' }) == 'interactive')
    assert(GitCommand.route_key({ 'add', '--patch', '.' }) == 'interactive')
    assert(GitCommand.route_key({ 'reset', '-i' }) == 'interactive')
    assert(GitCommand.route_key({ 'rebase', '--interactive' }) == 'interactive')
    assert(GitCommand.route_key({ '--no-pager', 'log', '-p' }) == 'interactive')
    assert(GitCommand.route_key({ '--paginate', 'log' }) == 'interactive')
    assert(GitCommand.route_key({ 'log', '--help' }) == 'interactive')
  end)

  test('reads flags literally, but stops at `--`', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.route_key({ 'add', '--', '-p' }) == 'capture', 'a pathspec is not an option')
    assert(
      GitCommand.route_key({ 'commit', '-m', 'add -p' }) == 'capture',
      'one argv entry is one word'
    )
    -- A value that is spelled exactly like an option still reads as one: the
    -- route takes git at its word rather than keeping a table of every
    -- subcommand's value-taking options. The cost is an unnecessary terminal.
    assert(GitCommand.route_key({ 'log', '--grep', '--patch' }) == 'interactive')
    assert(GitCommand.route_key({ 'log', '--grep=--patch' }) == 'capture')
  end)

  test('routes subcommands that only work with a human to interactive', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    assert(GitCommand.route_key({ 'mergetool' }) == 'interactive')
    assert(GitCommand.route_key({ 'bisect', 'run' }) == 'interactive')
    assert(GitCommand.route_key({ 'help', 'log' }) == 'interactive')
    assert(GitCommand.route_key({ 'push' }) == 'interactive')
    assert(GitCommand.route_key({ 'fetch', '--all' }) == 'interactive')
    assert(GitCommand.route_key({ 'clone', 'url' }) == 'interactive')
  end)

  test('routes both surfaces through the default preset', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local harness = make_harness()
    assert(harness.run({ 'status', '--short' }) == 'process')
    assert(harness.run({ 'commit', '-m', 'x' }) == 'process')
    assert(harness.run({ 'add', '.' }) == 'process')
    assert(
      harness.run({ 'add', '-p' }) == 'terminal',
      'the invocation, not the subcommand, decides'
    )
    assert(harness.run({ 'log', '-1', '--oneline' }) == 'process')
    assert(harness.run({ 'diff' }) == 'process')
    assert(harness.run({ 'push' }) == 'terminal')
    assert(harness.run({ 'log', '-p' }) == 'terminal')
    assert(harness.run({}) == 'process')
  end)

  test('merges user routes over the defaults and can replace them entirely', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local merged = make_harness({ routes = { capture = 'terminal' } })
    assert(merged.run({ 'status' }) == 'terminal')
    assert(merged.run({ 'push' }) == 'terminal', 'untouched defaults must survive the merge')

    local replaced = make_harness({
      replace_routes = true,
      routes = { capture = 'terminal', interactive = 'process' },
    })
    assert(replaced.run({ 'status' }) == 'terminal')
    assert(replaced.run({ 'push' }) == 'process', 'replaced presets must not keep defaults')
  end)

  test('exposes a copy of the default preset and honours a custom fallback', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local preset = GitCommand.default_routes()
    assert(preset.capture == 'process')
    assert(preset.interactive == 'terminal')
    preset.capture = 'terminal'
    assert(GitCommand.default_routes().capture == 'process', 'the preset copy must be decoupled')
    assert(GitCommand.default_fallback == 'terminal')
    -- A key no preset names falls through: replacing the preset with only
    -- `capture` leaves `interactive` to the fallback.
    local incomplete = make_harness({
      replace_routes = true,
      routes = { capture = 'process' },
      fallback = 'process',
    })
    assert(incomplete.run({ 'push' }) == 'process')
  end)

  test('rejects malformed route definitions', function()
    local build = _G.cli_cmd_test.git_command
    local cwd = vim.fn.getcwd()
    assert(not pcall(build, { cwd = cwd, routes = 'status' }))
    assert(not pcall(build, { cwd = cwd, routes = { capture = 5 } }))
    assert(not pcall(build, { cwd = cwd, routes = { [''] = 'process' } }))
    assert(not pcall(build, { cwd = cwd, replace_routes = 'yes' }))
    local ok, err = pcall(build, { cwd = cwd, routes = { capture = '' } })
    assert(not ok)
    assert(tostring(err):find('route target must be a backend name or a function', 1, true))
  end)

  test('does not mutate argv and rejects malformed input', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local argv = { '-C', '/repo', 'status' }
    assert(GitCommand.subcommand(argv) == 'status')
    assert(GitCommand.route_key(argv) == 'capture')
    assert(vim.deep_equal(argv, { '-C', '/repo', 'status' }))
    local ok, err = pcall(GitCommand.subcommand, { '-C' })
    assert(not ok)
    assert(tostring(err):find('cli-cmd.tools.git.command:', 1, true))
  end)
end

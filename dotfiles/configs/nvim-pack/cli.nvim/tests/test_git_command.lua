return function(test)
  test('builds a Git command definition and routes native command arguments', function()
    local Git = require('cli.adapter.git')
    local seen
    local command = Git.new({
      cwd = vim.fn.getcwd(),
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { status = 'process', commit = 'process' },
      fallback = 'process',
    })
    command:register('CliGitProbe', { route_key = Git.route_key })
    vim.cmd([[execute 'CliGitProbe --no-pager -C . status']])
    assert(seen.executable == 'git')
    assert(vim.deep_equal(seen.argv, { '--no-pager', '-C', '.', 'status' }))
    assert(seen.route_key == 'status')
    assert(seen.raw_input == '--no-pager -C . status')
  end)

  test('preserves custom executable and environment configuration', function()
    local Git = require('cli.adapter.git')
    local command = Git.new({
      executable = '/usr/bin/git',
      cwd = vim.fn.getcwd(),
      env = { GIT_OPTIONAL_LOCKS = '0' },
      backends = {
        process = function(context, task)
          assert(context.executable == '/usr/bin/git')
          assert(context.env.GIT_OPTIONAL_LOCKS == '0')
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { status = 'process' },
      fallback = 'process',
    })
    command:register('CliGitConfigProbe', { route_key = Git.route_key })
    vim.cmd('CliGitConfigProbe status')
  end)

  test('combines the editor environment with an env function that returns nothing', function()
    local Git = require('cli.adapter.git')
    local Command = require('cli.command')
    local seen
    local command = Git.new({
      cwd = vim.fn.getcwd(),
      editor = {
        env = function()
          return { GIT_EDITOR = 'editor' }
        end,
      },
      -- An env function is allowed to return nothing; the editor variables must
      -- still arrive, and the function itself must never be treated as a table.
      env = function()
        return nil
      end,
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { commit = 'process' },
      fallback = 'process',
    })
    assert(command ~= nil)
    command:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'commit' })
    assert(seen.env.GIT_EDITOR == 'editor', vim.inspect(seen.env))
  end)

  test('runs real Git through the default preset: status notifies, log opens a terminal', function()
    local Git = require('cli.adapter.git')
    local Task = require('cli.task')
    local repo = _G.cli_test.temp_repo()
    _G.cli_test.stage(repo, 'tracked.txt', { 'first' })

    local messages = {}
    local presenter = require('cli.presenter.notify').new({
      notify = function(message, level)
        messages[#messages + 1] = { message = message, level = level }
      end,
    })
    local git = Git.new({ cwd = repo, presenter = presenter })

    local tabs_before = #vim.api.nvim_list_tabpages()
    local status = git:dispatch({
      argv = { 'status', '--short', '--branch' },
      raw_input = 'status --short --branch',
      route_key = Git.route_key({ 'status' }),
    })
    vim.wait(10000, function()
      return status:status() == 'finished'
    end, 20)
    assert(status:result().kind == 'exit' and status:result().code == 0)
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'status must not open a terminal')
    assert(#messages == 1, vim.inspect(messages))
    assert(messages[1].message:find('## ', 1, true), messages[1].message)

    local log = git:dispatch({
      argv = { 'log', '-1', '--oneline' },
      raw_input = 'log -1 --oneline',
      route_key = Git.route_key({ 'log' }),
    })
    vim.wait(10000, function()
      return log:status() == 'finished'
    end, 20)
    assert(log:result().kind == 'exit' and log:result().code == 0)
    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'log must open a terminal tab')
    assert(#messages == 1, 'terminal output must not be duplicated through notify')
    vim.cmd('tabclose!')
  end)

  test('requires a working directory and keeps Git errors namespaced', function()
    local Git = require('cli.adapter.git')
    local ok, err = pcall(Git.new, {})
    assert(not ok)
    assert(tostring(err):find('cli.git:', 1, true))
  end)
end

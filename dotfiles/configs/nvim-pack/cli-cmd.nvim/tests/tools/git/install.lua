return function(test)
  local Installer = require('cli-cmd.install')
  local cli = require('cli-cmd')

  ---`:exists()` treats a shorter name as an abbreviation, so compare exact names.
  local function installed(name)
    return vim.api.nvim_get_commands({})[name] ~= nil
  end

  local function fresh(opts)
    Installer.dispose('git')
    return cli.install('git', opts)
  end

  ---Backend double that records the Context it was asked to run.
  local function recorder(seen, name)
    return function(context, task)
      seen[#seen + 1] = { backend = name, context = context }
      task:finish({ kind = 'exit', code = 0 })
    end
  end

  test('installs :Git with the Git preset, the editor bridge and completion', function()
    local seen = {}
    fresh({
      cwd = vim.fn.getcwd(),
      backends = {
        process = recorder(seen, 'process'),
        terminal = recorder(seen, 'terminal'),
      },
    })

    assert(installed('Git'), 'the canonical name is the full word')
    assert(not installed('G'), ':G is Vim abbreviation, not a second command')
    vim.cmd('Git status --short')
    -- Another :G* command (:Glance, for instance) makes the abbreviation
    -- ambiguous, which is why the name is spelled out.
    vim.cmd('G rebase --interactive')
    assert(seen[1].backend == 'process', 'status stays off the terminal')
    assert(seen[2].backend == 'terminal', 'interactive subcommands get a real tty')
    assert(type(seen[1].context.env.GIT_EDITOR) == 'string')
    assert(seen[1].context.env.GIT_SEQUENCE_EDITOR == seen[1].context.env.GIT_EDITOR)
    Installer.dispose('git')
  end)

  test('renames the command and appends typed arguments to the preset', function()
    local seen = {}
    fresh({
      cwd = vim.fn.getcwd(),
      command = 'G',
      presets = {
        Gs = { argv = { 'status', '--porcelain' }, desc = 'status' },
      },
      backends = { process = recorder(seen, 'process') },
    })

    assert(installed('G') and installed('Gs') and not installed('Git'))
    vim.cmd('Gs --branch')
    assert(vim.deep_equal(seen[1].context.argv, { 'status', '--porcelain', '--branch' }))
    assert(seen[1].context.route_key == 'capture')
    Installer.dispose('git')
  end)

  test('leaves the environment alone when the editor is disabled', function()
    local seen = {}
    fresh({
      cwd = vim.fn.getcwd(),
      editor = false,
      backends = { process = recorder(seen, 'process') },
    })
    vim.cmd('G commit -m done')
    assert(seen[1].context.env == nil or seen[1].context.env.GIT_EDITOR == nil)
    Installer.dispose('git')
  end)

  test('replaces the previous tool of the same name and releases its editor', function()
    local first = fresh({ cwd = vim.fn.getcwd() })
    local bridge = first.editor
    assert(bridge ~= nil)
    assert(installed('Git'))

    local second = fresh({ cwd = vim.fn.getcwd(), command = 'G' })
    assert(second.editor ~= bridge, 'a re-install owns a fresh bridge')
    assert(bridge:active() == false, 'the replaced bridge must not keep sessions')
    assert(installed('G') and not installed('Git'))
    Installer.dispose('git')
    assert(not installed('G'))
  end)

  test('completes from Git in the repository the user is in', function()
    local repo = _G.cli_cmd_test.temp_repo()
    local original = vim.fn.getcwd()
    fresh({ cwd = repo })
    local ok, err = pcall(function()
      vim.cmd('cd ' .. vim.fn.fnameescape(repo))
      local candidates = vim.fn.getcompletion('G sta', 'cmdline')
      assert(vim.tbl_contains(candidates, 'stash'), vim.inspect(candidates))
      assert(vim.tbl_contains(candidates, 'status'), vim.inspect(candidates))
    end)
    vim.cmd('cd ' .. vim.fn.fnameescape(original))
    Installer.dispose('git')
    assert(ok, err)
  end)

  test('runs real Git through the installed command', function()
    local repo = _G.cli_cmd_test.temp_repo()
    _G.cli_cmd_test.stage(repo, 'staged.txt', { 'content' })
    local chunks = {}
    local collector = {
      attach = function(_, task)
        task:on(function(event)
          if event.kind == 'output' then
            chunks[#chunks + 1] = event.data
          end
        end)
      end,
    }
    fresh({ cwd = repo, presenter = collector })
    vim.cmd('G status --porcelain')
    vim.wait(10000, function()
      local output = table.concat(chunks, '')
      return output:find('staged.txt', 1, true) ~= nil
    end, 10)
    local output = table.concat(chunks, '')
    assert(output:find('staged.txt', 1, true), 'expected status output, got: ' .. output)
    Installer.dispose('git')
  end)
end

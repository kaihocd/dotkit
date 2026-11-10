---The external terminal protocol against the terminal manager that exists in this
---checkout: a command opens as a session in its UI, and the exit code it reports is
---the command's own.
return function(test)
  local Output = require('cli-cmd.presenter.output')

  ---`terminal.new` needs its UI and that UI is `popup.nvim`; both are siblings in
  ---`nvim-pack/` and neither is fetched.
  local function terminal_plugin()
    if not (cli_cmd_test.sibling('popup.nvim') and cli_cmd_test.sibling('terminal.nvim')) then
      test.skip('terminal.nvim and popup.nvim are not in this checkout')
    end
    local terminal = require('terminal')
    terminal.setup({})
    return terminal
  end

  ---Each case hands the manager back empty: its state is module-level by design.
  local function reset(terminal)
    for _, term in ipairs(require('terminal.state').terminals) do
      pcall(vim.fn.jobstop, term.job_id)
      if vim.api.nvim_buf_is_valid(term.buf) then
        pcall(vim.api.nvim_buf_delete, term.buf, { force = true })
      end
    end
    require('terminal.state').terminals = {}
    require('terminal.state').current_index = 1
    pcall(terminal.close)
  end

  ---A tool whose only job is to be routed to the terminal, with the capability that
  ---runs it there.
  local function install(terminal, messages, argv)
    local capability = {
      delegate = function(context, task)
        local index = terminal.new({
          command = { context.executable, unpack(context.argv) },
          cwd = context.cwd,
          env = context.env,
          name = 'probe',
          on_exit = function(code)
            task:finish({ kind = 'exit', code = code })
          end,
        })
        terminal.open()
        terminal.select(index)
        --The session is on screen, so the presenter stays out of it.
        task:annotate('surface', 'terminal')
        return { owns_result = true, index = index }
      end,
    }
    require('cli-cmd.install').dispose('probe')
    local tool = require('cli-cmd').define('probe', {
      executable = 'sh',
      route_key = function()
        return 'interactive'
      end,
      presets = { Probe = { argv = argv } },
      presenter = Output.new({
        notify = function(message, level)
          messages[#messages + 1] = { message = message, level = level }
        end,
        max_lines = 1000,
      }),
      terminal_capability = capability,
    })
    return tool
  end

  test('runs a command in the terminal UI and reports the real exit code', function()
    local terminal = terminal_plugin()
    local state = require('terminal.state')
    reset(terminal)
    local messages = {}
    install(terminal, messages, { '-c', 'printf probe-output; exit 5' })

    vim.cmd('Probe')

    vim.wait(10000, function()
      return state.count() == 1 and state.terminals[1].code ~= nil
    end, 10)
    assert(state.count() == 1, 'the command must be a session in the terminal list')
    assert(state.terminals[1].code == 5, vim.inspect(state.terminals[1]))
    local screen =
      table.concat(vim.api.nvim_buf_get_lines(state.terminals[1].buf, 0, -1, false), '\n')
    assert(screen:find('probe-output', 1, true), 'the output must be in the session: ' .. screen)
    assert(
      #messages == 0,
      'a visible session is not also a notification: ' .. vim.inspect(messages)
    )
    reset(terminal)
    require('cli-cmd.install').dispose('probe')
  end)

  test('keeps the session afterwards, so the result can be read again', function()
    local terminal = terminal_plugin()
    local state = require('terminal.state')
    reset(terminal)
    install(terminal, {}, { '-c', 'printf readable' })

    vim.cmd('Probe')
    vim.wait(10000, function()
      return state.terminals[1] and state.terminals[1].code ~= nil
    end, 10)

    assert(state.count() == 1, 'a finished command session must stay in the list')
    assert(state.terminals[1].name == 'probe')
    assert(vim.api.nvim_buf_is_valid(state.terminals[1].buf))
    reset(terminal)
    require('cli-cmd.install').dispose('probe')
  end)
end

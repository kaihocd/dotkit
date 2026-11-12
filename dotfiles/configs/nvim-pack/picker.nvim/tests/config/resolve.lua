local config = require('picker.config')
local options = require('picker.picker.options')
local presentation = require('picker.picker.presentation')

local function fails(body, pattern)
  local ok, problem = pcall(body)
  assert(not ok, 'expected a failure, got success')
  assert(
    tostring(problem):find(pattern, 1, true),
    ('expected %q in: %s'):format(pattern, tostring(problem))
  )
end

return function(test)
  test('resolves the picker defaults', function()
    config.setup({})
    local resolved = config.resolve('picker', {})
    assert(resolved.search.debounce_ms == 40, 'debounce default')
    assert(resolved.search.grep_page_size == 100, 'page size default')
    assert(resolved.preview.radius == 2, 'preview radius default')
    assert(resolved.view.layout.width_ratio == 0.75, 'layout ratio default')
    assert(resolved.view.presentation.marker.text == '▊', 'marker default')
    assert(resolved.keymaps.n['<CR>'] == 'confirm', 'normal-mode confirm mapping')
    assert(resolved.keymaps.i['<CR>'] == 'confirm', 'insert-mode confirm mapping')
  end)

  test('merges overrides without disturbing siblings', function()
    config.setup({ picker = { search = { debounce_ms = 5 } } })
    local resolved = config.resolve('picker', {})
    assert(resolved.search.debounce_ms == 5, 'override applied')
    assert(resolved.search.scan_poll_ms == 100, 'sibling keeps its default')
    config.setup({})
  end)

  test('accepts user keymaps that no default declares', function()
    config.setup({})
    local resolved = config.resolve('picker', { keymaps = { n = { ['<C-x>'] = 'next' } } })
    assert(resolved.keymaps.n['<C-x>'] == 'next', 'custom mapping is kept')
    assert(resolved.keymaps.i['<CR>'] == 'confirm', 'other modes keep their defaults')
  end)

  test('resolves the select defaults', function()
    config.setup({})
    local resolved = config.resolve('select', { view = { min_items = 2 } })
    assert(resolved.view.min_items == 2, 'override applied')
    assert(resolved.view.max_items == 8, 'sibling keeps its default')
    assert(resolved.view.prefix.text == ' Select ', 'prefix default')
  end)

  test('normalizes a layout declared as a function', function()
    config.setup({})
    local build = function() end
    local resolved = config.resolve('picker', { view = { layout = build } })
    assert(type(resolved.view.layout) == 'table', 'layout becomes a table')
    assert(resolved.view.layout.build == build, 'the function moves to build')
    assert(resolved.view.layout.width_ratio == 0.75, 'ratios survive normalization')
  end)

  test('rejects a setup option the schema does not declare', function()
    fails(function()
      config.setup({ picker = { nope = true } })
    end, 'unsupported option setup.picker.nope')
    config.setup({})
  end)

  test('rejects a view field the schema does not declare', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { view = { nope = true } })
    end, 'unsupported option picker.view.nope')
  end)

  test('rejects a retired view role with a migration hint', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { view = { preview = {} } })
    end, 'view.preview is no longer supported; use view.layout')
  end)

  test('rejects a select layout that is not a function', function()
    config.setup({})
    fails(function()
      config.resolve('select', { view = { layout = { width_ratio = 0.5 } } })
    end, 'select.view.layout must be a function')
  end)

  test('rejects a keymap mode Neovim does not define', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { keymaps = { zz = { ['<CR>'] = 'confirm' } } })
    end, 'keymaps mode must be a native Neovim mapping mode')
  end)

  test('rejects a sign ratio outside the unit interval', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { view = { signs = { staged_foreground_ratio = 2 } } })
    end, 'staged_foreground_ratio must be in [0, 1]')
  end)

  test('rejects a git marker wider than the reserved column', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { view = { signs = { git = { modified = { 'XXX', 'Changed' } } } } })
    end, 'git.modified must contain at most two display cells and a highlight')
  end)

  test('accepts the defaults when ambiwidth widens ambiguous glyphs', function()
    local previous = vim.o.ambiwidth
    vim.o.ambiwidth = 'double'
    local ok, problem = pcall(config.setup, {})
    local resolved_ok, resolved_problem = pcall(config.resolve, 'picker', {})
    vim.o.ambiwidth = previous

    assert(ok, tostring(problem))
    assert(resolved_ok, tostring(resolved_problem))
    config.setup({})
  end)

  test('keys the default prefix copy by mode', function()
    config.setup({})
    local resolved = config.resolve('picker', {})
    local text = resolved.view.presentation.prefix.text
    assert(type(text) == 'table', 'default copy is configuration data: ' .. vim.inspect(text))
    assert(text.files == ' Files ' and text.grep == ' Grep ', vim.inspect(text))
    assert(presentation.resolve(resolved.view.presentation, 'grep').prefix.text == ' Grep ', 'grep copy')
    assert(presentation.resolve(resolved.view.presentation, 'files').prefix.text == ' Files ', 'files copy')
  end)

  test('applies one prefix string to every mode', function()
    config.setup({ picker = { view = { presentation = { prefix = { text = ' Search ' } } } } })
    local resolved = config.resolve('picker', {})
    for _, mode in ipairs({ 'files', 'grep' }) do
      assert(
        presentation.resolve(resolved.view.presentation, mode).prefix.text == ' Search ',
        mode .. ' uses the single string'
      )
    end
    config.setup({})
  end)

  test('keeps the default for the mode a partial override omits', function()
    config.setup({ picker = { view = { presentation = { prefix = { text = { grep = ' G ' } } } } } })
    local resolved = config.resolve('picker', {})
    assert(presentation.resolve(resolved.view.presentation, 'grep').prefix.text == ' G ', 'grep override')
    assert(
      presentation.resolve(resolved.view.presentation, 'files').prefix.text == ' Files ',
      'files keeps its default'
    )
    config.setup({})
  end)

  test('rejects prefix copy that is neither a string nor a mode table', function()
    config.setup({})
    fails(function()
      config.resolve('picker', { view = { presentation = { prefix = { text = 5 } } } })
    end, 'must be a string or a { files, grep } table')
    fails(function()
      config.resolve('picker', { view = { presentation = { prefix = { text = { other = ' x ' } } } } })
    end, 'unsupported option picker.view.presentation.prefix.text.other')
    fails(function()
      config.resolve('picker', { view = { presentation = { prefix = { text = { grep = 'a\nb' } } } } })
    end, 'must be a single line without tabs')
  end)

  test('survives a snapshot round trip through presentation', function()
    config.setup({})
    local declared = config.resolve('picker', {})
    local restored = vim.deepcopy(declared.view.presentation)
    assert(type(restored.prefix.text) == 'table', 'snapshots stay declarative')
    assert(presentation.resolve(restored, 'grep').prefix.text == ' Grep ', 'rebuilds on resume')
  end)

  test('resolves an absolute working directory', function()
    config.setup({})
    local cwd = vim.fn.getcwd()
    local resolved = options.resolve({ cwd = cwd })
    assert(resolved.cwd == (vim.uv.fs_realpath(cwd) or cwd), 'cwd is canonical: ' .. resolved.cwd)
  end)

  test('rejects invocation options the public API does not define', function()
    config.setup({})
    fails(function()
      options.resolve({ nope = true })
    end, 'unsupported option: nope')
  end)

  test('rejects an unknown search mode', function()
    config.setup({})
    fails(function()
      options.resolve({ mode = 'symbols' })
    end, 'mode must be files or grep')
  end)

  test('rejects a non-function on_instance hook', function()
    config.setup({})
    fails(function()
      options.resolve({ on_instance = true })
    end, 'on_instance must be a function')
  end)
end

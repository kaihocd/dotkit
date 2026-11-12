-- End-to-end session tests: a real popup, real keymaps, an injected source.
--
-- The backend is the only thing swapped out; windows, buffers, wiring, model
-- updates and completion all run for real. Every test restores the window state
-- it found, because the remaining suites share this Neovim instance.

local config = require('picker.config')

local function entries()
  return {
    { path = '/tmp/a.txt', display = 'a.txt' },
    { path = '/tmp/b.txt', display = 'b.txt' },
    { path = '/tmp/c.txt', display = 'c.txt' },
  }
end

---@param overrides? { mode?: 'files'|'grep', search?: fun(query: string, size: integer, mode: string?): picker.picker.Page }
local function open(overrides)
  overrides = overrides or {}
  local invocation, settings = require('picker.picker.options').resolve({ mode = overrides.mode })
  local completed
  local panel = require('picker.picker.panel').new({
    source = { search = overrides.search or function()
      return { status = 'ready', items = entries(), total = #entries() }
    end },
    on_complete = function(entry, result)
      completed = { entry = entry, result = result }
    end,
    view = invocation.view,
    settings = settings,
    mode = overrides.mode,
  })
  panel:open()
  return panel, function()
    return completed
  end
end

local function keys(buffer)
  local installed = {}
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buffer, 'n')) do
    installed[mapping.lhs] = true
  end
  return installed
end

---Listeners this entry point creates, found the same way a user inspects them.
---@return integer
local function owned_listeners()
  local count = 0
  for _, event in ipairs({ 'WinEnter', 'ColorScheme', 'VimResized', 'TextChanged' }) do
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = event })) do
      if autocmd.desc and autocmd.desc:find('Picker', 1, true) then
        count = count + 1
      end
    end
  end
  return count
end

---@param panel picker.picker.PickerPanel
local function settle(panel)
  if not panel._closed then
    panel:close()
  end
  vim.wait(100, function()
    return panel.window.popup:root() == nil
  end)
  pcall(vim.cmd, 'stopinsert')
end

return function(test)
  test('opens with real panes and installs the configured mappings', function()
    config.setup({})
    local panel = open()
    local input = assert(panel.window:pane('input'), 'input pane is open')
    local list = assert(panel.window:pane('list'), 'list pane is open')
    assert(vim.bo[input.buf].buftype == 'prompt', 'input pane is a prompt buffer')
    assert(vim.api.nvim_buf_line_count(list.buf) > 0, 'list pane has rows')

    local installed = keys(input.buf)
    assert(installed['<CR>'], 'confirm is mapped')
    assert(installed['<C-k>'] or installed['<Up>'], 'move is mapped')

    assert(#panel.selection:entries() == 3, 'entries reached the model')
    assert(panel.selection:current_index() == 1, 'first entry selected')
    settle(panel)
    assert(#vim.api.nvim_list_wins() == 1, 'no popup windows survive the session')
  end)

  test('marks and movement stay model-owned', function()
    config.setup({})
    local panel = open()
    panel:mark(1)
    assert(panel.selection:marked_count() == 1, 'mark recorded')
    assert(panel.selection:current_index() == 2, 'mark advanced the selection')
    panel:move(-1)
    assert(panel.selection:current_index() == 1, 'move walked back')
    assert(panel.selection:marked_count() == 1, 'movement does not change marks')
    panel:mark(-1)
    assert(panel.selection:marked_count() == 0, 'marking again clears it')
    settle(panel)
  end)

  test('a bound key reaches the model through the error boundary', function()
    config.setup({})
    local panel = open()
    local input = assert(panel.window:pane('input'), 'input pane is open')
    assert(vim.api.nvim_get_current_buf() == input.buf, 'input pane takes focus')

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'x', false)
    assert(panel.selection:marked_count() == 1, '<Tab> ran mark_next')
    assert(panel.selection:current_index() == 2, '<Tab> advanced the selection')

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<S-Tab>', true, false, true), 'x', false)
    assert(panel.selection:marked_count() == 2, '<S-Tab> ran mark_previous')
    assert(panel.selection:current_index() == 1, '<S-Tab> walked back')
    settle(panel)
  end)

  test('a closed session leaves no editor listeners behind', function()
    config.setup({})
    local panel = open()
    assert(owned_listeners() > 0, 'the open session registered listeners')
    settle(panel)
    assert(owned_listeners() == 0, 'no listener survives the session')
  end)

  test('confirm completes with the current entry and closes once', function()
    config.setup({})
    local panel, completed = open()
    panel:confirm()
    vim.wait(200, function()
      return completed() ~= nil
    end)
    local result = assert(completed(), 'completion ran')
    assert(result.entry.path == '/tmp/a.txt', result.entry.path)
    assert(result.result.mode == 'edit', 'default open mode')
    assert(#result.result.entries == 1, 'completion carries one entry')
    assert(panel._closed, 'session is closed before completion returned')

    local counts = 0
    local original = panel._complete
    panel._complete = function(...)
      counts = counts + 1
      return original(...)
    end
    panel:close()
    vim.wait(50)
    assert(counts == 0, 'closing twice cannot complete twice')
    settle(panel)
  end)

  test('quickfix completes with marks, falling back to the current entry', function()
    config.setup({})
    local panel, completed = open()
    panel:quickfix()
    vim.wait(200, function()
      return completed() ~= nil
    end)
    local result = assert(completed(), 'completion ran')
    assert(result.result.mode == 'quickfix', result.result.mode)
    assert(#result.result.entries == 1, 'unmarked selection falls back')

    local panel2, completed2 = open()
    panel2:mark(1)
    panel2:mark(1)
    panel2:quickfix()
    vim.wait(200, function()
      return completed2() ~= nil
    end)
    local marked = assert(completed2(), 'completion ran')
    assert(#marked.result.entries == 2, 'both marks completed: ' .. #marked.result.entries)
    settle(panel)
    settle(panel2)
  end)

  test('grep sessions search with a match mode and can cycle it', function()
    config.setup({})
    local modes = {}
    local panel = open({
      mode = 'grep',
      search = function(_, _, mode)
        modes[#modes + 1] = mode
        return { status = 'ready', items = entries(), total = 3 }
      end,
    })
    assert(panel._grep, 'grep flag follows the mode')
    assert(panel.window._mode == 'grep', 'window knows the mode without re-rendering')
    assert(panel.window._presentation.prefix.text == ' Grep ', panel.window._presentation.prefix.text)
    assert(modes[1] == 'plain', 'first search uses the default match mode: ' .. tostring(modes[1]))
    panel:cycle_match_mode()
    assert(modes[#modes] == 'regex', 'cycling searches again with the next mode: ' .. tostring(modes[#modes]))
    settle(panel)
  end)

  test('a closing session hands focus back and stays closed', function()
    config.setup({})
    local origin = vim.api.nvim_get_current_win()
    local panel = open()
    assert(vim.api.nvim_get_current_win() ~= origin, 'opening moved focus into the popup')
    panel:close()
    vim.wait(100, function()
      return vim.api.nvim_get_current_win() == origin
    end)
    assert(vim.api.nvim_get_current_win() == origin, 'focus returned to the origin window')
    assert(panel._closed, 'closed')
    panel:open()
    assert(panel._closed, 'a closed session cannot reopen')
    settle(panel)
  end)
end

-- End-to-end Select sessions: real popup, real prompt buffer, real bindings.
--
-- SelectWindow owns four buffers and a caller-supplied layout, so these tests
-- are the only place where prompt painting, row rendering, detail mounting and
-- completion are exercised together. Each test restores the window state it
-- found, because the remaining suites share this Neovim instance.

local config = require('picker.config')

local items = { 'alpha', 'beta', 'gamma', 'delta' }

---@param overrides? { items?: any[], prompt?: string }
local function open(overrides)
  overrides = overrides or {}
  local completed
  local panel = assert(require('picker.select.panel').new(overrides.items or items, {
    prompt = overrides.prompt or 'Pick one',
  }, function(item, index)
    completed = { item = item, index = index }
  end))
  panel:open()
  return panel, function()
    return completed
  end
end

---@param panel picker.select.SelectPanel
local function settle(panel)
  if panel and not panel._closed then
    panel:close()
  end
  if panel then
    vim.wait(100, function()
      return panel.window.popup:root() == nil
    end)
  end
  pcall(vim.cmd, 'stopinsert')
end

---Listeners this entry point creates, found the same way a user inspects them.
---@return integer
local function owned_listeners()
  local count = 0
  for _, event in ipairs({ 'WinEnter', 'VimResized', 'TextChanged' }) do
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = event })) do
      if autocmd.desc and autocmd.desc:find('Select', 1, true) then
        count = count + 1
      end
    end
  end
  return count
end

local function lines(pane)
  return vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
end

return function(test)
  test('opens with the prompt painted and one row per item', function()
    config.setup({})
    local panel = open()
    local prompt = assert(panel.window:pane('prompt'), 'prompt pane is open')
    local list = assert(panel.window:pane('list'), 'list pane is open')
    local input = assert(panel.window:pane('input'), 'input pane is open')

    assert(table.concat(lines(prompt), '\n') == 'Pick one', table.concat(lines(prompt), '|'))
    assert(#lines(list) == #items, 'one row per item: ' .. #lines(list))
    assert(vim.bo[input.buf].buftype == 'prompt', 'input is a prompt buffer')
    assert(vim.bo[input.buf].filetype == 'picker-select-input', vim.bo[input.buf].filetype)
    assert(vim.bo[list.buf].filetype == 'picker-select', vim.bo[list.buf].filetype)
    assert(panel.window:query() == '', 'query starts empty')
    settle(panel)
  end)

  test('moving repaints the current row without touching the query', function()
    config.setup({})
    local panel = open()
    assert(panel.list:current_index() == 1, 'first row selected')
    panel:move(1)
    assert(panel.list:current_index() == 2, 'moved to the second row')
    panel:move(-1)
    assert(panel.list:current_index() == 1, 'moved back')
    assert(panel.window:query() == '', 'query unchanged by movement')
    settle(panel)
  end)

  test('typing filters the rows through the model', function()
    config.setup({})
    local panel = open()
    local input = assert(panel.window:pane('input'))
    vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { 'et' })
    panel:refresh()
    local remaining = panel.list:entries()
    assert(#remaining == 1, 'only beta contains "et": ' .. #remaining)
    assert(remaining[1].text:find('beta', 1, true), tostring(remaining[1].text))
    local list = assert(panel.window:pane('list'))
    assert(#lines(list) == 1, 'rendered rows follow the model: ' .. #lines(list))
    settle(panel)
  end)

  test('detail mounts, paints and unmounts', function()
    config.setup({})
    -- Detail only appears for a row that does not fit the list pane.
    local long = string.rep('wide ', 60)
    local panel = open({ items = { long, 'beta' }, prompt = 'Explain' })
    assert(not panel.window:detail_active(), 'detail starts closed')
    assert(panel.window:pane('detail') == nil, 'no detail pane before toggling')
    assert(panel.window:clipped(panel.list:entries()[1].text), 'row is clipped')

    panel:toggle_detail()
    assert(panel.window:detail_active(), 'detail is active')
    local detail = assert(panel.window:pane('detail'), 'detail pane mounted')
    assert(#lines(detail) > 0, 'detail has content')

    panel:leave_detail()
    assert(not panel.window:detail_active(), 'detail is closed again')
    assert(panel.window:pane('detail') == nil, 'detail pane unmounted')
    settle(panel)
  end)

  test('confirm completes with the current item and closes once', function()
    config.setup({})
    local panel, completed = open()
    panel:move(1)
    panel:confirm()
    vim.wait(200, function()
      return completed() ~= nil
    end)
    local result = assert(completed(), 'completion ran')
    assert(result.item == 'beta', tostring(result.item))
    assert(result.index == 2, tostring(result.index))
    assert(panel._closed, 'session closed before completion returned')

    local calls = 0
    local original = panel._complete
    panel._complete = function(...)
      calls = calls + 1
      return original(...)
    end
    panel:close()
    vim.wait(50)
    assert(calls == 0, 'closing twice cannot complete twice')
    settle(panel)
  end)

  test('closing hands focus back to the origin window', function()
    config.setup({})
    local origin = vim.api.nvim_get_current_win()
    local panel = open()
    assert(vim.api.nvim_get_current_win() ~= origin, 'opening moved focus into the popup')
    assert(panel.window:focused(true), 'popup owns focus')

    panel:close()
    vim.wait(100, function()
      return vim.api.nvim_get_current_win() == origin
    end)
    assert(vim.api.nvim_get_current_win() == origin, 'focus returned')
    assert(not panel.window:focused(true), 'window reports no focus after closing')
    settle(panel)
    assert(#vim.api.nvim_list_wins() == 1, 'no popup windows survive')
  end)
  test('a closed session leaves no editor listeners behind', function()
    config.setup({})
    local panel = open()
    assert(owned_listeners() > 0, 'the open session registered listeners')
    settle(panel)
    assert(owned_listeners() == 0, 'no listener survives the session')
  end)
end

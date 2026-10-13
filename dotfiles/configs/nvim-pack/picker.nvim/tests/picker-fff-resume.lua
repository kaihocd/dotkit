-- Opt-in real continuation replay; no personal configuration or backend UI.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
vim.opt.runtimepath:prepend(assert(vim.env.FFF_NVIM_PATH, 'Set FFF_NVIM_PATH'))
vim.o.columns = 180
vim.o.lines = 45
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
for file = 1, 7 do
  local lines = {}
  for line = 1, 40 do
    lines[line] = '-- resume_deep_probe ' .. line
  end
  vim.fn.writefile(lines, root .. '/fixture' .. file .. '.lua')
end
local ok, problem = pcall(function()
  require('picker').setup()
  local backend = require('picker.picker.backend.fff')
  local Search = require('picker.picker.list.pages')
  local Restore = require('picker.picker.list.restore')
  local original = Search.new(backend.grep(root), true)
  local page
  local preceding = 0
  assert(vim.wait(15000, function()
    page = original:refresh('resume_deep_probe', 'plain', 100, true)
    return page.status == 'ready' and #page.items >= 100
  end, 50))
  for _ = 1, 2 do
    preceding = preceding + #page.items
    assert(original:move(#page.items, 1))
    page = original:refresh('resume_deep_probe', 'plain', 100, true)
    assert(page.status == 'ready')
  end
  local expected = assert(page.items[5])
  original:close()
  local snapshot = {
    options = { mode = 'grep', cwd = root },
    query = 'resume_deep_probe',
    match_mode = 'plain',
    preview = false,
    page = 2,
    size = 100,
    index = 5,
    current = {
      path = expected.path,
      display = expected.display,
      line = expected.line,
      col = expected.col,
    },
    marks = {},
  }
  local fresh = Search.new(backend.grep(root), true)
  local restore = Restore.new(snapshot, 10)
  local done, fallback, target
  assert(vim.wait(15000, function()
    page, target, done, fallback = restore:step(fresh, 100)
    return done
  end, 10))
  assert(not fallback and fresh:position() == 2)
  local actual = assert(page.items[target])
  assert(
    actual.path == expected.path and actual.line == expected.line and actual.col == expected.col
  )
  fresh:close()

  local picker = require('picker')
  picker.open({
    cwd = root,
    mode = 'grep',
    view = { icon = false },
    keymaps = { i = {
      ['<F6>'] = function(actions)
        actions.mark(0)
      end,
    } },
  })
  local input = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(input, 0, -1, false, { snapshot.query })
  vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input })
  local function selected_location()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if buf ~= vim.api.nvim_get_current_buf() then
        local rows = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local row = vim.api.nvim_win_get_cursor(win)[1]
        local line, col = (rows[row] or ''):match(':(%d+):(%d+)')
        if line then
          for heading = row - 1, 1, -1 do
            local name = rows[heading]:match('(fixture%d+%.lua)')
            if name then
              return name, tonumber(line), tonumber(col) - 1
            end
          end
        end
      end
    end
  end
  assert(vim.wait(15000, function()
    return selected_location() ~= nil
  end, 50))
  for _ = 1, preceding + 4 do
    vim.fn.maparg('<C-n>', 'i', false, true).callback()
  end
  local name, line, col = selected_location()
  assert(name == vim.fs.basename(expected.path) and line == expected.line and col == expected.col)
  vim.fn.maparg('<F6>', 'i', false, true).callback()
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
  picker.resume()
  assert(vim.api.nvim_get_current_line() == snapshot.query)
  assert(vim.wait(15000, function()
    local resumed_name, resumed_line, resumed_col = selected_location()
    return resumed_name == name and resumed_line == line and resumed_col == col
  end, 10))
  local status = vim.api.nvim_buf_get_extmarks(
    0,
    vim.api.nvim_get_namespaces().PickerStatus,
    0,
    -1,
    { details = true }
  )
  assert(status[1][4].virt_text[1][1]:find('1 selected', 1, true))
  vim.fn.maparg('<CR>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
  assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(expected.path))
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { expected.line, expected.col }))
end)
vim.fn.delete(root, 'rf')
if not ok then
  error(problem)
end
print('PASS real fff resume rebuilds three-page continuation and restores exact location')

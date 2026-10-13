-- Opt-in real backend test; never included in the dependency-free test suite.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local fff = vim.env.FFF_NVIM_PATH
if not fff or fff == '' then
  error('Set FFF_NVIM_PATH to the installed fff plugin root')
end
vim.opt.runtimepath:prepend(fff)
vim.o.columns = 180
vim.o.lines = 45
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local path = root .. '/fixture.lua'
vim.fn.writefile({ 'local value = 1', '-- picker_unique_grep_probe [', 'return value' }, path)
local function wait_for(predicate)
  assert(vim.wait(15000, predicate, 50), 'real fff integration timed out')
end
local ok, problem = pcall(function()
  require('picker').setup()
  require('picker').open({ cwd = root, mode = 'grep', view = { icon = false } })
  local input = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(input, 0, -1, false, { 'picker_unique_grep_probe' })
  vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input })
  local list
  wait_for(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if buf ~= input then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if
          #lines == 2
          and lines[1]:find('fixture.lua', 1, true)
          and lines[2]:find('picker_unique_grep_probe', 1, true)
        then
          list = win
          return true
        end
      end
    end
    return false
  end)
  assert(list and vim.api.nvim_win_get_cursor(list)[1] == 2)
  local input_win = vim.api.nvim_get_current_win()
  local function query(text)
    vim.api.nvim_buf_set_lines(input, 0, -1, false, { text })
    vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input })
  end
  local function cycle(mode)
    vim.fn.maparg('<C-l>', 'i', false, true).callback()
    assert(vim.api.nvim_get_current_win() == input_win)
    local status = vim.api.nvim_buf_get_extmarks(
      input,
      vim.api.nvim_get_namespaces().PickerStatus,
      0,
      -1,
      { details = true }
    )
    assert(status[1][4].virt_text[1][1]:find(mode .. ' · 1', 1, true))
    local rows = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(list), 0, -1, false)
    assert(#rows == 2 and rows[2]:find('picker_unique_grep_probe', 1, true))
  end
  query('^-- picker_unique_.*probe')
  cycle('regex')
  -- The real backend falls back to a literal search for incomplete regex input.
  query('[')
  vim.fn.maparg('<C-l>', 'i', false, true).callback() -- fuzzy
  cycle('plain')
  cycle('regex')
  local fallback = require('fff').content_search('[', { mode = 'regex', wait_for_index_ms = 0 })
  assert(fallback.regex_fallback_error and #fallback.items == 1)
  query('pckr_unqe_grp_prbe')
  cycle('fuzzy')
  query('picker_unique_grep_probe')
  cycle('plain')
  assert(vim.fn.maparg('<C-r>', 'i') == '')
  vim.fn.maparg('<C-o>', 'i', false, true).callback()
  local preview
  wait_for(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
      if #lines == 3 and lines[1] == 'local value = 1' then
        preview = win
        return true
      end
    end
    return false
  end)
  assert(preview and vim.api.nvim_win_get_cursor(preview)[1] == 2)
  local hits = vim.api.nvim_buf_get_extmarks(
    vim.api.nvim_win_get_buf(preview),
    vim.api.nvim_get_namespaces().PickerPreviewMatches,
    0,
    -1,
    { details = true }
  )
  assert(#hits == 1 and hits[1][2] == 1 and hits[1][3] == 3)
  assert(hits[1][4].end_col == 3 + #'picker_unique_grep_probe')
  assert(vim.wo[preview].number and vim.api.nvim_get_current_win() == input_win)
  cycle('regex')
  vim.fn.maparg('<Tab>', 'i', false, true).callback()
  vim.fn.maparg('<CR>', 'i', false, true).callback()
  wait_for(function()
    return #vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() ~= input
  end)
  assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(path))
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
  require('picker').resume()
  local resumed = vim.api.nvim_get_current_buf()
  assert(resumed ~= input and vim.api.nvim_get_current_line() == 'picker_unique_grep_probe')
  wait_for(function()
    local status = vim.api.nvim_buf_get_extmarks(
      resumed,
      vim.api.nvim_get_namespaces().PickerStatus,
      0,
      -1,
      { details = true }
    )
    return #status == 1 and status[1][4].virt_text[1][1] == 'regex · 1 · 1 selected '
  end)
  wait_for(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ranges = vim.api.nvim_buf_get_extmarks(
        buf,
        vim.api.nvim_get_namespaces().PickerPreviewMatches,
        0,
        -1,
        { details = true }
      )
      if #ranges == 1 and ranges[1][2] == 1 and ranges[1][3] == 3 then
        assert(vim.api.nvim_win_get_cursor(win)[1] == 2 and vim.wo[win].number)
        return true
      end
    end
    return false
  end)
  assert(vim.api.nvim_get_current_buf() == resumed)
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  wait_for(function()
    return #vim.api.nvim_list_wins() == 1
  end)
end)
vim.fn.delete(root, 'rf')
if not ok then
  error(problem)
end
print('PASS real fff public grep, grouped result, preview location and cleanup-before-open')

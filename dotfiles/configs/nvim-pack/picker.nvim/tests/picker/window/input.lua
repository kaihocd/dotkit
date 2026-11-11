local input = require('picker.picker.window.input')

local function pane(lines, cursor)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = 2,
    col = 2,
    width = 40,
    height = 1,
  })
  if cursor then
    vim.api.nvim_win_set_cursor(win, cursor)
  end
  return { buf = buf, win = win }
end

local function close(handle)
  pcall(vim.api.nvim_win_close, handle.win, true)
  pcall(vim.api.nvim_buf_delete, handle.buf, { force = true })
end

---@param handle {buf: integer, win: integer}
---@return string[]
local function lines_of(handle)
  return vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)
end

return function(test)
  test('leaves a single-line query untouched', function()
    local handle = pane({ 'Guard' }, { 1, 5 })
    assert(input.one_line(handle) == false, 'a single line is already the expected shape')
    assert(vim.deep_equal(lines_of(handle), { 'Guard' }), 'the line must not be rewritten')
    close(handle)
  end)

  test('joins a pasted multiline register into the one query line', function()
    -- Shape of `yy` + <C-r>": the yanked line, then the empty tail of the linewise register.
    local handle = pane({ 'Guard# Agent instructions', '' }, { 2, 0 })
    assert(input.one_line(handle) == true, 'two lines are not a query')
    assert(
      vim.deep_equal(lines_of(handle), { 'Guard# Agent instructions' }),
      'the whole paste stays searchable instead of hiding below the viewport'
    )
    close(handle)
  end)

  test('keeps the cursor after the pasted text', function()
    local handle = pane({ 'Guard', 'second' }, { 2, 6 })
    input.one_line(handle)
    assert(vim.deep_equal(lines_of(handle), { 'Guard second' }), 'the paste is joined with a space')
    local cursor = vim.api.nvim_win_get_cursor(handle.win)
    assert(cursor[1] == 1, 'the cursor belongs to the only line')
    -- Normal mode cannot rest on the byte past the last character, so the joined
    -- row stops at 'd'; inside the pane's insert mode the same request keeps col 12.
    assert(cursor[2] == 11, 'the cursor stays after the pasted text, got col ' .. cursor[2])
    close(handle)
  end)

  test('drops the trailing blank line a linewise register carries', function()
    local handle = pane({ 'Guard', '' }, { 2, 0 })
    input.one_line(handle)
    assert(vim.deep_equal(lines_of(handle), { 'Guard' }), 'no trailing space is left in the query')
    close(handle)
  end)
end

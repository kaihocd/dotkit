-- Row building is now the only place a session's rows get formatted, so these
-- cases pin the text a session shows when it does not supply a formatter.

local content = require('picker.content')
local list_view = require('picker.picker.window.list')

local files_entries = {
  { path = '/tmp/target.txt', display = 'target.txt', git_status = 'modified' },
  { path = '/tmp/other.txt', display = 'other.txt' },
}

local grep_entries = {
  { path = '/tmp/target.txt', display = 'target.txt', git_status = 'modified' },
  { path = '/tmp/target.txt', display = 'target.txt', line = 12, col = 3, content = '  local function named()' },
}

---@param mode 'files'|'grep'
---@param overrides? table
local function build(mode, overrides)
  return list_view.build(vim.tbl_extend('force', {
    mode = mode,
    width = 40,
    entries = files_entries,
    icon = function()
      return '', nil
    end,
    match = 'fun',
    empty_text = 'empty',
  }, overrides or {}))
end

---@param built picker.picker.ListBuild
---@return string[]
local function texts(built)
  local result = {}
  for index, row in ipairs(built.rows) do
    result[index] = content.project(row)
  end
  return result
end

return function(test)
  test('files rows show one display path per entry', function()
    local built = build('files')
    assert(vim.deep_equal(texts(built), { 'target.txt', 'other.txt' }), vim.inspect(texts(built)))
    assert(vim.deep_equal(built.entry_rows, { 1, 2 }), vim.inspect(built.entry_rows))
  end)

  test('grep rows add a file row per path change and a location row per match', function()
    local built = build('grep', { entries = grep_entries })
    assert(
      vim.deep_equal(texts(built), { 'target.txt', ':1:1  ', ':12:4    local function named()' }),
      vim.inspect(texts(built))
    )
    assert(vim.deep_equal(built.entry_rows, { 2, 3 }), vim.inspect(built.entry_rows))
    assert(built.row_entries[1] == nil, 'the shared file row is not a selectable entry')
    assert(built.row_entries[2] == 1 and built.row_entries[3] == 2, vim.inspect(built.row_entries))
  end)

  test('a supplied formatter wins over the built-in one', function()
    local built = build('files', {
      format = function(_, _)
        return content.from_ranges('custom', {})
      end,
    })
    assert(texts(built)[1] == 'custom', texts(built)[1])
  end)

  test('an empty result renders the caller-supplied placeholder', function()
    local built = build('files', { entries = {} })
    assert(vim.deep_equal(texts(built), { 'empty' }), vim.inspect(texts(built)))
  end)
end

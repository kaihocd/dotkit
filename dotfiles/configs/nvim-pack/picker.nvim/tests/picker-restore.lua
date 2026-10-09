vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local Restore = require('picker.picker.list.restore')
local Search = require('picker.picker.list.pages')
local function saved(mode, page)
  return {
    options = { mode = mode },
    query = 'query',
    match_mode = 'regex',
    preview = false,
    page = page,
    size = 5,
    index = 3,
    marks = {},
  }
end
local offsets = {}
local ready = false
local search = Search.new({
  search = function(query, _, mode, offset)
    assert(query == 'query' and mode == 'regex')
    offsets[#offsets + 1] = offset
    if not ready then
      return { status = 'indexing', total = 0, items = {} }
    end
    return {
      status = 'ready',
      total = 1,
      more = true,
      next_offset = offset + 17,
      items = { { path = '/' .. offset, display = tostring(offset) } },
    }
  end,
}, true)
local restore = Restore.new(saved('grep', 2))
local result, _, done = restore:step(search, 100)
assert(result.status == 'indexing' and not done)
ready = true
for _ = 1, 3 do
  result, _, done = restore:step(search, 100)
end
assert(done and result.items[1].path == '/34')
assert(vim.deep_equal(offsets, { 0, 0, 17, 34 }))
local calls = 0
local files = Search.new({
  search = function(_, size, _, page)
    calls = calls + 1
    assert(size == 2 and page == (calls == 1 and 0 or 8))
    return {
      status = 'ready',
      total = 20,
      items = { { path = '/a', display = 'a' }, { path = '/b', display = 'b' } },
    }
  end,
}, false)
local task = Restore.new(saved('files', 3))
local _, _, finished = task:step(files, 2)
assert(not finished and calls == 1)
local _, target = task:step(files, 2)
assert(files:position() == 8 and target == 2 and calls == 2)
local bounded = Restore.new(saved('grep', 1000))
local fresh = Search.new({
  search = function()
    return { status = 'ready', total = 0, items = {} }
  end,
}, true)
local _, _, complete, fallback = bounded:step(fresh, 100)
assert(complete and fallback and fresh:position() == 0)
print(
  'PASS bounded resume re-search uses fresh offsets, retries indexing and translates file positions'
)

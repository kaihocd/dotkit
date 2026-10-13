package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
require('picker').setup()
local Search = require('picker.picker.list.pages')
local passed = 0
local function test(name, run)
  run()
  passed = passed + 1
  print('PASS ' .. name)
end

local calls = 0
---@type picker.picker.PageSource
local files = {
  search = function(_, size, _, page)
    calls = calls + 1
    local items = {}
    for index = page * size + 1, math.min(23, (page + 1) * size) do
      items[#items + 1] = { path = '/' .. index, display = tostring(index) }
    end
    return { status = 'ready', items = items, total = 23 }
  end,
}

test('files cross pages, clamp the final page and reuse cached pages', function()
  local search = Search.new(files, false)
  search:refresh('', nil, 5)
  local changed, target = search:move(5, 1)
  assert(changed and target == 1)
  local page, selected = search:refresh('', nil, 5, true)
  assert(page.items[1].path == '/6' and selected == 1)
  assert(search:move(1, -1))
  local before = calls
  page, selected = search:refresh('', nil, 5, true)
  assert(calls == before and selected == 5 and page.items[5].path == '/5')
  assert(search:move(5, 100))
  page, selected = search:refresh('', nil, 5, true)
  assert(#page.items == 3 and selected == 3)
  assert(not search:move(3, 1))
end)

test('resize preserves the logical file and a new query resets the page', function()
  local search = Search.new(files, false)
  search:refresh('', nil, 5)
  search:move(1, 12)
  search:refresh('', nil, 5, true)
  assert(search:resize(4, 3) == 1)
  local page, target = search:refresh('', nil, 4, true)
  assert(target == 1 and page.items[1].path == '/13')
  page, target = search:refresh('new', nil, 4)
  assert(target == nil and page.items[1].path == '/1')
end)

test('prefetch warms adjacent pages and stale or closed work does nothing', function()
  local search = Search.new(files, false)
  search:refresh('', nil, 5)
  search:prefetch()()
  search:move(5, 1)
  local before = calls
  search:refresh('', nil, 5, true)
  assert(calls == before)
  local stale = search:prefetch()
  search:move(5, 1)
  stale()
  assert(calls == before)
  local closed = search:prefetch()
  search:close()
  closed()
  search:refresh('', nil, 5)
  assert(calls == before and not search:move(1, 1))
end)

test('three-page capacity evicts the least recently used page', function()
  local search = Search.new(files, false)
  search:refresh('', nil, 5)
  for _ = 1, 3 do
    search:move(5, 1)
    search:refresh('', nil, 5, true)
  end
  search:move(1, -15)
  local before = calls
  local page = search:refresh('', nil, 5, true)
  assert(calls == before + 1 and page.items[1].path == '/1')
end)

test('grep uses continuation offsets and restores the previous page last item', function()
  local positions = {}
  local indexing = false
  ---@type picker.picker.PageSource
  local source = {
    search = function(_, _, _, offset)
      positions[#positions + 1] = offset
      if indexing then
        return { status = 'indexing', items = {}, total = 0 }
      end
      return {
        status = 'ready',
        total = 2,
        more = offset == 0,
        next_offset = offset == 0 and 37 or 0,
        items = {
          { path = '/a', display = 'a', line = offset + 1 },
          { path = '/a', display = 'a', line = offset + 2 },
        },
      }
    end,
  }
  local search = Search.new(source, true)
  search:refresh('q', 'plain', 100)
  assert(search:move(2, 1))
  indexing = true
  local page, target = search:refresh('q', 'plain', 100, true)
  assert(page.status == 'indexing' and target == nil)
  indexing = false
  page, target = search:refresh('q', 'plain', 100)
  assert(positions[#positions] == 37 and target == 1)
  assert(not search:move(2, 1))
  assert(search:move(1, -1))
  page, target = search:refresh('q', 'plain', 100, true)
  assert(target == 2 and page.items[1].line == 1)
  search:refresh('q', 'regex', 100)
  assert(positions[#positions] == 0)
  assert(search:resize(5, 1) == nil)
end)

test('speculative failures are ignored but foreground errors propagate', function()
  ---@type picker.picker.PageSource
  local source = {
    search = function(_, _, _, page)
      if page > 0 then
        error('backend failed')
      end
      return files.search('', 5, nil, 0)
    end,
  }
  local search = Search.new(source, false)
  search:refresh('', nil, 5)
  search:prefetch()()
  search:move(5, 1)
  assert(not pcall(search.refresh, search, '', nil, 5, true))
end)

test('indexing retries retain the pending page target and deliver it once', function()
  local ready = true
  local search = Search.new({
    search = function(_, size, _, page)
      if not ready then
        return { status = 'indexing', total = 12, items = {} }
      end
      local items = {}
      for index = 1, size do
        items[index] = { path = '/' .. (page * size + index), display = tostring(index) }
      end
      return { status = 'ready', total = 12, items = items }
    end,
  }, false)
  search:refresh('query', nil, 3)
  assert(search:move(3, 2))
  ready = false
  for _ = 1, 2 do
    local result, target = search:refresh('query', nil, 3, true)
    assert(result.status == 'indexing' and target == nil)
  end
  ready = true
  local result, target = search:refresh('query', nil, 3, true)
  assert(target == 2 and result.items[target].path == '/5')
  local _, consumed = search:refresh('query', nil, 3, true)
  assert(consumed == nil)
  search:close()
end)

print('Passed ' .. passed .. ' tests')

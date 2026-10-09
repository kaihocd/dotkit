local pages_module = require('plugins.explorer.picker.search')
local calls = {}
local source = {
  search = function(query, size, mode, offset)
    calls[#calls + 1] = { query, size, mode, offset }
    return { status = 'ready', items = {}, total = 100, more = offset == 0, next_offset = 17 }
  end,
}
local pages = pages_module.new(source, true)
pages.refresh('one', 'plain', 100)
assert(calls[1][4] == 0)
assert(pages.move(1, 1))
pages.refresh('one', 'plain', 100, true)
assert(calls[2][4] == 17)
assert(not pages.move(1, 1))
assert(pages.move(1, -1))
pages.refresh('one', 'plain', 100, true)
assert(#calls == 2)
pages.refresh('one', 'regex', 100, true)
assert(calls[3][3] == 'regex' and calls[3][4] == 0)
pages.refresh('two', 'regex', 100, true)
assert(calls[4][1] == 'two' and calls[4][4] == 0)
pages.close()

calls = {}
pages = pages_module.new(source, false)
pages.refresh('files', nil, 10)
local changed, row = pages.move(10, 1)
assert(changed and row == 1)
pages.refresh('files', nil, 10, true)
assert(calls[2][3] == 1)
assert(pages.resize(6, 3) == 1)
pages.refresh('files', nil, 6, true)
assert(calls[3][2] == 6 and calls[3][3] == 2)
local stale = pages.prefetch()
pages.refresh('new', nil, 6)
local count = #calls
stale()
assert(#calls == count, 'Old query prefetch must be invalidated')
local closing = pages.prefetch()
pages.close()
closing()
assert(#calls == count, 'Close invalidates prefetch')
print('PASS pagination model')

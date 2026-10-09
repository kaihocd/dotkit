package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local PickerList = require('picker.picker.list')
local calls = 0
local ready = false

local list = PickerList.new({
  search = function()
    calls = calls + 1
    return { status = ready and 'ready' or 'indexing', items = {}, total = 0 }
  end,
}, false)

local page = list:load('first', 5)
list:continue_loading(page, function()
  error('invalidated list must not deliver a polling callback')
end)
list:invalidate()
vim.wait(150, function()
  return false
end)
assert(calls == 1)
print('PASS List invalidation cancels pending indexing delivery without a popup')

local delivered = false
page = list:load('second', 5)
list:continue_loading(page, function()
  ready = true
  local result = list:load('second', 5)
  assert(result.status == 'ready')
  delivered = true
end)
assert(vim.wait(500, function()
  return delivered
end))
assert(calls == 3)
print('PASS List indexing retry delivers the ready page without UI dependencies')

ready = false
page = list:load('third', 5)
list:continue_loading(page, function()
  error('closed list must not deliver a polling callback')
end)
list:close()
vim.wait(150, function()
  return false
end)
assert(calls == 4)
print('PASS List close cancels pending polling')

local files = PickerList.new({
  search = function(_, size, _, page_index)
    local items = {}
    for index = page_index * size + 1, math.min(23, (page_index + 1) * size) do
      items[#items + 1] = { path = '/' .. index, display = tostring(index) }
    end
    return { status = 'ready', items = items, total = 23 }
  end,
}, false)

files:load('', 5)
local changed, target = files:move(5, 1)
assert(changed and target == 1)
local next_page, selected = files:load('', 5, true)
assert(next_page.items[1].path == '/6' and selected == 1)

local position = files:snapshot()
assert(position.page == 1 and position.size == 5)
position.page = 99
assert(files:snapshot().page == 1, 'snapshot must not expose mutable page state')

assert(files:resize(3, 1) == 3)
local resized, resized_target = files:load('', 3, true)
assert(resized.items[resized_target].path == '/6')
files:close()
print('PASS List owns file navigation, logical resize and copied position snapshots')

local offsets = {}
local grep = PickerList.new({
  search = function(_, _, mode, offset)
    offsets[#offsets + 1] = offset
    assert(mode == 'plain')
    return {
      status = 'ready',
      items = {
        { path = '/a', display = 'a', line = offset + 1 },
        { path = '/a', display = 'a', line = offset + 2 },
      },
      total = 4,
      more = offset == 0,
      next_offset = offset + 2,
    }
  end,
}, true)

grep:load('needle', 5)
changed, target = grep:move(1, 20)
assert(not changed and target == 2 and #offsets == 1)
assert(grep:move(2, 1))
next_page, selected = grep:load('needle', 5, true)
assert(offsets[2] == 2 and selected == 1 and next_page.items[1].line == 3)
assert(grep:move(1, -1))
next_page, selected = grep:load('needle', 5, true)
assert(selected == 2 and next_page.items[2].line == 2)
grep:close()
print('PASS List resolves grep page-local movement before following backend continuation')

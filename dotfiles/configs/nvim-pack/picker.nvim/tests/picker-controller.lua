package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local Controller = require('picker.picker.selection')

local passed = 0
local function test(name, run)
  run()
  passed = passed + 1
  print('PASS ' .. name)
end

---@param path string
---@param line? integer
---@return picker.picker.Entry
local function entry(path, line)
  return { path = path, display = path, line = line, col = line and 0 or nil }
end

local a, b, c = entry('/a'), entry('/b'), entry('/c')

test('page targets clamp and empty results cannot retain a stale choice', function()
  local controller = Controller.new()
  controller:replace({ a, b }, false, 99)
  assert(controller:current() == b and controller:current_index() == 2)
  assert(not controller:can_move(1))
  controller:replace({ c }, false, -1)
  assert(controller:current() == c)
  controller:replace({})
  assert(controller:current() == nil and controller:current_index() == nil)
  assert(not controller:move(1) and not controller:toggle_mark())
end)

test('refresh preserves identity only when requested', function()
  local controller = Controller.new()
  controller:replace({ a, b })
  controller:move(1)
  local fresh = entry('/b')
  controller:replace({ c, fresh }, true)
  assert(controller:current() == fresh)
  controller:replace({ a, fresh })
  assert(controller:current() == a)
end)

test('marks survive query and page changes in marking order', function()
  local controller = Controller.new()
  controller:replace({ a, b })
  controller:move(1)
  controller:toggle_mark()
  controller:replace({ c })
  controller:toggle_mark()
  controller:replace({})
  local marked = controller:marked_items()
  assert(#marked == 2 and marked[1] == b and marked[2] == c)
  marked[1] = nil
  assert(controller:marked_count() == 2)
  controller:replace({ entry('/b') })
  assert(controller:is_marked(b))
  controller:toggle_mark()
  assert(controller:marked_count() == 1 and controller:marked_items()[1] == c)
end)

test('grep locations remain distinct and nearby files are deduplicated', function()
  local controller = Controller.new()
  local first, second = entry('/a', 1), entry('/a', 2)
  controller:replace({ first, second, b })
  controller:toggle_mark()
  controller:move(1)
  assert(not controller:is_marked(second))
  controller:toggle_mark()
  assert(controller:marked_count() == 2)
  local nearby = controller:nearby(2)
  assert(#nearby == 2 and nearby[1] == first and nearby[2] == b)
end)

test('invalid replacement leaves the previous page and marks intact', function()
  local controller = Controller.new()
  controller:replace({ a })
  controller:toggle_mark()
  assert(not pcall(controller.replace, controller, { b, entry('/b') }))
  assert(controller:current() == a and controller:marked_count() == 1)
end)

print('Passed ' .. passed .. ' tests')

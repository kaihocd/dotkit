-- Test Select business logic without opening windows.
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local SelectList = require('picker.select.list')

local passed = 0
local function test(name, run)
  local ok, failure = pcall(run)
  if not ok then
    error(name .. ': ' .. tostring(failure))
  end

  passed = passed + 1
  print('PASS ' .. name)
end

test('filter and move return the original item and index', function()
  local select = SelectList.new({ 'Apple', 'Banana', 'Apricot' })
  select:set_query('Ap')
  assert(#select:entries() == 2)
  assert(select:move(1))
  local item, index = select:choice()
  assert(item == 'Apricot')
  assert(index == 3)
end)

test('numeric queries match original indices rather than labels', function()
  local select = SelectList.new({ 'item 2', 'Banana', 'Apricot' })
  select:set_query('2')
  local item, index = select:choice()
  assert(item == 'Banana' and index == 2)
  select:set_query('0')
  assert(select:choice() == nil)
end)

test('query changes preserve current identity or fall back to first', function()
  local select = SelectList.new({ 'Apple', 'Banana', 'Apricot' })
  select:move(2)
  assert(select:set_query('Ap'))
  local _, index = select:choice()
  assert(index == 3)
  assert(not select:set_query('AP'))
  select:set_query('Apple')
  local item = select:choice()
  assert(item == 'Apple')
  select:set_query('missing')
  local empty_item, empty_index = select:choice()
  assert(empty_item == nil and empty_index == nil)
  assert(not select:move(1))
  select:set_query('')
  assert(select:choice() == 'Apple')
end)

test('identical formatted labels retain distinct original identities', function()
  local first, second = { name = 'same' }, { name = 'same' }
  local select = SelectList.new({ first, second }, {
    format_item = function(item)
      return item.name
    end,
  })
  select:set_query('same')
  select:move(1)
  local item, index = select:choice()
  assert(item == second and index == 2)
  local entries = select:entries()
  entries[1] = nil
  assert(#select:entries() == 2)
end)

test('current index is a visible position, not original identity', function()
  local select = SelectList.new({ 'Apple', 'Banana', 'Apricot' })
  select:set_query('Ap')
  assert(select:current_index() == 1)
  select:move(1)
  assert(select:current_index() == 2)
  local item, original_index = select:choice()
  assert(item == 'Apricot' and original_index == 3)

  select:set_query('missing')
  assert(select:current_index() == nil)
end)

test('select uses original identity and ignores hidden or unknown items', function()
  local select = SelectList.new({ 'Apple', 'Banana', 'Apricot' })
  select:set_query('Ap')
  assert(select:select(3))
  assert(select:current_index() == 2)
  local item, original_index = select:choice()
  assert(item == 'Apricot' and original_index == 3)

  for _, index in ipairs({ 3, 2, 99 }) do
    assert(not select:select(index))
    assert(select:current_index() == 2)
    assert(select:choice() == 'Apricot')
  end

  select:set_query('missing')
  assert(not select:select(1))
  assert(select:current_index() == nil)
  assert(select:choice() == nil)
end)

print(('Passed %d tests'):format(passed))

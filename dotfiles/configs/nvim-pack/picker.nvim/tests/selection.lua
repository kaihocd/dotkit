-- Exercise the internal module's interface, never its state tables.
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local Selection = require('picker.selection')
local passed = 0

local function test(name, run)
  local ok, failure = pcall(run)
  if not ok then
    error(name .. ': ' .. tostring(failure))
  end

  passed = passed + 1
  print('PASS ' .. name)
end

local function new_selection()
  return Selection.new({
    key = function(item)
      return item.id
    end,
  })
end

test('empty results and default current item', function()
  local selection = new_selection()
  assert(selection:count() == 0)
  assert(selection:current() == nil)
  assert(selection:current_key() == nil)
  assert(selection:current_index() == nil)
  assert(not selection:move(1))
  assert(not selection:can_move(1))
  assert(not selection:toggle_mark())

  local first = { id = 'a' }
  selection:replace({ first, { id = 'b' } })
  assert(selection:count() == 2)
  assert(selection:current() == first)
  assert(selection:current_index() == 1)
  assert(selection:current_key() == 'a')

  selection:replace({})
  assert(selection:current() == nil)
  assert(selection:current_index() == nil)
end)

test('preserve current identity, fall back, and reset by default', function()
  local selection = new_selection()
  selection:replace({ { id = 'a' }, { id = 'b' } })
  selection:select('b')

  local replacement = { id = 'b' }
  selection:replace({ replacement, { id = 'a' } }, { preserve_current = true })
  assert(selection:current() == replacement)
  assert(selection:current_index() == 1)

  selection:replace({ { id = 'c' } }, { preserve_current = true })
  assert(selection:current_key() == 'c')

  selection:replace({ { id = 'a' }, { id = 'c' } })
  assert(selection:current_key() == 'a')
end)

test('failed replacement leaves results, current item, and marks intact', function()
  local selection = new_selection()
  local first, second = { id = 'a' }, { id = 'b' }
  selection:replace({ first, second })
  selection:select('b')
  selection:toggle_mark()

  for _, invalid in ipairs({
    { { id = 'x' }, { id = 'x' } },
    { { id = 'x' }, { id = false } },
  }) do
    assert(not pcall(function()
      selection:replace(invalid)
    end))
    assert(selection:count() == 2)
    assert(selection:items()[1] == first)
    assert(selection:current() == second)
    assert(selection:current_index() == 2)
    assert(selection:marked_count() == 1)
    assert(selection:marked_items()[1] == second)
  end
end)

test('movement clamps while can_move checks full displacement', function()
  local selection = new_selection()
  selection:replace({ { id = 'a' }, { id = 'b' }, { id = 'c' } })
  assert(selection:can_move(2))
  assert(not selection:can_move(3))
  assert(selection:current_index() == 1)
  assert(selection:move(99))
  assert(selection:current_index() == 3)
  assert(not selection:move(1))
  assert(not selection:move(0))
  assert(not selection:select('missing'))
  assert(not selection:select('c'))
  assert(selection:select('b'))
  assert(selection:move(-99))
  assert(selection:current_index() == 1)
end)

test('marks survive filtering and retain references and marking order', function()
  local selection = new_selection()
  local first, second = { id = 'a' }, { id = 'b' }
  selection:replace({ first, second })
  selection:toggle_mark()
  selection:select('b')
  selection:toggle_mark()
  selection:replace({})
  assert(selection:marked_items()[1] == first)
  assert(selection:marked_items()[2] == second)

  local replacement = { id = 'a' }
  selection:replace({ replacement })
  assert(selection:is_marked('a'))
  assert(selection:marked_items()[1] == first)
  selection:toggle_mark()
  assert(not selection:is_marked('a'))
  selection:toggle_mark()
  assert(selection:marked_items()[1] == second)
  assert(selection:marked_items()[2] == replacement)

  selection:clear_marks()
  assert(selection:marked_count() == 0)
  assert(selection:current() == replacement)
  assert(selection:count() == 1)
end)

test('arrays are copied but item references are retained', function()
  local selection = new_selection()
  local item = { id = 'a' }
  local input = { item }
  selection:replace(input)
  input[1] = { id = 'other' }
  local output = selection:items()
  output[1] = nil
  assert(selection:count() == 1)
  assert(selection:current() == item)

  selection:toggle_mark()
  local marked = selection:marked_items()
  marked[1] = nil
  assert(selection:marked_count() == 1)
  assert(selection:marked_items()[1] == item)
end)

test('false is a valid current item with stable identity', function()
  local selection = Selection.new({ key = tostring })
  selection:replace({ false, true })
  assert(selection:current() == false)
  assert(selection:current_key() == 'false')
  selection:replace({ true, false }, { preserve_current = true })
  assert(selection:current_index() == 2)
  assert(selection:current() == false)
end)

test('false-valued marks can be removed and marked again', function()
  local selection = Selection.new({ key = tostring })
  selection:replace({ false })
  assert(selection:toggle_mark())
  assert(selection:is_marked('false'))
  assert(selection:marked_items()[1] == false)
  assert(selection:toggle_mark())
  assert(not selection:is_marked('false'))
  assert(selection:marked_count() == 0)
  assert(selection:toggle_mark())
  assert(selection:marked_count() == 1)
end)

test('restored marks deduplicate in first-seen order without changing results', function()
  local selection = new_selection()
  local current, first, second = { id = 'current' }, { id = 'a' }, { id = 'b' }
  selection:replace({ current })
  local input = { second, first, { id = 'b' } }
  selection:replace_marks(input)
  input[1] = nil
  assert(selection:marked_count() == 2)
  assert(selection:marked_items()[1] == second and selection:marked_items()[2] == first)
  assert(selection:current() == current and selection:count() == 1)
  selection:replace_marks({})
  assert(selection:marked_count() == 0 and selection:current() == current)
end)

test('restored false-valued marks deduplicate and toggle normally', function()
  local selection = Selection.new({ key = tostring })
  selection:replace({ false })
  selection:replace_marks({ false, true, false })
  assert(selection:marked_count() == 2 and selection:marked_items()[1] == false)
  selection:toggle_mark()
  assert(selection:marked_count() == 1 and selection:marked_items()[1] == true)
end)

test('failed mark restoration preserves marks, results and selection atomically', function()
  local selection = Selection.new({
    key = function(item)
      if item.id == 'throw' then
        error('key failure')
      end
      return item.id
    end,
  })
  local current = { id = 'current' }
  selection:replace({ current })
  selection:toggle_mark()
  for _, invalid in ipairs({ {}, { id = false }, { id = {} }, { id = 0 / 0 }, { id = 'throw' } }) do
    assert(not pcall(function()
      selection:replace_marks({ { id = 'partial' }, invalid })
    end))
    assert(selection:marked_count() == 1 and selection:marked_items()[1] == current)
    assert(not selection:is_marked('partial'))
    assert(selection:current() == current and selection:count() == 1)
  end
end)

print(('Passed %d tests'):format(passed))

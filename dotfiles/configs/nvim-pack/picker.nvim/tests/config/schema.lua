local schema = require('picker.config.schema')

local function fails(body, pattern)
  local ok, problem = pcall(body)
  assert(not ok, 'expected a failure, got success')
  assert(
    tostring(problem):find(pattern, 1, true),
    ('expected %q in: %s'):format(pattern, tostring(problem))
  )
end

return function(test)
  test('merges nested records and keeps siblings', function()
    local merged = schema.merge({ view = { a = 1, b = 2 } }, { view = { b = 3 } })
    assert(merged.view.a == 1 and merged.view.b == 3, vim.inspect(merged))
  end)

  test('replaces nonempty sequences instead of merging them', function()
    local merged = schema.merge({ margin = { 0, 1 } }, { margin = { 2, 3 } })
    assert(vim.deep_equal(merged.margin, { 2, 3 }), vim.inspect(merged.margin))
  end)

  test('treats an empty override as a record no-op', function()
    local merged = schema.merge({ git = { a = { 'x', 'Y' } } }, { git = {} })
    assert(next(merged.git) ~= nil, 'an empty table does not erase the record')
    assert(vim.deep_equal(merged.git.a, { 'x', 'Y' }), vim.inspect(merged.git))
  end)

  test('rejects keys the schema does not declare', function()
    fails(function()
      schema.validate_record({ nope = 1 }, { known = true }, 'sample')
    end, 'unsupported option sample.nope')
  end)

  test('rejects a value whose type differs from the default', function()
    fails(function()
      schema.validate_record({ known = 'text' }, { known = true }, 'sample')
    end, 'invalid type for sample.known')
  end)

  test('rejects multi-line strings under presentation', function()
    fails(function()
      schema.validate_record({ presentation = { empty = 'a\nb' } }, {
        presentation = { empty = 'No Item' },
      }, 'sample')
    end, 'must be a single line without tabs')
  end)

  test('lets a rule handle a key that has no default', function()
    local seen
    schema.validate_record({ icon = false }, { known = true }, 'sample', {
      sample = {
        icon = function(value, name)
          seen = name
          assert(value == false, 'rule receives the value')
          return true
        end,
      },
    })
    assert(seen == 'sample.icon', 'the rule ran for the undeclared key')
  end)

  test('falls back to the type check when a rule declines', function()
    fails(function()
      schema.validate_record({ known = 'text' }, { known = true }, 'sample', {
        sample = { known = function() end },
      })
    end, 'invalid type for sample.known')
  end)
end

local tree = require('picker.ui.tree')

local function fails(body, pattern)
  local ok, problem = pcall(body)
  assert(not ok, 'expected a failure, got success')
  assert(
    tostring(problem):find(pattern, 1, true),
    ('expected %q in: %s'):format(pattern, tostring(problem))
  )
end

local function pane(id)
  return { type = 'pane', id = id, buf = vim.api.nvim_create_buf(false, true) }
end

---A minimal picker-shaped fixture: three panes, preview optional.
local function fixture()
  local panes = { input = pane('input'), list = pane('list'), preview = pane('preview') }
  local buffers = { panes.input.buf, panes.list.buf, panes.preview.buf }
  local spec = {
    prefix = 'picker',
    roles = { 'input', 'list', 'preview' },
    optional = { preview = true },
    requires = function(used)
      if not used.input or not used.list then
        return 'layout must retain input and list'
      end
    end,
  }
  return panes, buffers, spec
end

return function(test)
  test('accepts a tree that reuses the supplied panes', function()
    local panes, buffers, spec = fixture()
    local layout = { type = 'col', children = { panes.input, panes.list } }
    assert(tree.validate(layout, panes, panes, buffers, spec) == layout, 'returns the tree')
  end)

  test('rejects a node the callback built itself', function()
    local panes, buffers, spec = fixture()
    local layout = { type = 'row', children = { panes.input, { type = 'pane', id = 'list' } } }
    fails(function()
      tree.validate(layout, panes, panes, buffers, spec)
    end, 'picker: layout must use each supplied pane exactly once')
  end)

  test('rejects a pane used twice', function()
    local panes, buffers, spec = fixture()
    local layout = { type = 'col', children = { panes.input, { type = 'col', children = { panes.list, panes.list } } } }
    fails(function()
      tree.validate(layout, panes, panes, buffers, spec)
    end, 'layout must return a tree without repeated nodes')
  end)

  test('rejects a replaced role table entry', function()
    local panes, buffers, spec = fixture()
    local originals = vim.deepcopy(panes)
    panes.input = pane('input')
    fails(function()
      tree.validate({ type = 'col', children = { panes.input, panes.list } }, panes, originals, buffers, spec)
    end, 'picker: layout cannot replace supplied panes')
  end)

  test('rejects an unsupplied pane that is not optional', function()
    local panes, buffers, spec = fixture()
    local originals = { input = panes.input, list = nil, preview = panes.preview }
    fails(function()
      tree.validate({ type = 'col', children = { panes.input } }, originals, originals, buffers, spec)
    end, 'picker: layout requires every supplied pane')
  end)

  test('accepts an omitted optional pane', function()
    local panes, buffers, spec = fixture()
    local originals = { input = panes.input, list = panes.list, preview = nil }
    local layout = { type = 'col', children = { panes.input, panes.list } }
    assert(tree.validate(layout, originals, originals, buffers, spec) == layout, 'preview stays optional')
  end)

  test('rejects an unknown node type', function()
    local panes, buffers, spec = fixture()
    fails(function()
      tree.validate({ type = 'grid', children = { panes.input } }, panes, panes, buffers, spec)
    end, 'picker: layout expects native pane, row or col nodes')
  end)

  test('rejects empty and sparse children', function()
    local panes, buffers, spec = fixture()
    fails(function()
      tree.validate({ type = 'col', children = {} }, panes, panes, buffers, spec)
    end, 'picker: layout containers require a nonempty children array')
    fails(function()
      tree.validate(
        { type = 'col', children = { panes.input, panes.list, extra = panes.preview } },
        panes,
        panes,
        buffers,
        spec
      )
    end, 'picker: layout children must be a dense array')
  end)

  test('reports the role the callback dropped', function()
    local panes, buffers, spec = fixture()
    fails(function()
      tree.validate(panes.input, panes, panes, buffers, spec)
    end, 'picker: layout must retain input and list')
  end)

  test('keeps the select entry point messages separate', function()
    local panes = {
      input = pane('input'),
      list = pane('list'),
      detail = pane('detail'),
      prompt = pane('prompt'),
    }
    local buffers = { panes.input.buf, panes.list.buf, panes.detail.buf, panes.prompt.buf }
    local spec = {
      prefix = 'picker.select',
      roles = { 'input', 'list', 'detail', 'prompt' },
      requires = function(used)
        if not used.input or not used.prompt then
          return 'layout must retain input and the active list/detail pane'
        end
      end,
    }
    assert(
      tree.validate(
        { type = 'col', children = { panes.input, panes.prompt, panes.list } },
        panes,
        panes,
        buffers,
        spec
      )
    )
    fails(function()
      tree.validate({ type = 'col', children = { panes.input, panes.list } }, panes, panes, buffers, spec)
    end, 'picker.select: layout must retain input and the active list/detail pane')
  end)
end

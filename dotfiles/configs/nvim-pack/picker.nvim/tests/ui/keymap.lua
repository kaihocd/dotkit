local keymap_ui = require('picker.ui.keymap')

---Minimal popup.instance surface: panes, listeners and event emission.
local function fake_instance()
  local buf = vim.api.nvim_create_buf(false, true)
  local listeners = {}
  local instance = { panes = { input = { buf = buf } } }

  function instance:pane(id)
    return self.panes[id]
  end

  function instance:on(event, callback)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], callback)
  end

  function instance:emit(event)
    for _, callback in ipairs(listeners[event] or {}) do
      callback()
    end
  end

  function instance:events()
    local names = {}
    for name in pairs(listeners) do
      names[#names + 1] = name
    end
    table.sort(names)
    return names
  end

  return instance, buf
end

local function insert_mapping(buf, lhs)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, 'i')) do
    if mapping.lhs:lower() == lhs:lower() then
      return (mapping.rhs or ''):lower()
    end
  end
end

return function(test)
  test('binds a buffer-local word delete on open', function()
    local instance, buf = fake_instance()
    keymap_ui.preserve_insert_word_delete(instance, {})
    assert(vim.deep_equal(instance:events(), { 'open', 'render' }), vim.inspect(instance:events()))
    instance:emit('open')
    assert(insert_mapping(buf, '<C-w>') == '<c-s-w>', 'native word delete is preserved')
  end)

  test('reapplies the binding when the pane is remounted', function()
    local instance, buf = fake_instance()
    keymap_ui.preserve_insert_word_delete(instance, {})
    instance:emit('render')
    assert(insert_mapping(buf, '<C-w>') == '<c-s-w>', 'render rebinds the mounted pane')
  end)

  test('keeps a user declaration of <C-w>', function()
    local instance, buf = fake_instance()
    keymap_ui.preserve_insert_word_delete(instance, { i = { ['<C-w>'] = 'previous' } })
    assert(#instance:events() == 0, 'no listeners when the user claimed <C-w>')
    instance:emit('open')
    assert(insert_mapping(buf, '<C-w>') == nil, 'no buffer-local override either')
  end)

  test('binds when only normal-mode mappings are configured', function()
    local instance, buf = fake_instance()
    keymap_ui.preserve_insert_word_delete(instance, { n = { ['<CR>'] = 'confirm' } })
    instance:emit('open')
    assert(insert_mapping(buf, '<C-w>') == '<c-s-w>', 'insert mode stays unclaimed')
  end)

  test('tolerates an instance without an input pane', function()
    local instance = {
      pane = function()
        return nil
      end,
      on = function(self, event, callback)
        self.listeners = self.listeners or {}
        self.listeners[event] = callback
      end,
    }
    keymap_ui.preserve_insert_word_delete(instance, {})
    assert(pcall(instance.listeners.open), 'binding a missing pane is a no-op')
  end)
end

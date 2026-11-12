-- Keymap contracts shared by both entry points.
--
-- Only behavior that is byte-identical in the two windows lives here. Each
-- window keeps its own action resolution: the picker routes callbacks through a
-- scheduler, the select overlay guards them with an `active()` predicate, and
-- unifying those would change how both windows dispatch keys.

local M = {}

---Neovim's insert-mode `<C-w>` deletes the previous word, but the input line
---uses it as its own binding. Preserve the native meaning unless the user
---claimed `<C-w>` explicitly, in which case their declaration wins.
---@param instance popup.instance
---@param mappings popup.keymap.opts
function M.preserve_insert_word_delete(instance, mappings)
  if mappings.i and mappings.i['<C-w>'] ~= nil then
    return
  end

  -- Buffer-local, so it is re-applied whenever the pane is (re)mounted.
  local function bind_input()
    local input = instance:pane('input')
    if input then
      vim.keymap.set('i', '<C-w>', '<C-S-w>', { buffer = input.buf, desc = 'Delete previous word' })
    end
  end

  instance:on('open', bind_input)
  instance:on('render', bind_input)
end

return M

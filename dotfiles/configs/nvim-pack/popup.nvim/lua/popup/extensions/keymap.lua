return function(opts)
  return {
    name = 'keymap',
    opts = opts,
    apply = function(instance, plugin_opts)
      local function resolve_action(action)
        if action == 'close' then
          return function()
            instance:close()
          end
        elseif action == 'hide' then
          return function()
            instance:hide()
          end
        elseif action == false or action == '<Nop>' then
          return '<Nop>'
        end
        return action
      end

      local function set_keymaps(buf)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        for mode, maps in pairs(plugin_opts) do
          for key, action in pairs(maps) do
            local callback = resolve_action(action)
            if callback then
              vim.keymap.set(mode, key, callback, { buffer = buf, nowait = true })
            end
          end
        end
      end

      local function apply_keymaps()
        for _, pane in ipairs(instance:panes()) do
          set_keymaps(pane.buf)
        end
      end

      instance:on('open', apply_keymaps)
      instance:on('render', apply_keymaps)
    end,
  }
end

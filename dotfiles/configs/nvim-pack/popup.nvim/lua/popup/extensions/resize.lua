return function(opts)
  return {
    name = 'resize',
    opts = opts,
    apply = function(instance, plugin_opts)
      local geometry = plugin_opts.geometry
      if not geometry then
        return
      end

      local resize_autocmd = nil

      local function setup()
        if resize_autocmd then
          return
        end

        resize_autocmd = vim.api.nvim_create_autocmd('VimResized', {
          callback = function()
            local g = geometry()
            instance
              :update(function(root)
                root.row = g.row
                root.col = g.col
                root.width = g.width
                root.height = g.height
              end)
              :render()
          end,
        })
      end

      local function cleanup()
        if resize_autocmd then
          vim.api.nvim_del_autocmd(resize_autocmd)
          resize_autocmd = nil
        end
      end

      instance:on('open', setup)
      instance:on('close', cleanup)
    end,
  }
end

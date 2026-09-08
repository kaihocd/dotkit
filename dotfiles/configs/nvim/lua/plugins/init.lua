local M = {}

function M.setup()
  local config = assert(
    vim.uv.fs_realpath(vim.fn.stdpath('config')),
    'Unable to resolve Neovim configuration directory'
  )

  require('plugins.pack').setup({
    {
      name = 'popup.nvim',
      path = vim.fs.joinpath(vim.fs.dirname(config), 'nvim-pack', 'popup.nvim'),
      event = 'VimEnter',
      config = function()
        require('popup').group('single_popup', {
          on_join = function(instance, group)
            instance:on('open', function()
              for _, other in ipairs(group.instances) do
                if other ~= instance and other:is_open() then
                  other:close('group_replaced')
                end
              end
            end)
          end,
        })
      end,
    },
    unpack(require('plugins.editor')),
  })
end

return M

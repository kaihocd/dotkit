local config = assert(
  vim.uv.fs_realpath(vim.fn.stdpath('config')),
  'Unable to resolve Neovim configuration directory'
)

return {
  {
    name = 'popup.nvim',
    path = vim.fs.joinpath(vim.fs.dirname(config), 'nvim-pack', 'popup.nvim'),
    event = 'UIEnter',
    config = function()
      require('popup').group('single_popup', {
        on_join = function(instance, group)
          instance:on('open', function()
            for _, other in ipairs(vim.list_extend({}, group.instances)) do
              if other ~= instance and other:is_open() then
                other:close('group_replaced')
              end
            end
          end)
        end,
      })
    end,
  },
}

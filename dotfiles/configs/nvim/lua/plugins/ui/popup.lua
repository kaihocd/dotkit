local M = {}

M.EXCLUSIVE_GROUP = 'exclusive'

M.config = function()
  require('popup').group(M.EXCLUSIVE_GROUP, {
    on_join = function(instance, group)
      instance:on('open', function()
        for _, other in ipairs(vim.list_slice(group.instances)) do
          if other ~= instance and other:is_open() then
            other:close()
          end
        end
      end)

      instance:on('close', function()
        instance:leave_group()
      end)
    end,
  })
end

return M

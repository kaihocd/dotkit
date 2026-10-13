local M = {}

M.config = function()
  local picker = require('picker')
  require('picker').setup()
  local exclusive_group = require('plugins.ui.popup').EXCLUSIVE_GROUP

  local function configure(instance)
    instance:join_group(exclusive_group)
  end

  vim.keymap.set('n', '<leader>sf', function()
    picker.open({ on_instance = configure })
  end, { desc = 'Search files' })

  vim.keymap.set('n', '<leader>sg', function()
    picker.open({ mode = 'grep', on_instance = configure })
  end, { desc = 'Search grep' })

  vim.keymap.set('n', '<leader>sr', function()
    picker.resume({ on_instance = configure })
  end, { desc = 'Resume picker' })

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.ui.select = function(items, options, on_choice)
    return picker.select(items, options, on_choice)
  end
end

return M

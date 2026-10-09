local M = {}

local function open_cmdline()
  local glance = require('glance')
  glance.actions.close()

  -- Close Glance before command-line entry, including a later <C-f>.
  vim.api.nvim_feedkeys(':', 'n', false)
end

function M.config()
  local actions = require('glance').actions

  require('glance').setup({
    mappings = {
      list = {
        [':'] = open_cmdline,
        ['<C-j>'] = actions.jump,
        ['<C-c>'] = actions.close,
      },
      preview = {
        [':'] = open_cmdline,
        ['<C-c>'] = actions.close,
        ['q'] = actions.close,
      },
    },
    hooks = {
      before_open = function(results, open, jump, method)
        if method == 'definitions' and #results == 1 then
          jump(results[1])
        else
          open(results)
        end
      end,
    },
  })

  vim.keymap.set('n', 'gd', '<Cmd>Glance definitions<CR>', {
    desc = 'Glance definitions',
  })
  vim.keymap.set('n', 'grr', '<Cmd>Glance references<CR>', {
    desc = 'Glance references',
  })
  vim.keymap.set('n', 'gri', '<Cmd>Glance implementations<CR>', {
    desc = 'Glance implementations',
  })
  vim.keymap.set('n', 'grt', '<Cmd>Glance type_definitions<CR>', {
    desc = 'Glance type definitions',
  })
end

return M

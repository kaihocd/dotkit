local M = {}
local api = vim.api

local function open_tab()
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'mason' then
      api.nvim_set_current_win(win)
      return
    end
  end

  vim.cmd.tabnew()
  local target = api.nvim_get_current_win()
  local placeholder = api.nvim_get_current_buf()
  local group = api.nvim_create_augroup('ConfigMasonTab', { clear = true })

  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'mason',
    once = true,
    callback = function(event)
      -- Mason finishes registering its window events after setting filetype.
      vim.schedule(function()
        if not api.nvim_win_is_valid(target) or not api.nvim_buf_is_valid(event.buf) then
          return
        end

        local win = vim.fn.bufwinid(event.buf)
        if win == -1 then
          return
        end

        -- These private Mason groups manage floating-window geometry and focus.
        for _, autocmd in
          ipairs(api.nvim_get_autocmds({
            group = 'MasonWindowMgmt',
            event = 'VimResized',
            buffer = event.buf,
          }))
        do
          api.nvim_del_autocmd(autocmd.id)
        end

        for _, autocmd in
          ipairs(api.nvim_get_autocmds({ group = 'MasonWindow', event = 'WinEnter' }))
        do
          api.nvim_del_autocmd(autocmd.id)
        end

        api.nvim_win_set_config(win, { split = 'right', win = target })
        api.nvim_win_close(target, true)
        if api.nvim_buf_is_valid(placeholder) then
          api.nvim_buf_delete(placeholder, { force = true })
        end
      end)
    end,
  })

  require('mason.ui').open()
end

function M.config()
  require('mason').setup({ ui = { backdrop = 100 } })

  api.nvim_create_user_command('Mason', open_tab, {
    desc = 'Open Mason in a dedicated tab',
    force = true,
  })
end

return M

local M = {}
local started = false
local active = nil
local namespace = vim.api.nvim_create_namespace('UiInputPrompt')

local function render_prompt(buf)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  if not active or not active.prompt or active.prompt == '' then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local prompt = active.prompt:gsub('[\r\n]', ' ')
  vim.api.nvim_buf_set_extmark(buf, namespace, line, 0, {
    virt_text = { { prompt, 'Normal' } },
    virt_text_pos = 'inline',
    right_gravity = false,
  })
end

function M.setup()
  if started then
    return
  end
  started = true

  local native_input = vim.ui.input

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.ui.input = function(opts, on_confirm)
    local previous = active
    local context = { prompt = opts and opts.prompt }
    local input_opts = vim.tbl_extend('force', opts or {}, {
      prompt = '@' .. (context.prompt or ''),
    })
    active = context

    local ok, err = pcall(native_input, input_opts, function(value)
      active = previous
      on_confirm(value)
    end)
    if active == context then
      active = previous
    end
    if not ok then
      error(err, 0)
    end
  end

  local group = vim.api.nvim_create_augroup('UiInput', { clear = true })
  vim.api.nvim_create_autocmd({ 'CmdwinEnter', 'CursorMoved', 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function(event)
      if vim.fn.getcmdwintype() == '@' then
        render_prompt(event.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('CmdwinLeave', {
    group = group,
    callback = function(event)
      vim.api.nvim_buf_clear_namespace(event.buf, namespace, 0, -1)
    end,
  })
end

return M

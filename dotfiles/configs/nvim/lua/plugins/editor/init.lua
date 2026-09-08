local function oil_geometry()
  local width = math.floor(vim.o.columns * 0.75)
  local height = math.floor(vim.o.lines * 0.65)

  return {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
  }
end

local function attach_oil_window(args)
  local win = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(win)

  if not vim.w[win].is_oil_win or config.relative == '' then
    return
  end

  local popup = require('popup').external({
    win = win,
    group = 'single_popup',
    geometry = oil_geometry,
    style = {
      border = 'single',
      title = ' Oil ',
      title_pos = 'center',
      winhl = 'Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle',
    },
    on_close_request = function()
      require('oil').close()
    end,
  })

  popup:on('close', function()
    if vim.api.nvim_buf_is_valid(args.buf) then
      vim.api.nvim_buf_set_var(args.buf, 'dotkit_oil_popup', nil)
    end
  end)
end

return {
  {
    src = 'https://github.com/stevearc/oil.nvim',
    event = 'UIEnter',
    deps = {
      { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
    },
    opts = {
      columns = { 'icon', 'permissions', 'size', 'mtime' },
      float = {
        padding = 0,
        max_width = 0.75,
        max_height = 0.65,
        border = 'single',
        win_options = {
          number = true,
          cursorline = true,
        },
        override = function(conf)
          conf.relative = 'editor'
          conf.row = oil_geometry().row
          conf.col = oil_geometry().col
          conf.width = oil_geometry().width
          conf.height = oil_geometry().height
          conf.border = 'single'
          conf.title = ' Oil '
          conf.title_pos = 'center'
          return conf
        end,
      },
      keymaps = {
        ['-'] = { 'actions.close', mode = 'n' },
        ['q'] = { 'actions.close', mode = 'n' },
        ['<BS>'] = { 'actions.parent', mode = 'n' },
        ['<C-h>'] = { 'actions.parent', mode = 'n' },
        ['<C-l>'] = { 'actions.select', mode = 'n' },
        ['<C-j>'] = { 'actions.select', mode = 'n' },
        ['<C-w>v'] = { 'actions.select', opts = { vertical = true } },
        ['<C-w>s'] = { 'actions.select', opts = { horizontal = true } },
        ['<C-r>'] = { 'actions.refresh', mode = 'n' },
        ['gh'] = { 'actions.toggle_hidden', mode = 'n' },
      },
    },
    config = function(opts)
      local group = require('popup.group').get('single_popup')
      if not group then
        error('Oil requires popup group: single_popup')
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'oil',
        callback = attach_oil_window,
      })

      local oil = require('oil')
      oil.setup(opts)
      vim.keymap.set('n', '-', oil.toggle_float, { desc = 'Toggle Oil Floating' })
    end,
  },
}

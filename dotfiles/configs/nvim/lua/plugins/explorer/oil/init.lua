local Adapter = require('plugins.explorer.oil.adapter')

local MIN_PANE_SIZE = 3
local WIDTH_RATIO = 0.7
local HEIGHT_RATIO = 0.7

local M = {}

function M.config()
  local adapter = Adapter.new({
    min_pane_size = MIN_PANE_SIZE,
    border = 'solid',
    group = require('plugins.ui.popup').EXCLUSIVE_GROUP,
    geometry = function()
      local width = math.max(MIN_PANE_SIZE, math.floor(vim.o.columns * WIDTH_RATIO))
      local height = math.max(MIN_PANE_SIZE, math.floor(vim.o.lines * HEIGHT_RATIO))

      return {
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
      }
    end,
    oil_title = function(dir, cwd)
      local path = vim.fs.relpath(cwd, dir) or vim.fn.fnamemodify(dir, ':~')
      if path == '' or path == '.' then
        path = vim.fs.basename(vim.fs.normalize(cwd))
      end

      return { title = ' ' .. (path:gsub('/+$', '')) .. '/ ', title_pos = 'center' }
    end,
    preview_title = function()
      return { title = ' Preview ', title_pos = 'center' }
    end,
    keymaps = {
      n = { ['<C-c>'] = 'close', ['q'] = 'close' },
    },
    oil_win_options = { number = true },
    preview_win_options = {
      number = true,
      winhighlight = table.concat({
        'Normal:NormalFloat',
        'NormalNC:NormalFloat',
        'SignColumn:NormalFloat',
        'EndOfBuffer:NormalFloat',
        'FloatBorder:FloatBorder',
        'FloatTitle:FloatTitle',
      }, ','),
    },
  })

  local function select(opts)
    return function()
      adapter:select(opts)
    end
  end

  local function scroll_preview(opts)
    return function()
      adapter:scroll_preview(opts)
    end
  end

  local function close()
    adapter:close()
  end

  local function select_current()
    adapter:select()
  end

  require('oil').setup({
    columns = { 'icon', 'permissions', 'size', 'mtime' },
    win_options = { number = true },
    confirmation = {
      border = 'solid',
      win_options = {
        winhighlight = table.concat({
          'Normal:Pmenu',
          'NormalNC:Pmenu',
          'EndOfBuffer:Pmenu',
          'SignColumn:Pmenu',
          'FloatBorder:PreviewBorder',
          'FloatTitle:PreviewTitle',
        }, ','),
      },
    },
    keymaps = {
      ['-'] = close,
      ['q'] = close,
      ['<C-c>'] = close,
      ['<CR>'] = select_current,
      ['<C-l>'] = select_current,
      ['<C-j>'] = select_current,
      ['<BS>'] = 'actions.parent',
      ['<C-h>'] = 'actions.parent',
      ['<C-w>v'] = select({ vertical = true }),
      ['<C-w>s'] = select({ horizontal = true }),
      ['<C-s>'] = select({ vertical = true }),
      ['<C-v>'] = select({ horizontal = true }),
      ['<C-t>'] = select({ tab = true }),
      ['<C-r>'] = 'actions.refresh',
      ['gh'] = 'actions.toggle_hidden',
      ['<C-o>'] = function()
        adapter:preview()
      end,
      ['<C-n>'] = 'j',
      ['<C-p>'] = 'k',
      ['<C-f>'] = scroll_preview('down'),
      ['<C-b>'] = scroll_preview('up'),
    },
  })

  vim.keymap.set('n', '-', function()
    adapter:toggle()
  end, { desc = 'Toggle Oil Popup' })
end

return M

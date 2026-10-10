-- Terminal plugin configuration.
local M = {}

local DISABLED_KEYS = {
  ['<A-h>'] = false,
  ['<A-j>'] = false,
  ['<A-k>'] = false,
  ['<A-l>'] = false,
  ['<C-w>+'] = false,
  ['<C-w>-'] = false,
  ['<C-w>>'] = false,
  ['<C-w><'] = false,
  ['<C-w>='] = false,
  ['<C-w>|'] = false,
  ['<C-w>_'] = false,
}

M.defaults = {
  width_ratio = 0.75,
  height_ratio = 0.75,
  list_width = 20,
  -- Solid padding supports native titles; FloatBorder supplies the borderless style.
  border = 'solid',
  shell = vim.o.shell,
  auto_insert = true,
  list_title = ' List ',
  help_title = ' Help ',
  term_title = ' Terminal ',
  default_term_name = 'Terminal',
  help_text = {
    ' [n]     new term ',
    ' [r]       rename ',
    ' [d]       delete ',
    ' [<Cr>]    select ',
    ' [<A-h>]     list ',
    ' [<A-l>] terminal ',
    ' [<A-j>]     next ',
    ' [<A-k>]     prev ',
  },

  on_open = nil,

  on_close = nil,

  keymaps = {
    list = vim.tbl_extend('force', DISABLED_KEYS, {
      ['<A-j>'] = function(terminal)
        terminal.next()
      end,
      ['<A-k>'] = function(terminal)
        terminal.prev()
      end,
      ['r'] = function(terminal)
        terminal.rename_under_cursor()
      end,
      ['n'] = function(terminal)
        terminal.new()
      end,
      ['<cr>'] = function(terminal)
        terminal.select_under_cursor()
      end,
      ['d'] = function(terminal)
        terminal.delete_under_cursor()
      end,
      ['<A-l>'] = function(terminal)
        terminal.focus_right()
      end,
      ['q'] = function(terminal)
        terminal.close()
      end,
    }),
    term = vim.tbl_extend('force', DISABLED_KEYS, {
      ['<A-j>'] = {
        mode = { 'n', 't' },
        action = function(terminal)
          terminal.next()
        end,
      },
      ['<A-k>'] = {
        mode = { 'n', 't' },
        action = function(terminal)
          terminal.prev()
        end,
      },
      ['<A-h>'] = {
        mode = { 'n', 't' },
        action = function(terminal)
          terminal.focus_left()
        end,
      },
      ['q'] = function(terminal)
        terminal.close()
      end,
    }),
  },
}

M.options = {}

-- Merge user options into defaults.
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
end

-- Return the resolved options, initializing with defaults if needed.
---@return table
function M.get()
  if vim.tbl_isempty(M.options) then
    error('terminal: setup() must be called before using the API')
  end
  return M.options
end

return M

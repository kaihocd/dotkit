---@class terminal.Config
---@field width_ratio number
---@field height_ratio number
---@field list_width integer
---@field border string|table
---@field shell string|string[]
---@field auto_insert boolean
---@field list_title string
---@field help_title string
---@field term_title string
---@field default_term_name string
---@field help_text string[]
---@field keymaps table<string, table<string, function|false|table>>
---@field group? string
---@field on_open? fun(list_win: integer?, term_win: integer?, help_win: integer?)
---@field on_close? fun()

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

local defaults = {
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

---@type terminal.Config?
local options

local function copy(opts)
  return vim.deepcopy(opts)
end

local function validate(opts)
  local function check(ok, key)
    assert(ok, 'terminal: invalid option ' .. key)
  end
  for key in pairs(opts) do
    check(defaults[key] ~= nil or key == 'group' or key == 'on_open' or key == 'on_close', key)
  end
  for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
    local value = opts[key]
    check(type(value) == 'number' and value > 0 and value <= 1, key)
  end
  check(
    type(opts.list_width) == 'number' and opts.list_width >= 1 and opts.list_width % 1 == 0,
    'list_width'
  )
  check(type(opts.auto_insert) == 'boolean', 'auto_insert')
  for _, key in ipairs({ 'list_title', 'help_title', 'term_title', 'default_term_name' }) do
    check(type(opts[key]) == 'string', key)
  end
  for _, key in ipairs({ 'on_open', 'on_close' }) do
    check(opts[key] == nil or type(opts[key]) == 'function', key)
  end
  if type(opts.border) == 'string' then
    check(
      vim.tbl_contains({ 'none', 'single', 'double', 'rounded', 'solid', 'shadow' }, opts.border),
      'border'
    )
  else
    local border = opts.border
    check(
      type(border) == 'table' and vim.islist(border) and #border > 0 and 8 % #border == 0,
      'border'
    )
    for _, part in ipairs(border) do
      if type(part) == 'table' then
        check(
          vim.islist(part)
            and #part == 2
            and (type(part[2]) == 'string' or type(part[2]) == 'number'),
          'border highlight'
        )
        part = part[1]
      end
      check(type(part) == 'string' and vim.fn.strdisplaywidth(part) <= 1, 'border character')
    end
  end
  check(opts.group == nil or (type(opts.group) == 'string' and opts.group ~= ''), 'group')
  local function strings(value, key)
    check(type(value) == 'table' and vim.islist(value) and #value > 0, key)
    for _, item in ipairs(value) do
      check(type(item) == 'string' and item ~= '', key)
    end
  end
  if type(opts.shell) == 'table' then
    strings(opts.shell, 'shell')
  else
    check(type(opts.shell) == 'string' and opts.shell ~= '', 'shell')
  end
  strings(opts.help_text, 'help_text')
  check(type(opts.keymaps) == 'table', 'keymaps')
  for pane, mappings in pairs(opts.keymaps) do
    check((pane == 'list' or pane == 'term') and type(mappings) == 'table', 'keymaps.' .. pane)
    for key, value in pairs(mappings) do
      check(type(key) == 'string' and key ~= '', 'keymaps key')
      if type(value) == 'table' then
        for field in pairs(value) do
          check(field == 'mode' or field == 'action', 'keymaps.' .. key)
        end
        local modes = type(value.mode) == 'string' and { value.mode } or value.mode
        strings(modes, 'keymaps.' .. key .. '.mode')
        for _, mode in ipairs(modes) do
          check(
            vim.tbl_contains({ 'n', 'v', 'x', 's', 'o', 'i', 'l', 'c', 't', '!' }, mode),
            'keymap mode'
          )
        end
        value = value.action
      end
      check(value == false or type(value) == 'function', 'keymaps.' .. key)
    end
  end
end

-- Merge user options into private defaults.
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == 'table', 'terminal: options must be a table')
  local supplied = copy(opts)
  local resolved = vim.tbl_deep_extend('force', vim.deepcopy(defaults), supplied)
  validate(resolved)
  options = resolved
end

-- Return an isolated copy of the configured preferences.
---@return terminal.Config
function M.get()
  if not options then
    error('terminal: setup() must be called before using the API')
  end
  return copy(options)
end

return M

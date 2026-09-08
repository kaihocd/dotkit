local M = {}

---@type string[]
local BASE24_KEYS = {
  'base00',
  'base01',
  'base02',
  'base03',
  'base04',
  'base05',
  'base06',
  'base07',
  'base08',
  'base09',
  'base0A',
  'base0B',
  'base0C',
  'base0D',
  'base0E',
  'base0F',
  'base10',
  'base11',
  'base12',
  'base13',
  'base14',
  'base15',
  'base16',
  'base17',
}

---@return string
local function active_theme_path()
  local state_home = vim.fs.dirname(vim.fn.stdpath('state'))
  return vim.fs.joinpath(state_home, 'palette', 'active-theme.json')
end

---@param condition boolean
---@param message string
local function validate(condition, message)
  if not condition then
    error('Invalid Palette active theme: ' .. message, 0)
  end
end

---@param value unknown
---@return palette.PaletteTheme
local function parse(value)
  validate(type(value) == 'table', 'expected an object')
  ---@cast value table
  validate(type(value.id) == 'string' and value.id ~= '', 'invalid id')
  validate(type(value.name) == 'string' and value.name ~= '', 'invalid name')
  validate(value.author == nil or type(value.author) == 'string', 'invalid author')
  validate(value.variant == 'dark' or value.variant == 'light', 'invalid variant')
  validate(type(value.palette) == 'table', 'invalid palette')
  ---@type table<string, unknown>
  local colors = value.palette

  for _, key in ipairs(BASE24_KEYS) do
    local color = colors[key]
    validate(
      type(color) == 'string' and color:match('^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$'),
      'invalid ' .. key
    )
  end

  ---@cast value palette.PaletteTheme
  return value
end

---@return palette.PaletteTheme theme
---@return string contents
function M.load()
  local path = active_theme_path()
  local file, open_error = io.open(path, 'r')
  if not file then
    error('Failed to read Palette active theme: ' .. path .. ': ' .. tostring(open_error), 0)
  end

  local contents = file:read('*a')
  file:close()

  local decoded_ok, decoded = pcall(vim.json.decode, contents)
  if not decoded_ok then
    error('Invalid JSON in Palette active theme: ' .. path, 0)
  end

  return parse(decoded), contents
end

---@return string
function M.directory()
  return vim.fs.dirname(active_theme_path())
end

return M

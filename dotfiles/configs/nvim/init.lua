-- Shared startup paths; keep runtime/session state out of this table.
_G.G = {}

---Absolute configuration path with symlinks resolved.
G.config_root = assert(
  vim.uv.fs_realpath(vim.fn.stdpath('config')),
  'Unable to resolve Neovim configuration directory'
)

--- Local plugins stored beside the configuration directory.
G.local_plugins_root = vim.fs.joinpath(vim.fs.dirname(G.config_root), 'nvim-pack')

require('configs').setup()
require('enhance').setup()
require('palette').setup()
require('plugins').setup()

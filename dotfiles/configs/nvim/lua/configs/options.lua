-- Leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Netrw
vim.g.netrw_banner = 0
vim.g.netrw_list_hide = [[\(^\|\s\s\)\zs\.\S\+]]
vim.g.netrw_winsize = 25
vim.g.netrw_liststyle = 3
vim.g.netrw_keepdir = 0
vim.g.netrw_sort_sequence = [[[\/]$,*]]

-- UI
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.signcolumn = 'yes'
vim.opt.fillchars = { msgsep = '─', eob = ' ', diff = '╱' }
vim.opt.mouse = 'a'
vim.opt.cursorline = true
vim.opt.cursorlineopt = 'number'
vim.opt.laststatus = 3
vim.opt.showmode = false
vim.opt.cmdwinheight = 1

-- Wrapping and indentation
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = 'list:-1'
vim.opt.list = true
vim.opt.listchars = { trail = '·', tab = '→ ', nbsp = '␣' }
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = -1
vim.opt.expandtab = true
vim.opt.shiftround = true

-- Editing
vim.opt.virtualedit = 'block'
vim.opt.undofile = true
vim.opt.clipboard = 'unnamedplus'
vim.opt.confirm = true

-- Windows and splits
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.splitkeep = 'screen'
vim.opt.scrolloff = 2
vim.opt.smoothscroll = true
vim.opt.winborder = 'single'

-- Searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.grepprg = 'rg --vimgrep'
vim.opt.grepformat = '%f:%l:%c:%m'

-- UX
vim.opt.jumpoptions:append({ 'stack', 'view' })
vim.opt.completeopt:append('noselect')
vim.opt.wildmenu = false
vim.opt.timeoutlen = 500
vim.opt.updatetime = 500
vim.opt.shortmess:append({ W = true, c = true, C = true })

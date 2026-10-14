local M = {}

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = 'Git graph' })
end

local function open_commit(commit)
  local parent = commit.parents[1]

  if not parent then
    -- Ask Git for the empty tree instead of hardcoding a SHA-1 object ID.
    local process = vim.system({ 'git', 'hash-object', '-t', 'tree', '--stdin' }, {
      stdin = '',
      text = true,
    })
    local result = process:wait()
    if result.code ~= 0 then
      warn('Unable to resolve the empty tree for the initial commit.')
      return
    end

    parent = vim.trim(result.stdout)
  end

  require('diffview').open({ parent .. '..' .. commit.hash })
end

local function open_graph()
  local cwd = vim.fn.getcwd()
  local process = vim.system({ 'git', '-C', cwd, 'rev-parse', '--show-toplevel' }, { text = true })
  local repository = process:wait()
  if repository.code ~= 0 then
    warn('The current directory is not inside a Git working tree.')
    return
  end

  local root = vim.trim(repository.stdout)
  local head = vim.system({ 'git', '-C', root, 'rev-parse', '--verify', 'HEAD' }):wait()
  if head.code ~= 0 then
    warn('This repository has no commits to display.')
    return
  end

  vim.cmd('tabnew')
  vim.cmd.tcd(root)
  require('gitgraph').draw({}, { all = true, max_count = 1000 })
  vim.keymap.set('n', 'q', '<Cmd>tabclose<CR>', { buffer = true, desc = 'Close Git graph' })
  vim.keymap.set('n', '<C-r>', function()
    require('gitgraph').draw({}, { all = true, max_count = 1000 })
  end, { buffer = true, desc = 'Refresh Git graph' })
end

function M.config()
  require('gitgraph').setup({
    symbols = {
      merge_commit = '',
      commit = '',
      merge_commit_end = '',
      commit_end = '',

      GVER = '',
      GHOR = '',
      GCLD = '',
      GCRD = '╭',
      GCLU = '',
      GCRU = '',
      GLRU = '',
      GLRD = '',
      GLUD = '',
      GRUD = '',
      GFORKU = '',
      GFORKD = '',
      GRUDCD = '',
      GRUDCU = '',
      GLUDCD = '',
      GLUDCU = '',
      GLRDCL = '',
      GLRDCR = '',
      GLRUCL = '',
      GLRUCR = '',
    },
    format = {
      timestamp = '%Y-%m-%d %H:%M',
      fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
    },
    hooks = {
      on_select_commit = open_commit,
      -- Compare endpoint snapshots, including across branches. This also
      -- works when either endpoint is the initial commit.
      on_select_range_commit = function(from, to)
        require('diffview').open({ from.hash .. '..' .. to.hash })
      end,
    },
  })

  vim.keymap.set('n', '<leader>gG', open_graph, { desc = 'Git commit graph' })
end

return M

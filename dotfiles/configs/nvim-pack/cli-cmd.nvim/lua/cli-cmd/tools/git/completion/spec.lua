---Curated Git knowledge that Git does not expose itself.
---
---Discovery covers subcommands and most options, but `git log --oneline`,
---`--since=`, `--author=` and friends never appear in
---`git <cmd> --git-completion-helper`; Git's own `git-completion.bash` hardcodes
---them too. This module holds only those gaps plus the semantics discovery
---cannot express: which value an option takes and what a positional means.
---
---Nothing here invents behaviour beyond `git`: every entry mirrors an option Git
---accepts or a rule Git's own completion script already encodes.
local M = {}

---Options that are valid before the subcommand only.
M.global_options = {
  '--bare',
  '--exec-path',
  '--git-dir',
  '--help',
  '--literal-pathspecs',
  '--no-pager',
  '--no-replace-objects',
  '--paginate',
  '--version',
  '--work-tree',
  '-C',
  '-c',
  '-p',
}

---Global options that consume a value, and where the value comes from.
M.global_values = {
  ['-C'] = 'paths',
  ['-c'] = 'none',
  ['--config-env'] = 'none',
  ['--exec-path'] = 'paths',
  ['--git-dir'] = 'paths',
  ['--namespace'] = 'none',
  ['--work-tree'] = 'paths',
}

---Value source for options discovery already reports as value-taking. Options
---missing here return no candidates instead of falling back to paths.
M.value_kinds = {
  ['--after'] = 'dates',
  ['--author'] = 'authors',
  ['--before'] = 'dates',
  ['--committer'] = 'authors',
  ['--contains'] = 'refs',
  ['--date'] = 'dates',
  ['--file'] = 'paths',
  ['--fixup'] = 'refs',
  ['--onto'] = 'refs',
  ['--pathspec-from-file'] = 'paths',
  ['--points-at'] = 'refs',
  ['--reedit-message'] = 'refs',
  ['--reuse-message'] = 'refs',
  ['--set-upstream-to'] = 'refs',
  ['--since'] = 'dates',
  ['--source'] = 'refs',
  ['--squash'] = 'refs',
  ['--strategy'] = 'strategies',
  ['--until'] = 'dates',
}

---Options Git accepts but does not report through `--git-completion-helper`.
M.extra_options = {
  log = {
    '--all',
    '--author=',
    '--branches',
    '--decorate',
    '--first-parent',
    '--graph',
    '--grep=',
    '--max-count=',
    '--merges',
    '--no-merges',
    '--oneline',
    '--pretty=',
    '--remotes',
    '--since=',
    '--tags',
    '--until=',
  },
  show = { '--oneline', '--pretty=', '--stat', '--name-only', '--name-status' },
  diff = { '--cached', '--staged', '--name-only', '--name-status', '--stat' },
  ['cherry-pick'] = { '--abort', '--continue', '--skip', '--no-commit' },
  ['rev-parse'] = { '--abbrev-ref', '--show-toplevel', '--verify' },
}

---What the positional arguments of a subcommand mean. A list means the kind
---depends on the position: `git push <remote> <refspec>`.
M.positionals = {
  add = 'paths',
  blame = 'paths',
  checkout = 'refs',
  clean = 'paths',
  commit = 'paths',
  diff = 'paths',
  fetch = { 'remotes', 'refs' },
  grep = 'paths',
  log = 'refs',
  merge = 'refs',
  mv = 'paths',
  pull = { 'remotes', 'refs' },
  push = { 'remotes', 'refs' },
  rebase = 'refs',
  reset = 'refs',
  restore = 'paths',
  revert = 'refs',
  rm = 'paths',
  show = 'refs',
  switch = 'refs',
  tag = 'refs',
}

---Merge strategies Git ships with, used by `--strategy=`.
M.strategies = { 'ort', 'recursive', 'resolve', 'octopus', 'ours', 'subtree' }

---Relative dates Git parses, offered for `--since=` and friends.
M.dates = { 'now', 'today', 'yesterday', '1 week ago', '2 weeks ago', 'last month', 'last year' }

return M

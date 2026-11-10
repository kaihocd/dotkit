# cli.nvim

Neovim CLI integration, used as a command and extended as a framework.

`require('cli.git').setup()` installs `:Git`. Underneath it are Context, Router, Task,
Dispatcher, the process and terminal backends, the external terminal protocol, the
Git adapter and its completion, and the editor bridge that hands commit messages
back to Neovim. Those modules stay public for tools that have no preset yet; see
[`docs/api.md`](docs/api.md) for their signatures.

## Entry point

```lua
require('cli.git').setup()
```

That is the whole integration: it registers `:Git`, runs Git in the current directory, edits commit messages in this Neovim and completes from Git's own output.

`G` is one option away. `alias` adds a second name for the same command — `:Git` stays, `:G` joins it — while `command` renames the command outright:

```lua
require('cli.git').setup({ alias = 'G' })     -- :Git and :G
require('cli.git').setup({ command = 'G' })   -- :G only
```

Prefer an alias to Vim's abbreviation: `:G` is ambiguous the moment another command starts with `G` (`:Glance` is enough, `E464`), an alias is an exact name.

Commands that start from fixed arguments are `presets`:

```lua
require('cli.git').setup({
  alias = 'G',
  presets = {
    Gs = { argv = { 'status', '--short', '--branch' }, desc = 'status' },
    Gl = { argv = { 'log', '--oneline', '-20' }, desc = 'log' },
  },
  editor = false,      -- let Git use its own editor instead of this Neovim
  completion = false,  -- no completion at all
})
```

| Option | Default | Notes |
| --- | --- | --- |
| `command` | `'Git'` | Name of the command |
| `alias` | — | Another name, or a list of names, for the same command |
| `presets` | — | `{name = {argv = {...}, desc = '...'}}` extra commands; typed arguments are appended |
| `cwd` | current directory | Pass a path to pin the directory |
| `editor` | `true` | Commit messages open in this Neovim; a table forwards bridge options, `false` leaves `EDITOR` alone |
| `completion` | `true` | Provider options, `false`, or a per-directory factory |
| `presenter` | `vim.notify` | Any presenter, or `false` |
| `routes` / `replace_routes` / `fallback` / `backends` / `env` / `executable` / `terminal_capability` / `terminal_layout` | — | Forwarded to the Git adapter |

Three things are deliberate:

- The working directory is resolved **per invocation**, so the command follows `:cd` and window-local directories; completion does the same.
- Calling `setup` again replaces the previous installation: its commands and its editor bridge are released first, so changing a name never leaves the old one behind.
- An unknown option is an error, not something quietly ignored.

A tool without a built-in preset goes through `define`, which takes the same options plus an executable:

```lua
require('cli').define('brew', {
  executable = 'brew',                     -- :Brew
  alias = 'B',
  presets = { Bl = { argv = { 'list' } } }, -- :Bl list…, :Bl as pre-typed
  route_key = function(argv) return 'capture' end,
  routes = { capture = 'process', interactive = 'terminal' },
})
```

`routes` decides execution, not presentation: `process` captures output and reports it through the presenter, `terminal` gets a real tty. A route key names what the invocation *needs*, not which subcommand it is, so a tool with no interactive mode answers `capture` every time and one preset serves every command. The framework modules behind both entry points stay public and independently usable — see [`docs/api.md`](docs/api.md) — but you do not need them to use `:Git`.

## Context

`require('cli.context').new(input)` validates and snapshots one invocation:

```lua
local ctx = require('cli.context').new({
  executable = 'git',
  argv = { '-C', 'a directory', 'status' },
  raw_input = [[-C a\ directory status]],
  cwd = vim.fn.getcwd(),
  env = { GIT_OPTIONAL_LOCKS = '0' }, -- optional string overrides
  route_key = 'status', -- optional; supplied by the adapter
})
```

- `argv` excludes the executable. Context never infers the route from `argv[1]`.
- User command inputs use Neovim `fargs`: escape spaces with `\`, not quotes.
- Programmatic argv is preserved literally, including empty arguments.
- Context performs no expansion, shell execution, cwd change or environment mutation.
- `cwd` is supplied explicitly; directory existence and executable availability are execution concerns.
- argv/env are copied so invocations do not share caller-owned tables. Returned tables are ordinary Lua tables, not enforced read-only objects.
- Environment values are strings; an empty string is allowed. Environment deletion is not part of this interface.

## Router

```lua
local router = require('cli.router').new({
  handlers = { process = process_handler, terminal = terminal_handler },
  routes = { commit = 'process', inspect = custom_handler },
  fallback = 'terminal', -- default; may also be a custom Terminal handler function
})
local handler = router:resolve(ctx)
```

- Routes match `ctx.route_key` exactly; missing or unmatched keys always select the fallback.
- Router returns a function without invoking it, creating Tasks, or interpreting argv.
- The caller supplies the Terminal fallback; Router has no backend dependencies and cannot inspect what a handler does.
- Unknown handler references, invalid registrations and missing fallback handlers fail at construction, not at execution.
- Registration tables are snapshotted; changing caller tables does not reconfigure existing routers.
- Dispatcher will own invoking the returned handler with `(ctx, task)`.

## Task

`require('cli.task').new(metadata)` owns one invocation lifecycle:

```text
created -> running -> cancelling -> finished
created -> running -> finished
```

- `start()` emits `start`.
- `output('stdout'|'stderr', chunk)` emits output while unfinished; late output is ignored.
- `cancel()` requests cancellation and emits `cancel`; it does not claim the process has terminated.
- `complete(result)` accepts `exit`, `delegated` (target `terminal`), `error`, or `cancelled`, emits one `result`, and removes listeners.
- `finish(result)` is the backends' form: a finished task returns `false` instead of raising, and a cancelling task always reports `cancelled`. That keeps the lifecycle decision here rather than in every backend.
- Duplicate completion and invalid transitions are errors; output after completion returns `false`.
- Listeners receive a copied event and the Task. The returned function removes one listener.

## Command configuration

`require('cli.command').new(opts)` builds one isolated command definition. It supplies native Process and Native Terminal handlers by default, while allowing named custom backends and an injected external terminal capability:

```lua
local command = require('cli.command').new({
  executable = 'git',
  cwd = vim.fn.getcwd(),
  routes = { status = 'process' },
  terminal_capability = optional_capability,
})
local task = command:dispatch({
  argv = { 'status' },
  raw_input = 'status',
  route_key = 'status',
})
```

Command construction snapshots environment and backend registrations. Dispatch constructs a validated Context, then uses the existing Router and Dispatcher. `command:register(name, opts)` adds a native Neovim user command with `nargs = '*'`; its callback forwards Neovim's `fargs` and `args` directly, without reparsing quotes. `opts.route_key` may be a string or a function receiving `(fargs, command_opts)`, and `opts.complete` is passed to Neovim's native command completion API.

## Git adapter

`require('cli.adapter.git').route_key(argv)` answers what an invocation needs from its surface: `interactive` when the child must talk to a human, `capture` when it can run unattended. It reads argv, not a table of subcommands:

- a conversational option anywhere before `--`: `-p`, `--patch`, `-i`, `--interactive`, `--paginate`, `--help`;
- a subcommand that only works with a human: `mergetool`, `bisect`, `help`;
- a subcommand that may stop for a password: `push`, `pull`, `fetch`, `clone`, `submodule`, `ls-remote`.

Everything else is captured, so `add .` is quiet while `add -p` asks questions. Values are read literally: an argument spelled exactly like one of those options also asks for a terminal, and `--` ends the search.

`require('cli.adapter.git').subcommand(argv)` gives the identity instead — the first Git subcommand after supported global options such as `-C`, `-c`, `--git-dir`, `--work-tree`, and `--no-pager`, or `nil` when there is none. Neither function mutates argv, executes Git, or infers command success; malformed options fail with a `cli.git:` error.

`require('cli.adapter.git').new(opts)` builds a Command definition with `git` as the default executable. It requires `cwd` and accepts the same backend/capability configuration as Command.

Routes come from a default preset, so a command definition is useful before any routing decisions are made:

```lua
local Git = require('cli.adapter.git')

Git.new({ cwd = cwd })                                        -- the preset as-is
Git.new({ cwd = cwd, routes = { interactive = 'process' } })   -- preset + your overrides
Git.new({ cwd = cwd, routes = { capture = 'terminal' }, replace_routes = true })  -- preset ignored
```

`Git.default_routes()` returns a copy of the preset and `Git.default_fallback` (`'terminal'`) covers route keys the preset does not name. Copies are decoupled, so mutating one never leaks into later definitions.

The preset has one entry per surface, not per subcommand:

| Route key | Backend | Meaning |
| --- | --- | --- |
| `interactive` | `terminal` | The child pages, prompts, or holds the keyboard, so it needs a real tty |
| `capture` | `process` | The child runs unattended; `/dev/null` on stdin, output reported by the presenter |

`commit` is captured because the editor bridge already sends `GIT_EDITOR` back to this Neovim instance: the message opens here and hook output arrives in one report.

Registering does not touch the existing mini-git setup:

```lua
local git = require('cli.adapter.git').new({ cwd = vim.fn.getcwd() })
git:register('MyGit', { route_key = require('cli.adapter.git').route_key })
```

## Completion

Completion is independent of routing and execution. `require('cli.completion')` owns the Neovim callback plumbing: it splits the command line with native `fargs` rules (backslash escapes, quotes do not group), passes `{ tokens, arglead, cmdline }` to a provider, filters by the unfinished token and escapes spaces so each candidate is inserted as one argument.

Git candidates are generated by our own provider, not by mini.git. It is layered so the parts Git can answer are never hand-written:

| Layer | Module | Source |
| --- | --- | --- |
| Vocabulary | `cli.completion.git.discover` | `git --list-cmds=main,others` and `git <cmd> --git-completion-helper` |
| Semantics | `cli.completion.git.spec` | The small set of facts Git does not expose |
| Candidates | `cli.completion.git` | Paths, refs, remotes and authors, all overridable |

Discovery supplies subcommands, per-subcommand options and nested words (`git stash <Tab>` offers `apply clear drop pop …`). Options ending in `=` tell us which options take a value, so no option table has to be maintained. An upgraded Git is picked up because every cache key includes `git --version`.

`spec.lua` only holds what Git refuses to describe: which value an option wants (`--author=` authors, `--since=` dates, `--onto=` refs, `--file=` paths), what a positional argument means (`checkout` refs, `add` paths, `push <remote> <refspec>`), and the options missing from `--git-completion-helper` (`--oneline`, `--graph`, `--since=`, …). Git's own `git-completion.bash` hardcodes the same list in `__git_log_common_options`.

```lua
local Git = require('cli.adapter.git')
local GitCompletion = require('cli.completion.git')

git:register('MyGit', {
  route_key = Git.route_key,
  complete = GitCompletion.callback({ cwd = repo_root }),
})
```

Behaviour worth knowing:

- After a subcommand only that subcommand's vocabulary is offered; global options such as `--no-pager` and `--bare` are offered only before it.
- An unknown option stops completion instead of falling back to paths. `git commit -m <Tab>` and `git checkout -b <Tab>` return nothing, because guessing an unnamed value is worse than silence.
- Outside a repository `--git-completion-helper` refuses to run, so there are no refs, paths or options to offer. Missing completions outside a repository is accepted on purpose; no fallback list is kept.
- Discovery is cached per `(git version, directory, subcommand)` and sources are memoised for two seconds, so a keystroke burst spawns Git at most once per source.
- Every Git candidate source runs through `Discover:run`, the same bounded call discovery uses, so a timeout or a failing Git has one behaviour. `opts.sources` replaces *what* is asked; it does not bring its own process handling.
- The provider decides in a fixed list of rules (`pending option`, `--opt=value`, `--`, option names, subcommands, positionals, subcommand words). That list is the priority order.
- `-C <dir>` moves the base directory used for path candidates.
- `-c`, `--config-env` and `--namespace` have no candidates: their values are config keys, not paths.

## Native Terminal Backend

The default interactive backend is `cli.backend.native_terminal`. It uses Neovim's native `termopen()` with an argv list, owns the created terminal buffer/job, streams terminal output to Task, reports the real exit code, and can cancel only its own job. It does not require or load `terminal.nvim`.

The terminal is presented in a new tab by default, so an interactive command never replaces the current view; the tab stays open after the command finishes so its output remains readable. Placement is configurable per command definition:

```lua
Command.new({ executable = 'git', cwd = cwd })                            -- default: tab
Command.new({ executable = 'git', cwd = cwd, terminal_layout = 'split' })  -- also 'vsplit'
```

An unknown layout is rejected at construction. A failed spawn opens no tab and leaves no buffer behind.

### Swapping in an external terminal later

`terminal.nvim` is deliberately not wired in yet. When that changes, the work stays in the user configuration layer — no core change is required:

```lua
-- user config, not this plugin
local capability = {
  delegate = function(ctx, task)
    local terminal = require('terminal')
    local session = terminal.new({ cmd = ctx.executable, args = ctx.argv, cwd = ctx.cwd, env = ctx.env })
    terminal.open(session)
    return { cancel = function() terminal.close(session) end }
  end,
}
local git = require('cli.adapter.git').new({ cwd = cwd, terminal_capability = capability })
```

Constraints that shape that adapter, and the reasons the protocol looks the way it does:

- `terminal.nvim` currently exposes session and UI management only (`new`/`open`/`close`/`hide`/`toggle`/`select`/`focus_*`/`shutdown`); it has no `execute()`/`send()`. The adapter therefore starts a command per delegation rather than typing into a persistent shell.
- A capability cannot report an exit code today, so the Task ends as `delegated`, never as `exit 0`. Reporting a real code would need an exit hook from `terminal.nvim`; until then, do not present `delegated` as success.
- The two plugins must stay independent: `cli.nvim` never requires `terminal.nvim`, and no intermediate plugin is introduced. The only coupling point is `terminal_capability`.
- Once a capability is injected, it replaces the native tab behaviour for terminal routes; `terminal_layout` only affects the native backend.

An external terminal capability can be injected through `cli.backend.terminal`: `{ delegate = function(ctx, task) return handle_or_nil end }`. The capability receives the original argv Context and may return an optional `{ cancel = function() end }` handle. The backend completes the Task as `{ kind = 'delegated', target = 'terminal' }`; it never treats sending a command to a persistent shell as exit success. A capability failure becomes a Task error and is rethrown. This is a protocol only: `cli.nvim` does not require or load `terminal.nvim`.

## Presentation

Every dispatched command attaches a presenter, so results are visible without extra wiring. The default presenter reports a short result through `vim.notify`, which means one override of `vim.notify` takes over every short report; a report too long for the message area (more than `max_lines`, 15 by default) opens in a read-only scratch tab instead:

```lua
local presenter = require('cli.presenter.output').new()
local git = require('cli.adapter.git').new({ cwd = cwd, presenter = presenter })
git:register('Git', { route_key = require('cli.adapter.git').route_key })
```

Rules, all covered by tests:

- Output is buffered per task and emitted once when the task finishes; there is no per-line spam.
- Size picks the channel: up to `max_lines` lines notify, more than that open a scratch tab (`:q` closes it), so `git log` never floods the message area.
- `stdout` and `stderr` are merged in arrival order, with trailing blank lines and carriage returns normalized.
- A successful exit with no output stays silent, so ordinary commands do not fill the message area.
- A failing exit, spawn error, or cancellation always reports, falling back to `exit N`, the error message, or `cancelled` when there is no output.
- `delegated` is not reported: the terminal session already shows the command.
- Tasks annotated with `surface = 'terminal'` are not reported either: the native terminal tab already shows the output, and duplicating it in a message would be noise. Backends annotate through `task:annotate('surface', 'terminal')`.
- `Task:metadata()` returns a copy, so presenters can read execution facts without mutating task state.
- Levels are `INFO` for success, `ERROR` for failures, `WARN` for cancellation.
- `vim.notify` is resolved at emit time, not at construction, so a later override still applies.
- `presenter = false` disables presentation for a command definition.

Whether a multi-line notification pauses for `Press ENTER` is decided by the UI, not by this plugin: Neovim's built-in message area does pause, while a UI attached with `ext_messages` receives the same message as a `msg_show` event and never blocks.

## Editor Bridge

`require('cli.bridge.editor').new(opts)` opens files that an external process asks this Neovim instance to edit. It is a shared capability, not part of any backend:

```lua
local bridge = require('cli.bridge.editor').new({ cwd = repo_root })
local git = require('cli.adapter.git').new({ cwd = repo_root, editor = bridge })
local task = git:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'capture' })
```

### Presentation

`layout` selects the built-in presentation; the default is a horizontal split because it disturbs the current view the least:

```lua
new({ layout = 'split' })  -- default
new({ layout = 'vsplit' })
new({ layout = 'tab' })
```

Anything else goes through `open`, which receives the file path and owns the placement entirely:

```lua
new({
  open = function(path)
    vim.cmd('botright 15split ' .. vim.fn.fnameescape(path))
  end,
})
```

An unknown `layout` is rejected at construction rather than silently falling back. Reusing the current window is deliberately not a layout: in the last-window case the close signal becomes ambiguous. Use `open` if you want that behaviour.

Mechanism, verified against Neovim 0.12.4 and real Git in the test suite:

1. `bridge:env()` returns `GIT_EDITOR` / `GIT_SEQUENCE_EDITOR` pointing at this Neovim with a generated `-u` config. The config is one line: it `dofile`s `lua/cli/bridge/serve.lua`, and which bridge to talk to arrives in the environment (`CLI_EDITOR_ID`, `CLI_EDITOR_SERVER`), so no value is ever spliced into Lua source.
2. Git runs that headless Neovim. `serve.lua` connects back over RPC and asks this instance to open the file, then stays alive and keeps Git blocked.
3. Closing the edit window finishes the session; the headless editor is notified with `quitall!` and exits 0, so Git continues.
4. `bridge:cancel()` notifies it with `cquit 1`, so Git fails and no commit is created.

Two liveness rules keep an abandoned edit from blocking a repository forever, both verified in a real terminal:

- The external editor waits in an event loop and pings this instance, so it notices a closed channel and exits nonzero. Killing Neovim with `SIGKILL` therefore still releases Git instead of leaving `git commit` blocked forever.
- Quitting Neovim normally releases every pending session first (`VimLeavePre` sends `cquit 130`), so `:qa!` with a commit message open leaves no stray editor and no stray Git process.
- The external editor is started with `-n`: Git passes the edited file as an argument, and without it that process would open a second buffer for the file this instance owns and warn (`W325`) into the command output.

Semantics, all covered by tests:

- `:w` alone does not release the external process.
- Session completion is closing the edit window or buffer, not saving, and it behaves the same in every layout.
- Failure propagates as a real non-zero editor exit code, so hooks and Git behave normally.
- Nothing blocks the current Neovim event loop: the bridge never calls `vim.wait`.
- A signal is never reported as success: a command killed by a signal becomes exit `128 + signal`, as a shell would report it.
- Hook order stays Git's own (`pre-commit`, `prepare-commit-msg`, editor, `commit-msg`); the bridge never emulates hooks.

The bridge owns temporary config files and an RPC registry entry; call `bridge:dispose()` when the command is finished. Multiple bridges are independent because each gets its own request id.

## Unit tests

From the repository root:

```sh
nvim --clean --headless -i NONE -l dotfiles/configs/nvim-pack/cli.nvim/tests/run.lua
```

The dependency-free Lua runner discovers `tests/test_*.lua`, reports cases, and exits nonzero on failure. Shared helpers live in `tests/support.lua`. Tests use actual Neovim APIs, including native user-command parsing. `test_integration.lua` exercises the real `Dispatcher → Router → Task → Backend` chains with `vim.system()` and `termopen()` subprocesses; `test_editor_bridge.lua` and `test_git_editor_integration.lua` run real `git commit` against temporary repositories, including hooks and a real editor round trip.

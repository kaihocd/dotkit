# API reference

Every module is usable on its own. Nothing here registers global state, reads user configuration, or loads `terminal.nvim`; composition happens in the caller.

Dependency direction (top depends on bottom, never the reverse):

```
init ── install ── tool
tools/git/init ── install ── tools/git/command, tools/git/completion, bridge/editor, presenter/output
                          ── tools/git/command ─┬─ command ─┬─ dispatcher ── router
                                                │           ├─ context
                                                │           ├─ task
                                                │           └─ backend/{process,native_terminal,external_terminal}
                                                ├─ tools/git/completion ── completion
                                                ├─ bridge/editor
                                                └─ presenter/output
```

| Module | Owns | Never does |
| --- | --- | --- |
| `cli-cmd.context` | Snapshot of one invocation | Parse Git options, pick a backend |
| `cli-cmd.router` | Route key → handler | Execute anything |
| `cli-cmd.task` | Lifecycle, output ordering, result | Know about processes or buffers |
| `cli-cmd.dispatcher` | Create Task → resolve handler → run | Choose handlers |
| `cli-cmd.command` | One command definition + `:Command` registration | Know which tool it runs |
| `cli-cmd.backend.*` | Start a process / terminal | Decide policy or presentation |
| `cli-cmd.presenter.output` | Turn a finished Task into one report | Render terminal output |
| `cli-cmd.presenter.registry` | Named sinks: config in, presenter out | Know which tool asked |
| `cli-cmd.bridge.editor` | Give Git an editor that talks back over RPC | Know which Git command asked |
| `cli-cmd.tool` | What a tool is: options, names, validation | Create anything |
| `cli-cmd.install` | Turning a spec into user commands, and releasing them | Know Git or any preset |
| `cli-cmd.bridge.serve` | The external editor's own script | Not a module: loaded by the child with `dofile` |
| `cli-cmd.completion*` | Candidate lists | Execute or route |
| `cli-cmd.tools.git.command` | Git's argv rules and its Command builder | Force a naming or registration policy |
| `cli-cmd.tools.git` | The declaration behind `:Git` | Contain anything another tool needs |
| `cli-cmd.tools.palette` | The declaration behind `:Palette`; no routes, everything captured | Need a Command of its own |
| `cli-cmd.tools.brew` | The declaration behind `:Brew`; routing in `command.lua`, candidates in `completion/` | Need a Command of its own |
| `cli-cmd` (`init.lua`) | Loading a built-in tool, or one you declare | Know a tool's routing |

---

## Entry points

Two entry points, both installing user commands and both idempotent by tool name.

`require('cli-cmd').install(name, opts)` loads a built-in tool: the module `lua/cli-cmd/tools/<name>/init.lua`, which returns a `cli-cmd.ToolSpec`. The name is resolved through Neovim's runtime path, and a name with no directory fails as `cli-cmd: no built-in tool: <name>` instead of a Lua module error. `opts` overrides whatever the tool declared, so `install('git')` with no options registers `:Git` exactly as the Git tool describes it.

| Option | Default | Notes |
| --- | --- | --- |
| `command` | `'Git'` | The command's name |
| `presets` | — | `{name = {argv?, desc?}}`; `argv` is a preset list, `fargs` are appended |
| `cwd` | current directory | A string pins the directory for every invocation |
| `editor` | `true` | `true` builds a `cli-cmd.bridge.editor` with defaults; `false` installs none |
| `completion` | the tool's provider | `false`, or a `fun(cwd): provider` factory |
| `presenter` | a `cli-cmd.presenter.output` | Any presenter instance, or `false` |
| `routes` / `replace_routes` / `fallback` / `backends` / `env` / `executable` / `terminal_capability` / `terminal_layout` | — | Merged into the spec; the tool's `build` decides what to do with them |

`require('cli-cmd').define(name, spec)` installs a tool that has no directory here. The spec is `cli-cmd.ToolSpec` — `cli-cmd.ToolOptions` plus an optional `build`/`route_key` — with `executable` required and `completion` given as a `fun(cwd): provider` factory; the default command name is `name` with a capital first letter (`brew` → `:Brew`), and the default route for anything unrouted is the terminal backend.

```lua
require('cli-cmd').define('brew', {
  executable = 'brew',
  route_key = function(argv) return argv[1] end,
  routes = { list = 'process' },
  completion = function(cwd) return my_provider end,
})
```

Both return a `cli-cmd.Tool`: `{ name, command, commands, editor, presenter }`. `commands` lists the registered names, the main name first; `command` is the underlying `cli-cmd.command` instance. `require('cli-cmd.install').dispose(name)` releases a tool's commands and editor bridge, and `install` does that automatically before replacing a name.

`cli-cmd.tool` is the part that can be reasoned about without side effects: `validate(spec)` rejects what cannot be installed, `names(spec)` returns the names and the order to register them in. `cli-cmd.install` owns everything that leaves a trace, including the one piece of module-level state in the framework — the map of installed tools by name.

Rules that apply to both:

- The working directory is resolved when the command runs, never at install time, unless `cwd` is given.
- Completion is built once per directory, and preset `argv` reaches the provider as tokens.
- Short names are not implied: `:G` is only Vim's abbreviation of `:Git`, and it becomes ambiguous as soon as another `G*` command exists. A tool answers to one name, `command`; a second one is your own config's business (`command! -nargs=* -complete=customlist,…`).
- Unknown options are rejected (`cli-cmd.tool: unknown option: <key>`), so a typo cannot silently do nothing.
- A name another plugin already registered is refused (`cli-cmd.tool: command already exists: <name>`) rather than taken over, and a failed install rolls back the commands it had created.

---

## Context

`require('cli-cmd.context').new(input)`

| Field | Type | Notes |
| --- | --- | --- |
| `executable` | `string` | Resolved program name, e.g. `'git'` |
| `argv` | `string[]` | Arguments, executable excluded. Needs to be a list |
| `cwd` | `string` | Explicit execution directory, must exist |
| `env` | `table<string,string>?` | Per-invocation environment overrides |
| `route_key` | `string?` | Supplied by the adapter; never inferred from `argv[1]` |

```lua
local Context = require('cli-cmd.context')
local ctx = Context.new({
  executable = 'git',
  argv = { 'status', '--short' },
  cwd = vim.fn.getcwd(),
  route_key = 'capture',
})
```

Context is a validated copy: it does not read the environment, resolve paths, or interpret flags.

---

## Router

`require('cli-cmd.router').new({ handlers, routes, fallback })` → `router:resolve(ctx)`

- `handlers`: `table<string, fun(ctx, task)>` — names to functions.
- `routes`: `table<string, string|function>` — route key to a handler name or an inline function.
- `fallback`: handler name or function. **Required** — a Router does not guess where an argv goes; `cli-cmd.command`'s `Command.defaults` supplies the tool layer's value, so only a caller constructing a Router directly has to state it.

Both `routes` and `fallback` are resolved at construction, so an unknown name fails immediately with `cli-cmd.router: unknown handler: <name>` instead of at dispatch time. Omitting `fallback` fails too, with `fallback is required` — a resolver that invented one would hide a missing registration.

```lua
local Router = require('cli-cmd.router')
local router = Router.new({
  handlers = {
    quiet = function(_, task) task:complete({ kind = 'exit', code = 0 }) end,
    interactive = function(_, task) task:complete({ kind = 'delegated', target = 'terminal' }) end,
  },
  routes = { status = 'quiet', log = 'interactive' },
  fallback = 'interactive',
})
router:resolve({ route_key = 'status' })  -- the quiet function
router:resolve({ route_key = nil })       -- the fallback
```

---

## Task

`require('cli-cmd.task').new(metadata?)`

| Method | Result | Notes |
| --- | --- | --- |
| `task:start()` | `task` | `created` → `running` |
| `task:output(stream, data)` | `boolean` | `stream` is `'stdout'` or `'stderr'`; ignored after completion |
| `task:complete(result)` | `boolean` | `running`/`cancelling` → `finished`; rejects a second result |
| `task:finish(result)` | `boolean` | Same, but a finished task returns `false` and a cancelling one reports `cancelled`. Backends use this |
| `task:cancel()` | `boolean` | `running` → `cancelling`; emits `cancel` |
| `task:status()` | `'created'\|'running'\|'cancelling'\|'finished'` | |
| `task:result()` | `table?` | Copy of the terminal result |
| `task:on(callback)` | `fun()` unsubscribe | Events are never replayed |
| `task:annotate(key, value)` | `task` | Scalar execution facts, e.g. output surface |
| `task:metadata()` | `table` | Copy of metadata |

`finish` is the form backends use: it reports what the process saw without deciding whether the task may still be completed, so a late callback cannot overwrite an earlier result and cancellation always wins.

`cancel` has one caller in the framework: the native terminal backend cancels when its surface goes away (tab closed, buffer wiped), because Neovim leaves the process running and the buffer hidden when a terminal tab closes. A cancelled run reports `cancelled` and its buffer is released.

Result kinds — the only four:

```lua
local results = {
  { kind = 'exit', code = 0 }, -- finished; code >= 0
  { kind = 'delegated', target = 'terminal' }, -- handed to a terminal; NOT success
  { kind = 'error', message = 'spawn failed' }, -- the CLI itself failed
  { kind = 'cancelled' }, -- user cancelled
}
```

Events: `{ kind = 'start' }`, `{ kind = 'output', stream, data }`, `{ kind = 'cancel' }`, `{ kind = 'result', result }`.

```lua
local Task = require('cli-cmd.task')
local task = Task.new({ command = 'git status' })
local stop = task:on(function(event)
  if event.kind == 'output' then
    io.write(event.stream, event.data)
  elseif event.kind == 'result' then
    print(vim.inspect(event.result))
  end
end)
task:start()
task:output('stdout', 'clean\n')
task:complete({ kind = 'exit', code = 0 })
stop()
```

Because listeners are not replayed, attach before `start()` — a listener added afterwards never sees the `start` event, and one added after `complete()` sees nothing at all. That is why `Dispatcher` offers `on_create`.

---

## Dispatcher

`require('cli-cmd.dispatcher').new({ router, task })` → `dispatcher:dispatch(ctx, { on_create })`

Creates a task, calls `on_create(task)` before starting it, then resolves and invokes the handler.

```lua
local Dispatcher = require('cli-cmd.dispatcher')
local dispatcher = Dispatcher.new({ router = router, task = require('cli-cmd.task') })
local task = dispatcher:dispatch(ctx, {
  on_create = function(created) presenter:attach(created) end,
})
```

---

## Command

`require('cli-cmd.command').new(opts)` → `command:dispatch(input)`, `command:register(name, opts)`

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `executable` | `string` | required | |
| `cwd` | `string` | required | |
| `backends` | `table<string, fun(ctx, task)>` | `{}` | Overrides the built-in `process`/`terminal` names |
| `routes` | `table<string, string\|function>` | `Command.standard_routes` | `capture` → `process`, `interactive` → `terminal` |
| `fallback` | `string\|function` | `'terminal'` | From `cli-cmd.tool`'s `defaults` |
| `terminal_capability` | `{ delegate = fun(ctx, task) }` | none | Replaces the native terminal backend |
| `terminal_layout` | `'tab'\|'split'\|'vsplit'` | `'tab'` | Native terminal placement |
| `env` | `table\|fun(): table?` | none | Function form is evaluated per dispatch |
| `complete` | `fun\|string` | none | Default completion for `register` |
| `presenter` | presenter table \| `false` | `presenter.output` | `false` disables presentation |

`dispatch(input)` takes `{ argv, cwd?, env?, route_key? }`; `cwd`/`env` fall back to the definition.

`register(name, opts)` creates a native user command with `nargs = '*'` and the `fargs` rule (spaces need a backslash; double quotes do not group).

| Register option | Type | Notes |
| --- | --- | --- |
| `route_key` | `string\|fun(fargs, cmdline_opts): string?` | Adapters pass their parser |
| `complete` | `fun\|string` | Overrides the definition default |
| `bang` | `boolean` | Registers `:Cmd!` |
| `force` | `boolean` | Passed to `nvim_create_user_command` |

```lua
local Command = require('cli-cmd.command')
local command = Command.new({
  executable = 'sh',
  cwd = vim.fn.getcwd(),
  routes = { capture = 'process' },
})
command:register('CliDemo', { complete = 'shellcmd' })
```

---

## Backends

### Process

`require('cli-cmd.backend.process').run(ctx, task)`

Runs `{ executable, unpack(argv) }` with `vim.system` in `ctx.cwd`, merging `ctx.env`. It has no tty: stdin is `/dev/null`, so anything interactive must not be routed here. Output streams into the task as `stdout`/`stderr`; the exit code becomes `{ kind = 'exit', code }`. Cancelling stops the job.

A process killed by a signal is never reported as success: it completes with `code = 128 + signal` (SIGINT → 130), matching how a shell reports the same command.

### Native terminal

`require('cli-cmd.backend.native_terminal').new({ layout? }):run(ctx, task)` — or `NativeTerminal.run(ctx, task)` for the default layout.

Starts a real terminal job (`jobstart` with `term = true`, the spelling Neovim 0.11+ prefers over `termopen`) in an unlisted scratch buffer and presents it:

| Layout | Placement |
| --- | --- |
| `'tab'` (default) | `tab sbuffer` — new tab, existing view untouched |
| `'split'` | `sbuffer` |
| `'vsplit'` | `vertical sbuffer` |

It owns the buffer and job, streams terminal output into the task, reports the real exit code, and annotates `surface = 'terminal'` so presenters stay quiet. A failed spawn or placement deletes the buffer, completes the task with `{ kind = 'error' }`, and rethrows. The tab stays open after the command exits so output remains readable.

### External terminal capability

`require('cli-cmd.backend.external_terminal').new(capability):run(ctx, task)` — protocol only:

```lua
local capability = {
  delegate = function(ctx, task)
    -- start the command somewhere else; return an optional handle
    return { cancel = function() end }
  end,
}
```

The task completes as `{ kind = 'delegated', target = 'terminal' }`; sending work to a persistent shell is never reported as `exit 0`. A capability that throws produces `{ kind = 'error' }` and the error is rethrown.

A capability that can see the real outcome says so and finishes the task itself:

```lua
local capability = {
  delegate = function(ctx, task)
    local session = start_somewhere(ctx, function(code)
      task:finish({ kind = 'exit', code = code })
    end)
    task:annotate('surface', 'terminal') -- the user can already see the result
    return { owns_result = true, cancel = function() stop(session) end }
  end,
}
```

`owns_result` must be a boolean. Without it the adapter closes the task as `delegated` immediately, because claiming knowledge it does not have would be worse than claiming nothing; with it the task stays `running` until the capability finishes it. Annotating the surface is what keeps the presenter from reporting a result that is on screen.

---

## Defaults

A value a caller can write is declared in one table per layer, and the code that
uses it reads that table. Nothing a caller can configure is decided by an `or`
buried in a code path.

| Table | Holds |
| --- | --- |
| `cli-cmd.tool`'s `defaults` | `cwd`, `fallback`, `terminal_layout` — what `install` fills in |
| `cli-cmd.presenter.output`'s `defaults` | every report option, per kind (see below) |
| `cli-cmd.command`'s `Command.defaults` | `routes`, `fallback` — what a Command ships |
| `cli-cmd.backend.native_terminal`'s `defaults` | `layout` |
| `cli-cmd.bridge.editor`'s `EditorBridge.defaults` | `cwd`, `server`, `layout` |

A value a caller *cannot* write is not here: Git's completion timeout, the
completion cache lifetime and Brew's provider budget are how those tools work,
not configuration. Moving them into a defaults table would claim otherwise.

`cli-cmd.router` deliberately has none. A Router is a resolver, so an absent
`fallback` is an error rather than a silent `'terminal'`; the tool layer decides
that default and passes it down.

## Presenter

Two separate decisions. `setup` configures the sinks; `install` picks one by name.

```lua
require('cli-cmd').setup({
  presenters = {
    split = { min_height = 3 },
    tab = { enter = false, number = true },
    log = { kind = 'split', max_height = 30 },
    page = function(message, level) end,
  },
})

require('cli-cmd').install('git', { presenter = 'log' })
require('cli-cmd').install('palette', { presenter = 'notify' })
require('cli-cmd').install('brew')                                    -- 'split'
```

An entry under `presenters` is a `cli-cmd.ReportConfig` or a function. A name that is built in — `split`, `tab`, `notify` — is its own kind, so `split = { min_height = 3 }` reads as "configure the split". Any other name has to say which kind it is, or be a function; that is how `log` becomes a split with its own height without inventing a fourth kind.

A tool's `presenter` option is a name, `false`, or absent. `false` turns reporting off; absent means `'split'`; anything else is a name that has to exist. A config passed here is an error — `setup` is the one place a presenter is built.

| Field | Meaning | Default |
| --- | --- | --- |
| `kind` | Where the report lands, below. | `'split'` |
| `level` | Fallback level for results that carry no level of their own, for every kind. | `nil` |
| `min_height` | `split` only: the shortest the window may be. | `1` |
| `max_height` | `split` only: the tallest the window may be. | a third of `vim.o.lines`, measured when the report is shown |
| `enter` | `tab` only: switch to the tab, or leave it in the background. | `true` |
| `number` | `split` and `tab`: line numbers in the report. | the editor's setting |
| `wrap` | `split` and `tab`: wrap long lines. | the editor's setting |

This table is not documentation of scattered code: it is `cli-cmd.presenter.output`'s `defaults` table, which the presenter reads for validation, defaults and window handling. Changing a default there changes the behaviour, and `tests/test_presenter_output.lua` fails if a declared default and an unconfigured presenter ever disagree.

The report's buffer is not configurable: it is always `buftype=nofile`, `bufhidden=wipe`, `modifiable=false`, because a report you can edit is a buffer pretending to be a file.

There is no length threshold: the report's size shapes the window, it never picks the sink.

| `kind` | Report lands in |
| --- | --- |
| `'split'` (default) | a read-only `nofile` buffer in a bottom split, as tall as the report, kept between `min_height` and `max_height`; `:q` closes it |
| `'notify'` | the message area, through `vim.notify` |
| `'tab'` | the same buffer in a tab of its own |
| `function(message, level)` | your rendering, with `level` a `vim.log.levels` value |

A field the chosen kind does not understand is an error, not ignored: `{ kind = 'notify', min_height = 3 }` and `{ kind = 'split', enter = false }` both fail to install rather than silently dropping the field. `number` and `wrap` belong to the report's own window, so they are set there instead of inherited from whatever window the report replaced.

| Result | Report |
| --- | --- |
| `exit 0` with output | the output |
| `exit ≠ 0` | `ERROR`, `stdout`/`stderr` merged in arrival order, `exit N` when silent |
| `error` | `ERROR` with `result.message` |
| `cancelled` | `WARN` |
| `delegated` | nothing |
| any result when `task:metadata().surface == 'terminal'` | nothing |

The report is read-only and wiped when its window closes, so `git log` stays scrollable, searchable, and yankable without a terminal. A tab is reserved for commands that take a keyboard, so the default sink never opens one; `<C-w>T` promotes a report to a tab when it is worth keeping. `kind = 'tab'` takes `enter`: with `enter = false` the report still gets its own tab but the cursor stays where it was, so a report you asked not to look at does not take the keyboard.

`min_height` (default 1) and `max_height` (default a third of the screen) bound the split: the window is as tall as the report, grown to `min_height` and capped at `max_height`. Both are row counts and must be positive integers, and `min_height` may not exceed `max_height` when both are given. The default `max_height` is measured against `vim.o.lines` each time a report is shown, so it follows the screen; a configured one is absolute. They are rejected by the other kinds rather than ignored.

`\r\n` and `\r` are normalised to `\n`. `vim.notify` is resolved when the report is emitted, not when the presenter is built, so an override installed later still takes over the `notify` sink.

The `level` option is only a fallback for results that carry no inherent level (`delegated`); it is not a threshold.

A function is how you take over rendering completely — the presenter does not care what you do with the text:

```lua
require('cli-cmd').setup({
  presenters = {
    page = function(message, level) require('my-notify').show(message, level) end,
  },
})
require('cli-cmd').install('git', { presenter = 'page' })
```

`cli-cmd.presenter.registry` owns the name → presenter map and validates each config; `cli-cmd.presenter.output` is the presenter it builds. Neither is something a config needs to require: `setup` calls the first and `install` calls the second.

---

## Editor Bridge

`require('cli-cmd.bridge.editor').new({ cwd?, layout?, open?, server? })`

Makes Git ask this Neovim instance to edit commit messages and sequences, without starting a nested Vim.

| Method | Result | Notes |
| --- | --- | --- |
| `bridge:env()` | `{ GIT_EDITOR, GIT_SEQUENCE_EDITOR, CLI_EDITOR_ID, CLI_EDITOR_SERVER }` | A quoted `nvim --clean --headless -n -i NONE -u <config>` command; the config loads `bridge/serve.lua` |
| `bridge:active()` | `boolean` | True while a session is waiting |
| `bridge:cancel(status?)` | `integer` | Cancels every session; returns how many |
| `bridge:dispose()` | — | Deletes the config and unregisters; call on teardown |

Options: `layout` is `'tab'` (default), `'split'`, or `'vsplit'`; `open(path)` overrides placement entirely; `server` defaults to `vim.v.servername` and is required.

The session ends when its window closes, its buffer is wiped, or `bridge:cancel()` runs — not on `:w`. Closing without saving releases Git as usual, so `git commit` aborts with an empty message rather than committing something unintended.

```lua
local tool = require('cli-cmd').install('git', { editor = { layout = 'tab' } })
local bridge = tool.editor -- the bridge this installation owns
bridge:dispose() -- or release every command it registered
require('cli-cmd.install').dispose('git')
```

---

## Completion

`require('cli-cmd.completion')` — provider plumbing:

| Function | Result | Notes |
| --- | --- | --- |
| `split(text)` | `tokens, current` | Native `fargs` rules |
| `callback(provider)` | `fun(arglead, cmdline, cursorpos): string[]` | Filters by the unfinished token, escapes spaces |

```lua
local Completion = require('cli-cmd.completion')
local complete = Completion.callback(function(query)
  return vim.tbl_filter(function(item)
    return item:find(query.arglead, 1, true) == 1
  end, { 'alpha', 'beta' })
end)
```

`require('cli-cmd.tools.git.completion').new(opts)` returns a provider; `.callback(opts)` returns a Neovim completion function.

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `cwd` | `string` | `vim.fn.getcwd()` | Base directory for refs, paths and discovery |
| `executable` | `string` | `'git'` | |
| `timeout` | `integer` | `1000` | Per Git call, in milliseconds |
| `cache_ttl` | `integer` | `2000` | Memo lifetime for candidate sources |
| `sources` | `table<string, fun(cwd): string[]>` | built-in | Replace `refs`, `remotes`, `authors` or `paths` |
| `discover` | table | real Git | Inject `{ subcommands, vocabulary }` for tests |

It is layered by what Git can answer versus what it cannot:

- `cli-cmd.tools.git.completion.discover` asks the installed Git: subcommands from `--list-cmds`, options and nested words from `<cmd> --git-completion-helper`. Options ending in `=` are how value-taking options are detected. Results are cached per `(git version, directory, subcommand)`.
- `cli-cmd.tools.git.completion.spec` holds only the gaps: value kinds (`--author=` authors, `--since=` dates, `--onto=` refs, `--file=` paths, `--strategy=` strategies), positional kinds (`checkout` refs, `add` paths, `push <remote> <refspec>`), the options `--git-completion-helper` omits (`--oneline`, `--graph`, `--since=`, …) and the static `strategies`/`dates` lists.
- `cli-cmd.tools.git.completion` orchestrates: pending value option, `--opt=value`, `--` paths, options, subcommands, positionals, nested words.

Behaviour:

```text
MyGit commit --<Tab>              -> every option Git reports for commit (no global options)
MyGit commit --author <Tab>       -> authors from git log
MyGit commit --author=<Tab>       -> --author=<author>
MyGit log --since=<Tab>           -> --since=yesterday, --since=2 weeks ago, ...
MyGit stash <Tab>                 -> apply clear drop pop branch list show ...
MyGit push <Tab>                  -> remotes      MyGit push origin <Tab> -> refs
MyGit -C /other add <Tab>         -> paths under /other
MyGit commit -m <Tab>             -> nothing (unknown option: no guessing)
```

Outside a repository `--git-completion-helper` refuses to run, so nothing is offered. That is accepted on purpose, and no fallback list is kept.

```lua
local GitCompletion = require('cli-cmd.tools.git.completion')
git:register('MyGit', {
  route_key = require('cli-cmd.tools.git.command').route_key,
  complete = GitCompletion.callback({ cwd = cwd }),
})
```

---

## The Git tool

`require('cli-cmd.tools.git')` returns the declaration; `require('cli-cmd.tools.git.command')` is the argv side of it.

| API | Result | Notes |
| --- | --- | --- |
| `route_key(argv)` | `'interactive'\|'capture'` | What the invocation needs from its surface; never mutates `argv` |
| `subcommand(argv)` | `string?` | First subcommand after supported global options; `nil` when absent; never mutates `argv` |
| `build(spec, parts)` | Command | `parts.cwd` is required; `parts.editor` adds the editor environment |
| `default_routes()` | `table` | Copy of the preset |
| `default_fallback` | `'terminal'` | Surface for route keys the preset does not name |

The preset names two surfaces, not subcommands:

| Key | Default backend | Meaning |
| --- | --- | --- |
| `interactive` | `terminal` | The child must talk to a human: it pages, prompts, or holds the keyboard |
| `capture` | `process` | The child runs unattended; the framework reports the result |

`route_key` answers with those keys by reading argv: `-p`, `--patch`, `-i`, `--interactive`, `--paginate`, `--help` anywhere before `--` ask for a conversation, and so do the subcommands that only work with a human (`mergetool`, `bisect`, `help`) and the ones that may ask for a password (`push`, `pull`, `fetch`, `clone`, `submodule`, `ls-remote`). Everything else is captured. The same subcommand can therefore switch surfaces: `add .` is captured, `add -p` is interactive.

Routes: `routes` merges over the preset, `replace_routes = true` ignores the preset. `editor` accepts an editor bridge and injects `bridge:env()` per dispatch, so one bridge can serve several commands.

Unknown values fail at construction: `routes` not a table, a target that is neither a non-empty backend name nor a function, or a non-boolean `replace_routes`.

```lua
local GitCommand = require('cli-cmd.tools.git.command')
local parts = { cwd = cwd, presenter = false }

local git = GitCommand.build({}, parts)                                  -- preset
local git2 = GitCommand.build({ routes = { interactive = 'process' } }, parts)  -- preset + override
local git3 = GitCommand.build({ routes = { capture = 'terminal' }, replace_routes = true }, parts)

-- Extend the preset explicitly instead of merging implicitly:
local routes = GitCommand.default_routes()
routes.capture = 'my-quiet-backend'
GitCommand.build({ routes = routes, replace_routes = true }, parts)
```

---

## Complete example

Registered command, Git preset, completion, editor bridge, and one notification per result:

```lua
require('cli-cmd').install('git', {
  command = 'MyGit',
  editor = { layout = 'tab' },
})
```

Custom backends and presenter, no Git involved:

```lua
local Command = require('cli-cmd.command')
local Output = require('cli-cmd.presenter.output')

local command = Command.new({
  executable = 'rg',
  cwd = vim.fn.getcwd(),
  backends = {
    quickfix = function(ctx, task)
      require('cli-cmd.backend.process').run(ctx, task)
      task:on(function(event)
        if event.kind == 'result' and event.result.kind == 'exit' then
          print('exit', event.result.code)
        end
      end)
    end,
  },
  presenter = 'split',
  routes = { search = 'quickfix' },
  fallback = 'quickfix',
})
command:register('Rg')
```

---

## Conventions

- Arguments are always argv arrays; no shell string is built. The single exception is the quoted editor command inside `GIT_EDITOR`, which Git itself parses as a shell command.
- Backends complete the task; they never present or decide policy.
- `delegated` is not success.
- A task completes exactly once; late output is dropped.
- User commands follow native `fargs` rules.
- A finished command's output lands in the presenter's `kind`; the default is a bottom split.
- A module's error prefix is the path it is required by: `lua/cli-cmd/backend/process.lua` says `cli-cmd.backend.process`, `.../init.lua` says nothing extra. `tests/test_guard.lua` fails the suite if a file disagrees, so an error string always leads back to the file that raised it.
- A tool lives in `lua/cli-cmd/tools/<name>/` and its tests in `tests/tools/<name>/`; `lua/cli-cmd/*.lua` never grows when a tool is added.

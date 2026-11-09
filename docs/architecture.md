# Neovim CLI integration framework — architecture context

## Objective
Build a configurable Neovim CLI command framework. Git is the first complete integration, with future registrations such as Pnpm and Brew. The user maintains custom Neovim Popup, Picker and Terminal Popup plugins and wants native Neovim editing rather than nested Vim inside terminal.

## Accepted decisions
1. Native user commands such as `:Git`, `:Pnpm`; command-line completion is independent of execution and should be compatible with native completion/Blink. Study mini.git completion, including branches/remotes and Git global options.
2. A command Context preserves executable, parsed argv, raw command input, cwd, optional env, and an adapter-derived route key. Do not assume args[1] is the Git subcommand (global flags can precede it). User commands use native Neovim `fargs` syntax, as mini.git does: escape spaces with backslashes (`my\ file.txt`); quotes do not group arguments. Context receives already parsed argv and does not parse or expand it again. Programmatic argv may contain spaces or empty arguments directly. Never interpolate untrusted args into a shell string without correct escaping.
3. Router is a pure resolver. Explicit routes select named or custom handlers; unmatched commands ALWAYS fall back to a configurable Terminal handler. Example: `:Git commit` -> process, `:Git cherry-pick abc123` -> Terminal fallback. Router does not know Git, process or terminal internals.
4. Dispatcher creates one Task per CLI invocation before invoking `handler(ctx, task)`. All handlers share a Task lifecycle, but need not share execution capabilities. Backend reports events to Task through a sink; optional Presenter subscribes without coupling to execution.
5. Task must distinguish successful execution (`exit` code 0) from successful delegation (`delegated` to Terminal). A reusable Terminal Session is NOT a Task. Do not report command success merely because it was sent to a shell. A terminal that lacks per-command exit tracking can finish the dispatch Task with a delegated result.
6. Process backend runs asynchronously (candidate: `vim.system`), streams stdout/stderr, captures exit codes, and supports cancellation. Neovim API calls from asynchronous callbacks must be scheduled safely. Process is not a TTY; interactive commands may need Terminal.
7. Terminal Adapter integrates the user's existing Terminal Popup; inspect its real public interface. Never assume a `terminal.execute` method exists. Preserve existing session/focus behavior; cancelling a delegated Task must not close a persistent Terminal Session. Safely handle argv, cwd and environment injection.
8. Editor Bridge is a shared optional execution capability, NOT owned by the Process backend or Git. Git adapter configures GIT_EDITOR / GIT_SEQUENCE_EDITOR; other CLIs can reuse the bridge. Accepted mechanism: study mini.git's headless Neovim + RPC technique, using the current Neovim instance to edit files. No required nvr dependency. Git owns hook/editor order; do not emulate hooks manually.
9. The editor bridge must block the requesting external editor process until the current Neovim edit session finishes, without blocking the main Neovim event loop. Define save vs completion vs cancellation semantics; `:w` alone must not complete the request. Handle failures, disconnections, concurrency and cleanup. Confirm exact mini.git implementation and Neovim API behavior from source/tests before copying assumptions.
10. Presentation is optional. Raw CLI output is not automatically structured LSP progress; stdout/stderr may include ANSI codes and carriage returns. Output display is separate from Task and Backend.

## Proposed relationships (not frozen file layout)
Command -> Context -> Router -> Handler -> Backend (Process or Terminal) -> Task events -> optional Presenter.
Editor Bridge can be injected into either execution path. Completion is independent of Router and execution.

## Example configuration intent (illustrative only)
```lua
require('cli').setup({
  commands = {
    Git = {
      executable = 'git',
      completion = require('cli.completion.git'),
      routes = { commit = 'process', fetch = 'process', pull = 'process' },
      fallback = 'terminal',
      -- Git-specific editor environment capability
    },
    Pnpm = { executable = 'pnpm', fallback = 'terminal' },
  },
})
```

## Task result intent (illustrative only)
```lua
-- { kind = 'exit', code = integer }
-- { kind = 'delegated', target = 'terminal' }
-- { kind = 'error', message = string }
-- { kind = 'cancelled' }
```

Task status transitions and cancellation semantics must be specified and tested. Cancellation request is not proof of process termination. Terminal delegation is a terminal outcome, not an assertion of CLI success.

## Implementation guidance
Prefer a coherent module dependency graph; do not split into generic helpers or one-function modules just for neatness. The previously discussed `command`, `context`, `router`, `task`, `backend/process`, `backend/terminal`, `bridge/editor`, `completion/git` names are conceptual, not a mandate. Verify whether native Neovim remote-wait or headless RPC semantics meet requirements; source of truth is real installed Neovim and mini.git code. The user explicitly rejects a disposable minimum-capability version; stage the final architecture's implementation, not an intentionally inadequate substitute.

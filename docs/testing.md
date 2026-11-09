# Testing and acceptance plan

## Approach
Use an automated Neovim Lua test harness (mini.test is a candidate, not a required dependency), temporary Git repositories and subprocesses. Separate fast unit tests, integration tests, and a small set of real UI acceptance checks. Tests must run in headless Neovim where possible. Proposed CLI test commands are placeholders until the repository test runner is implemented.

## Unit tests
- Context: native `fargs` escaped spaces and literal quote behavior, programmatic argv (including empty arguments), preservation of global Git options (`-C`, `--no-pager`) without interpreting them, cwd/env handling, snapshot isolation, invalid input. Git adapter tests own subcommand/global-option interpretation.
- Router: explicit match, custom handler, unmatched Terminal fallback, handler registration errors.
- Task: creation, start, waiting, completion, cancellation, duplicate terminal events, late output, callback ordering, listener cleanup.
- Process: stdout/stderr chunks, zero/nonzero exit, spawn failure, cancellation races, correct event-loop scheduling.
- Terminal: delegated outcome vs real exit, dispatch failure, persistent session reuse, cancellation not killing shared shell, safe command serialization.
- Completion: commands, flags, branches, remote refs, option argument contexts, global flags.

## Real integration tests
- Use a temporary Git repository and executable test hooks to assert actual Git order: pre-commit, prepare-commit-msg, editor, commit-msg (and failure paths). Do not assume all hooks run in every command mode; construct test inputs deliberately.
- Test `git commit` WITHOUT `-m` to force editor invocation, and verify the active Neovim instance receives the edit request.
- Saving (`:w`) must not release Git; successful close (`:wq`) must allow continuation; explicit cancellation must fail the editor request and prevent commit.
- Hook failure must return nonzero result and preserve diagnostics.
- Multiple bridge sessions must not overwrite each other's callbacks; handle child crash, RPC disconnect, Neovim shutdown and cleanup.
- Verify asynchronous responsiveness while hooks or editor are waiting; no blocking `vim.wait` on main instance.
- Verify Terminal fallback for e.g. cherry-pick, including when Git editor environment is required.

## Manual acceptance in the user's actual Neovim setup
- `:Git commit` uses a normal buffer in the existing Neovim, never nested Vim in Terminal.
- Blink command-line completion and Git context-aware completion work.
- Terminal Popup retains its focus, windows, session and reuse semantics.
- Git hooks (Husky, lint-staged, commitlint) run in Git's natural order and errors are visible through the optional presentation path.
- Main editor remains usable while Git runs and during editor bridge waits.

## Development stages
1. Inspect repository and Terminal plugin; define final module contracts and test harness.
2. Verify the highest-risk Editor Bridge mechanism against mini.git and real Neovim/Git behavior in a focused experiment. This is a technical validation, not a disposable architecture.
3. Implement Command/Context/Router/Task and their tests.
4. Implement Process/Terminal backends and tests.
5. Integrate Git adapter, editor bridge, completion and actual hooks.
6. Run complete automated suite and real UI acceptance; report failures and limitations explicitly.

## Done means
No untested claim of editor success, Git success, cancellation, or Terminal command completion. Automated suite passes; UI acceptance checklist is executed; architecture changes are reviewed with the user before adoption.

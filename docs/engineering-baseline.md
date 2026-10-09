# First-version engineering baseline

Compared with `/Users/qihao/forge`, Dotkit already has package-owned builds,
conservative linking, TypeScript/Lua tooling and a task runner. Missing pieces
were repository documentation, a root test entrypoint, root-file checks, CI and
acquisition of ignored external theme inputs.

## Added

- README, contributor/agent instructions and EditorConfig.
- Separate workspace `check` and `test` contracts, including root static checks.
- Palette `ensure`: fetch a missing collection at the pinned upstream commit,
  validate before publication, retain existing valid input, fail on invalid input.
- macOS CI: frozen dependency install, build, check and test; never slink.
- Standalone Task CLI test isolation from parent task transport variables.

## Local verification

- Root typecheck, lint and formatting passed.
- Workspace build passed (338 Palette themes).
- Missing-input download was tested in a temporary directory without replacing
  the real local collection.
- Palette input preparation tests passed (3 cases).
- Task tests passed (51 cases) after transport isolation.
- Shared, Profiles and Palette suites passed in the workspace test run.

## Verification follow-up

- Workspace `pnpm check` and all 220 tests now pass.
- A fresh temporary copy of tracked and nonignored source files passed frozen
  dependency installation, build (including input download), check and test.
  No existing node_modules, dist or local scheme YAML were copied.
- Pack tests now resolve runtime paths relative to the test file; Select tests
  exercise the current Picker implementation, and startup checks reflect the
  removal of the old Explore mapping.
- Lua checks discover Neovim's runtime when VIMRUNTIME is unset; remaining type
  issues, incomplete test fixtures and unused locals were corrected.
- Clean installation exposed tests assuming package-local tsx shims. They now
  use pnpm's workspace executable resolution instead.

## Remaining validation and limitations

- GitHub-hosted CI has not been executed. The temporary-copy verification is on
  the developer's machine, not proof of a fresh macOS runner. Native tools follow Homebrew,
  so clean-runner version compatibility must be verified.
- Standalone Heirline/Palette Lua integration tests still require locally
  installed third-party plugins; reproducible plugin provisioning remains open.
- Existing scheme input is schema-validated, not content-verified against the
  pinned revision. Strong provenance checking is a separate follow-up.
- Workspace slink is not an all-or-nothing installation transaction.

Commit hooks, commit-title enforcement and Forge's owner-only PR policy were not
copied. They are secondary to making build/check/test reliable on a clean clone.

# macOS environment acceptance

Status: live environment acceptance passed on the current macOS host.

The preparation and verification hooks ran twice successfully. The old plist
symlink was replaced with a managed regular file; the new helper is installed at
`~/.config/environment/xdg.sh`. `plutil -lint` and `sh -n` passed. LaunchAgent
reported one run with exit code 0 after the second load, and all four launchctl
XDG values matched the resolved configuration. Preview now reports preInstall
checked. No software installation or Palette build was performed.

Backup: `~/.local/state/dotkit/backups/environment-acceptance-20261018-160746/`.
It contains both on-disk Zsh histories, old plist/helper and a manifest of old
launchd values and the symlink destination. Original repository outputs remain.
Existing GUI applications and logout/login persistence have not been tested.
This stage tests only the environment hook, not Homebrew, Palette or software links.
The environment-only acceptance below preceded full software deployment. Full
installation/build/link execution subsequently passed on this host, with WezTerm
nightly preserved. The CLI is now enabled: `pnpm dotkit` executes after platform
selection; `pnpm dotkit --preview` is read-only. The recovery checklist below
records the original environment cutover, not a procedure to repeat on every run.

## Scope requiring confirmation

- Replace `~/Library/LaunchAgents/dev.qihao.xdg.plist`, currently a symlink to
  this repository's `profiles/dist/dev.qihao.xdg.plist`, with a managed regular file.
- Create `$XDG_CONFIG_HOME/environment/xdg.sh` (only if absent or already managed).
- Unload/reload `gui/<current uid>/dev.qihao.xdg`.
- Publish the four resolved XDG variables in the current GUI session.

Do not delete the old repository-generated plist/helper during acceptance. They
are the recovery source. Do not change Zsh, Neovim or WezTerm configuration links,
NVM installations, caches, state directories or history files.

## Before any changes

1. Ask the user to flush history in each active interactive Zsh session with
   `fc -AI`. Running this in a newly spawned shell cannot flush another shell's
   in-memory history.
2. Refresh backups of `$XDG_STATE_HOME/zsh/history` and `~/.zsh_history` into a
   private timestamped directory (directory 0700, files 0600).
3. Record the existing plist link target and back up the old plist and helper
   contents; record whether the service is loaded using `launchctl print`.
4. Record `launchctl getenv` for each XDG variable, including whether it was unset.
   Preserve exit status as well as output. Never include unrelated environment
   variables or history contents in logs.
5. Confirm current UID, GUI domain, resolved HOME/XDG, target parents and free
   backup access. Run read-only preparation checks. The old plist symlink is an
   expected blocker, not permission to overwrite arbitrary files.

## Controlled execution

Use the platform's `prepareXdgEnvironment` with the resolved context, not the
software executor. Record the exact invocation at execution time.

1. After refreshing backups, unlink only the confirmed old plist symlink. Leave
   its referent intact. If its type or destination changed, stop.
2. Invoke the macOS preparation hook. It writes the helper/plist, reloads the
   service, synchronously publishes XDG and verifies the values.
3. Invoke `verifyXdgEnvironment` and inspect the service and files.
4. Repeat preparation once to test repeat deployment.

A hook error is a failed acceptance, not proof that no changes happened. Stop and
inspect partial state before proceeding; do not run software installation.

## Success criteria

- The new plist parses and references the expected absolute helper path.
- Both files contain only the resolved intended paths and the management marker.
- `launchctl print gui/<uid>/dev.qihao.xdg` succeeds.
- Each `launchctl getenv XDG_*` matches its resolved value.
- Repeating preparation succeeds without modifying unrelated files.
- User checks a newly launched GUI terminal and a new Zsh session. Existing
  processes retain their old environment; opening a window from an existing app
  may not create a new process.
- Login persistence is a separate manual check at a convenient logout/login;
  RunAtLoad alone does not establish ordering before all other login applications.

## Recovery if acceptance fails

1. Record which new files and service changes completed.
2. Unload the newly loaded service if present; preserve errors for diagnosis.
3. Remove only verified new managed files. Restore any pre-existing managed helper
   from backup, or remove the helper if it was newly created.
4. Restore the original plist symlink and, if originally loaded, bootstrap the old
   service. Do not delete or rewrite the repository referent.
5. Restore the recorded launchd environment with `setenv`, or `unsetenv` for
   previously absent values, after accounting for the old service's asynchronous
   RunAtLoad action. Verify restored values; do not claim rollback if they differ.
6. Keep backups and report remaining discrepancies. Existing apps may need to be
   restarted; restoration does not retroactively change their environment.

No automatic global rollback or login-order guarantee is claimed.

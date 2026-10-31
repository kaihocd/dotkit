# Windows deployment: lessons and reimplementation

## What went wrong

The Windows work expanded from a thin installer into a second configuration system. It mixed
WinGet installation, shell environment publication, application path conventions, link
mechanisms, plugin bootstrapping, Palette packaging, and shared deployment lifecycle changes.
Several changes were made in shared Lua business code merely to anticipate Windows problems.
That is the wrong boundary.

Windows support must first deploy the configuration that already exists. It must not redesign
Neovim, the plugin manager, WezTerm, Palette, or the shared deployment model in advance.

## Junctions

A Windows junction is a directory reparse point: it makes one directory path refer to another
directory. It is not a copy and it is not a file symlink. Removing the junction removes only
the directory entry; it does not recursively remove the target directory.

A junction is useful only when Dotkit wants a Windows application to see a repository directory
at the application's configuration path without copying the configuration. It is not required
by Windows, by Neovim's Lua code, or by Dotkit in general. A Windows deployment may use a
junction for a directory if the application has no better supported configuration-entry
mechanism. A file entry, an application-supported loader, or a copy may be more appropriate.
The platform installer must choose this per target; shared business code must not learn about
Windows junctions.

## Rules for the next implementation

1. Keep the scope to one `pnpm dotkit` installation on a native Windows host.
2. Use the existing software declarations, authorization, preview, conflict checks, builds, and
   reporting. Do not add reset, uninstall, installation ownership, repair, or diagnostic systems.
3. Use Node and application APIs first: `node:path`, `node:fs`, PowerShell's `$PROFILE`, and
   documented WezTerm/Neovim configuration mechanisms. Do not write a general Windows path
   conversion layer or hand-parse paths in application business code.
4. Keep Windows-specific decisions at the Windows platform boundary. WinGet IDs and command
   arguments belong there. A required directory link may use Node's supported `junction` type
   there. Neovim plugin code, WezTerm shared helpers, and other dotfiles remain cross-platform.
5. Environment variables are allowed. Keep only the small set needed to make the existing
   configuration start consistently. Do not turn them into a new environment framework or
   duplicate their ownership in PowerShell, WezTerm, and deployment lifecycle code.
6. A Node CLI's Windows launcher is a package artifact. Palette builds `palette.js` and its
   Windows command shim; the Windows platform only consumes the artifact. Do not generate
   package launchers in a platform installer.
7. Do not install tools for an unverified downstream consumer. Dotkit does not become Mason's
   archive-extraction fallback or a general tool provider.
8. Do not modify shared Lua or application configuration pre-emptively. First make the minimal
   deployment work; add a compatibility change only when a concrete Windows runtime failure
   identifies the correct owner and the application API cannot solve it.
9. Keep public deployment changes to the smallest necessary interface. If installed commands
   need a refreshed child environment, isolate that mechanism and prove it is needed before
   expanding shared lifecycle state.
10. Test the actual Windows result: fresh PowerShell profile loading, WezTerm startup, Neovim's
    real config path, Palette invocation, and repeat deployment. A preview or package
    registration is not application acceptance.

## Reimplementation sequence

1. Restore all unrelated shared Lua, WezTerm helper, and deployment changes to their baseline.
2. Define the Windows software list and verify that every entry has a direct reason in the
   existing configuration or installation flow.
3. Add only the Windows platform declaration and the smallest required Windows configuration
   entries. Resolve actual application targets with their supported APIs; do not guess a
   universal `.config` layout.
4. Keep any required link-type selection inside the shared link primitive and Windows
   declaration only. Do not add Windows branches to plugin or configuration business code.
5. Make Palette's Windows command shim part of Palette's build output. The Windows platform
   links that output into its chosen bin directory.
6. Run static checks and focused declaration tests on the development host.
7. Transfer the complete snapshot to a fresh Windows machine, run preview, then perform one
   authorized deployment from a local interactive desktop PowerShell. Record failures instead
   of adding speculative fallback code.
8. Only after the fresh deployment works, simplify further or document a narrowly evidenced
   compatibility requirement.

The success criterion is not a large Windows framework. It is a fresh native Windows machine
that can run the existing configuration through the existing deployment entry with the fewest
platform-specific decisions possible.

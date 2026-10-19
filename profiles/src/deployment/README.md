# Deployment runtime

This directory is the platform-neutral runtime used by the platform declarations
under `profiles/platforms/`. The public entrypoint is `scripts/deploy.ts`; it
loads one platform configuration, resolves its environment, then chooses preview
or execution.

```text
scripts/deploy.ts
  ├─ platform-discovery.ts  scan/load profiles/platforms/*/install.ts
  ├─ environment.ts         resolve HOME, XDG and binDirectory
  ├─ platform.ts              platform configuration and installation context
  ├─ software.ts              software declarations and action contracts
  ├─ preview.ts               read-only callback + inspection flow
  └─ execute/
       ├─ index.ts            authorization + lifecycle orchestration
       ├─ software.ts         software list execution, install/build/links per entry
       ├─ authorization.ts    shared preflight/action authorization policy
       ├─ inspection.ts       preflight software/link diagnostics
       └─ types.ts            execution options and result types
```

## Module responsibilities

- `platform.ts` owns platform configuration, lifecycle callbacks and the resolved
  installation assembled for one platform.
- `software.ts` owns software entries, package probes, build actions, commands and
  their requirements. It keeps install/build/links together as one declaration.
- `environment.ts` validates explicit environment inputs and creates immutable,
  absolute HOME/XDG/bin paths. It does not mutate `process.env`.
- `platform-discovery.ts` finds platform entry files and imports only discovered
  paths. It does not know platform-specific behavior.
- `execute/inspection.ts` performs read-only preflight: package probes,
  source/target checks, duplicate/overlap detection and link diagnostics. It never installs,
  builds or links.
- `preview.ts` runs the read-only platform callback and inspection, returning a
  report without post-install or software actions.
- `execute/index.ts` owns lifecycle orchestration: authorization, preflight, the
  pre-install callback, failure propagation and post-install verification.
- `execute/authorization.ts` owns the shared authorization policy used both before
  hooks and immediately before software actions.
- `execute/software.ts` processes the software list serially, running each entry's
  install/build/links sequence and recording its step outcomes. `execute/types.ts` contains only the public
  execution options and result vocabulary.

Dependency direction is intentionally one-way:

```text
CLI → discovery/environment → preview or execute → inspection
                                      ↓
                              platform contracts
```

Platform modules may implement callbacks and declarations, but the runtime does
not contain macOS/Arch branches. Package-manager adapters are separate from this
runtime because they translate a native manager into the `SoftwareInstall`
contract; they are selected by platform declarations.

Regression tests live in `profiles/tests/`, outside production source:
`tests/deployment/` covers the runtime and `tests/platforms/macos/` covers the
macOS callback. They remain part of the package test command.

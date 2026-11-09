# Agent instructions

Before implementing, read `docs/architecture.md` and `docs/testing.md` in full. Treat their accepted decisions as constraints, and their illustrative APIs as proposals, not frozen signatures.

Inspect the existing repository and Terminal Popup public API before proposing changes. Do not invent methods. Prefer architecture-aligned modules over arbitrary file splitting. Do not implement a disposable MVP or change established decisions merely to simplify implementation.

Work in verifiable stages: inspect, validate critical Neovim APIs and mini.git behavior, implement with tests, run real Git integration tests, and report evidence and remaining risks. Ask before changing architecture. Keep the main Neovim instance responsive. Avoid unsafe shell concatenation and fabricated task success.

First response: report the current repository structure, existing integration points, proposed module dependencies, test harness, and a concrete validation plan. Do not immediately generate the entire implementation.

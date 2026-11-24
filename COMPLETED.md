# Warbound — completed work

## Performance

- 2026-11-24 — v0.97.71–v0.97.74: Verified the independent authority worker, default threaded mode, worker/parser fixes and synchronous-reference compatibility with Godot 4.7.2 parsing, the authority-worker regression and two-peer threaded ENet command/snapshot/teardown smoke. Registered the threaded smoke in manual validation. Three/eight-peer threaded stress and graphical performance remain tracked in TODO.md.
- 2026-11-24 — v0.97.70: Built the optional Windows x86_64 native extension with Godot 4.7.2 and godot-cpp `7fd5c4bc3efda6487fd6e6486c50016faa622f92`; moved project-generated object output under the ignored dependency checkout to prevent Godot OBJ import errors. Clean import and native targeting parity pass. Target-scale headless samples show no meaningful native speedup; backend remains opt-in.
- 2026-11-24 — Added a no-fixture two-peer threaded ENet smoke mode and manual validation entry. Verified guest commands reach the host worker, detached snapshots replicate threshold and speed changes, and worker state is cleared on lobby return; existing direct-mutation fixture tests remain synchronous.

# Warbound architecture and development guide

**Purpose:** Fast, reliable orientation for an AI agent or developer making a focused change. Read [AGENTS.md](AGENTS.md) for standing gameplay/CI rules and [TODO.md](TODO.md) for approved priorities. Historical version notes are not a license for new game mechanics.

## Responsibility boundaries

| Responsibility | Owner / entry point | Rules |
|---|---|---|
| Authoritative gameplay state and validation | `scripts/economy_rules.gd` (`create`, `step`, request validators) | Sole source of truth for ownership, costs, diplomacy, progression, simulation mutations and outcomes |
| Simulation scratch data | `scripts/step_frame.gd`, `scripts/combat_frame.gd` | Created for a substep/combat pass; never persisted as an independent state or replicated |
| Pure gameplay helpers | `scripts/combat_kernels.gd`, `scripts/repair_queries.gd`, `scripts/construction_queries.gd`, `scripts/system_geometry.gd`, `scripts/sector_geometry.gd` | No scene ownership, RPC dispatch or separate simulation authority; keep ordered tie-breaking intact |
| Lobby, host authority and RPCs | `scripts/game_session.gd` (autoload `GameSession`) | Retains request validation routing, peer checks, simulation timing, snapshot revision and recovery |
| Snapshot compression | `scripts/snapshot_codec.gd` | Pure map-ore and planet-template deltas and replica encode/decode; GameSession owns wire templates and fallbacks |
| Match input, UI and rendering orchestration | `scripts/match.gd` | Read-only previews via public EconomyRules queries; submit commands through GameSession, not local mutations |
| UI feature helpers | `scripts/match_*_ui.gd`, `scripts/command_card_ui.gd`, `scripts/construction_queue_view.gd` and view modules | Client presentation/state only, no new authoritative gameplay rules |
| Map generation/topology | `scripts/planet_map.gd` | Deterministic seeded layouts; preserve stable rock IDs and path/sector topology |

**Request flow:** Input in `match.gd` → `GameSession.request_*` → host validation/dispatch → `EconomyRules` authoritative mutation → reliable snapshots and unreliable movement updates → client presentation/interpolation. Solo uses the same authority simulation without ENet. New actions must reuse this path and must not add an independent client simulation.

## Simulation phase order

`EconomyRules.step(state, dt)` advances one authoritative simulation substep (currently `GameSession.SIM_STEP = 0.1`) in this order:

1. Reset rock planning budget; refresh current movement fields.
2. **Economy:** taxes/upkeep, simulation time, defection, blockades, local production and construction; initialize live hull lookup.
3. **AI:** diplomacy, routing permissions, economic/military decisions, mining budgets.
4. **Combat/repair preparation:** positions, regeneration, unit orders and withdrawals; resolve combat simultaneously, account for destruction/ownership changes, then salvage threats and resource handoffs.
5. **Formations/orders:** synchronize operations, plan formations/exploration, build service and repair indexes.
6. **Individual hull service and movement** in a duplicate of hull iteration order; then idle wandering, separation and contact correction.
7. **Final sync:** operations, exploration, conquest/objective updates; clear ephemeral indexes and route query caches.

Never rearrange these phases or reuse stale cached routes across ownership changes. Stable IDs, ordering, float precision and simultaneous damage attribution are gameplay contracts. `step_frame.gd` and `combat_frame.gd` document the scratch fields actually used by their stages.

## State ownership and lifecycle

The authoritative `state: Dictionary` is initialized by `EconomyRules.create`. Key families (non-exhaustive; consult source for the current schema):

| Root keys | Meaning / lifetime |
|---|---|
| `map` | Seeded points/fields/topology; ore depletion updates field chunks, so don't assume all map data is immutable |
| `planets` | Indexed systems: ownership, production, stocks, shipyard/infrastructure queues, population, upgrades |
| `ships` | Ordered live hull dictionaries with stable integer IDs, authoritative world positions/headings, cargo, orders, HP |
| `teams`, diplomacy and `military` | Relationships, legacy team groups and strategy metadata; changes may invalidate navigation/safety caches |
| `operations`, `next_operation_id` | Stable formation/operation assignments; maintain IDs and member order |
| `salvage`, `next_salvage_id`, `ship_destructions` | Authoritative pickups and destruction events; never create display-only copies as gameplay state |
| `galactic_credits`, `objectives`, `explored` | Empire economy, conquest and discovery owned by the simulation |
| `elapsed`, `next_id`, `next_ai`, `ai_waves` | Simulation time, identity allocation and host strategic scheduling |

`EconomyRules` also maintains **ephemeral static caches** for military/civilian routing, asteroid avoidance and indexed hull lookups. Cache validity is coupled to step phases, rock depletion, ownership changes and destruction. Treat cache invalidation as part of any refactor, not an incidental optimization. Do not persist per-step indexes in snapshots.

`GameSession` owns `economy`, `round_id`, `snapshot_revision`, reliable snapshot/template bookkeeping and visual `motion_samples`. The first reliable state conveys generated map/planet templates; later packets may send compact ore and planet changes, and decoding falls back to full states if incompatible. `snapshot_codec.gd` must preserve wire keys such as `_wire_ore`, `_wire_map_template`, `_wire_planets_compact` and `_wire_planet_template`. Movement packets remain **20 bytes per ship**, at most **57 records per batch**; GameSession owns RPC permissions, revision filters and finite-vector checks. Do not alter message schemas casually.

## Making changes safely

1. Identify the authoritative owner and approved gameplay requirement in AGENTS/TODO; keep speculative ideas in THOUGHTS until agreed.
2. Prefer changing a single domain module. Keep existing EconomyRules public signatures or add a facade; UI must never call underscored EconomyRules methods or mutate the authoritative state.
3. Preserve deterministic array/dictionary iteration, sorted tie-breaking, stable IDs, cost/resource reservation, queue limits, simulation order and cache lifetimes.
4. For a behavior-preserving refactor, compare identical seeded checkpoints from `tests/determinism_probe.gd` on both sides of the change. The CI replay guard checks *repeatability on one version*; it cannot alone prove parity with the previous version.
5. Update only relevant tests and documentation in the same versioned commit. Every commit bumps `project.godot`, with a matching `vMAJOR.MINOR.PATCH:` title. Keep unrelated balance and UI changes out of structural PRs.
6. Verify Godot parser/import, economic rules, solo startup, real ENet peers and targeted benchmarks. Report unrun tests explicitly. Existing CI is deliberately manual-only until the final pass is validated.

## Regression test policy

Automated validation protects **gameplay contracts, system invariants, authority and replication**, not UI geometry. Avoid asserting control names, hierarchy, disabled-state layout, labels, text content, pixel positions, sizes, styling, or interpolation internals in core/solo/ENet smoke tests. Test commands and resulting state via `GameSession` and `EconomyRules`; use visual playtesting or separate non-gating screenshots for appearance reviews. Preserve actual multiplayer connect/disconnect, objective, construction, resource and motion protocol coverage. Gameplay-relevant world-space positions (navigation arrival, collision avoidance, weapon ranges) remain valid simulation tests.

## Test entry points

After `godot --headless --path . --import`:

- `python3 tools/check_gdscript.py` — parses every tracked GDScript.
- `python3 tools/check_ui_rule_boundaries.py` — rejects private EconomyRules calls from match UI.
- `godot --headless --path . --script res://tests/construction_queries_test.gd` — base work/recipe costs, queue lookup and immutable input recipes.
- `godot --headless --path . --script res://tests/snapshot_codec_test.gd` — codec round trip, full-state fallback and malformed-input guards.
- `godot --headless --path . --script res://tests/economy_rules_test.gd` — economy, navigation, combat, construction and related invariants.
- `python3 tools/check_determinism.py` — independent-process seeded AI and battle state hash equality, **same version only**.
- `godot --headless --path . --script res://tests/solo_smoke.gd` — scene/startup authority.
- `.github/workflows/godot-validation.yml` — complete manual workflow: imports, parser, core and solo tests, 2/3-player ENet, disconnect scenarios, 8-player manual stress. The required aggregate `validate` job must pass before automatic triggers are restored.

## Performance measurement (informational, not a release gate)

Run `python3 tools/profile_simulation.py --godot godot --output performance-baseline.json` after importing the project, then compare identical fleet sizes, seeds, scenarios and tick counts on **the same machine** after any performance work. The driver uses `tests/fleet_benchmark.gd` unchanged: 500/1000-hull battle and logistics cases at 1× and 5×, a fixed seed, 100 simulation frames per case. Customize with `--ships 500,2500 --seeds 827,123 --scenarios battle,logistics --speeds 1,5 --ticks 100`. Outputs per-case frame p50/p95/p99, combat/repair and movement stage percentiles, CPU/engine and estimated simulated substeps per wall-clock second. This is a **headless CPU simulation benchmark**, not a graphical FPS measurement. Do not assert fixed millisecond budgets in CI or treat incomparable hardware results as regressions. Running it is optional and it does not affect the aggregate `validate` job.

## Stop conditions and deliberate non-goals

Finish the dedicated cleanup when (a) pure domain responsibilities and client/network boundaries are clear, (b) full manually dispatched validation is green, (c) hot-loop performance is measured, and (d) future features can be implemented without spelunking through unrelated systems. **Do not pursue a zero-line monolith, one-file-per-function, complete ECS rewrite, packed-state migration or UI rewrite merely for aesthetics.** The `match.gd` draw orchestrator and movement packet packing are acceptable to leave in their current controller if they remain stable and measurable.

Unresolved gameplay issues (e.g. asteroid anchor arrival and held freighter handoffs) are tracked separately; do not hide gameplay changes inside cleanup PRs.

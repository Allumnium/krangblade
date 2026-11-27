# Warbound — development TODO

## Approved art and audio overhaul (2026-11-27)

- [ ] v0.118.0 restores initial Small yards, adds base GC income, tightens asteroid clusters, softens selection/order indicators and boosts emissive contrast. Validate starting net GC, colony population conservation, actual visual balance and legacy fixtures; no runtime execution yet.

- [ ] v0.117.1 adds varying radius ceiling and synthetic fog observation/depletion regression (unrun). v0.117.0 removes ordinary asteroid collision and avoidance, retains Pulsar exclusions, reduces rock radius and slows real-time spin, hides unsurveyed minimap rocks and all non-live world rocks, and eliminates hidden-rock rendering. Run migrated direct travel, logistics, fog, wall, solo and real ENet regressions; compare realistic movement/render FPS and confirm relative asteroid/planet scale.

- [ ] v0.116.0 adds the 64-variant asteroid atlas, material maps, directional lighting and Crystal veins; v0.116.1 verifies PNG dimensions statically and adds tile coverage assertions. Run the existing fog regression; confirm atlas alignment, depletion scale, LOD, fog memory, shader/import metadata, and realistic rendered FPS. Physical geometry and economy unchanged.

- [ ] v0.115.0 integrates Science Vessel sprite and all supplied maps, bounded ambient/stellar/ship lighting and randomized repeating match playlist; confirm material map conventions, visually check directional lighting, cargo, portraits, fog/selection, audio transitions, import metadata and actual GPU performance at realistic fleet counts. Expand authored assets and lighting for planets, stations, other hulls and effects as supplied. Keep lighting client-only.
- [ ] v0.115.1 updates solo fleet counts and adds initial Science Vessel, stock, credit and objective assertions; run these and real peer parity. Verify initial economy pacing, and migrate other legacy starting-fleet assumptions as required. Batched ship lamps, nearest-light cap, planet shading, actual sprite portrait and foreground Antimatter cargo also need visual/runtime acceptance.

## Approved economic pacing and explicit production (2026-11-27)

- [x] v0.114.0 removes free production and infrastructure from home and newly founded stations, including starter yards/PDS and base Crystal income. Maintain starting fleet, stocks and integral station defenses. Explicit production buildings, dedicated orbital Eco-Housing and built Colony Ships generate materials; stockpiled food supports residents before farms complete. AI bootstraps Farms, Refineries, then Shipyards; focused and solo tests pass.
- [ ] Tune normal unfunded empires to opening 0–2 min, first colony and 7–10 military hulls 2–4, specialization 4–8, major conflict 8–15, endgame 15–30 at 1×. Rush viable, station defenses deter elimination; developed colony supports 20–30 fighters or equivalent plus civilian fleet. Expansion higher potential, concentrated investment viable with diminishing returns; mining leads early, industry grows later; Crystals constrain advanced technology; deposits exhaust without excessive micro, starting potential comparable. Credits chiefly constrain upkeep; consider tax and explicit fee rebalance. Verify actual peer openings and migrate old fixture assumptions; no new currencies/fleet caps.

## Approved gameplay rebalance — simpler numbers (2026-11-26)

Merged v0.113.0 implements the initial new scale across the simulation, recipes, presentation and objectives. Do not close these acceptance items until the full migrated regression suite, current-main physical-construction tests and actual peer tests pass. Playtesting and economic balance refinement remain expected. Focused contract and solo checks pass; funded AI pacing passes all three seeds.

- [ ] Replace bulk tonnage with unlabeled resource units: nominal 10 old tons per unit; starting Metals 165, Organics 30, base Metal storage 400. Preserve fractional simulation quantities, show whole inventories and useful fractional rates. Standard base costs 25 increments, smaller exceptions 5. Round modified costs as appropriate; no zeroing positive requirements unintentionally.
- [ ] Population in Pop (100 old people per Pop): home terrestrial 100, orbital 50, total 150, colony crew 250, origin 500. Rescale staffing, production, growth, housing, tax, objectives and AI. GC initial 500; rescale fees, upkeep and affordability consistently.
- [ ] Ship Metals: Scout 10, Fighter 25, Freighter 50, Construction Ship 40, Harvester 50, Science Vessel 100, Colony 150, Cruiser 200, Railgun Ship 200, Destroyer 300. Remove ordinary ship Organics costs; Colony retains 10. Provisional Pop crews and Crystal recipes as agreed in discussion; rebalance shipyard and upgrade costs, yields, extraction and freight throughput. Freighter 100 units (10 each of ten bays), Constructor 20, Harvester 5, Colony 25; depot Metals 200, Organics 400, Crystals 50.
- [x] Antimatter indivisible, eligible holder max 1, Resource Depot 0, science collection and warp deployment retain single items (v0.112.0; broader peer coverage pending).
- [ ] Rescale hull HP, shield/armor and weapon/repair damage; tune time-to-kill and display. Rebalance objectives, rewards, AI and construction costs in coordination, update Codex and all relevant semantic fixtures. Do not alter map geometry or simulation time by numeric rescale. Real peer and hardware playtesting remain separate acceptance.

## Approved gameplay development — construction, siege and support (2026-11-26)

- [ ] **Siege:** v0.98.0 implements one Destroyer railgun; v0.99.0 adds cheaper specialized Railgun Ship with only one railgun, stand-off navigation, recipe/crew/HP/upkeep/art/AI and command card integration. Verify exact damage, range, cooldown, focus, neutral/ally/cloak filtering, formation and standoff behavior, visuals and actual peer replication. Railgun is single-target with no splash or wall penetration. Keep other Destroyer weapons. Numeric values derive from base missiles (2× range, 4× damage, 1.25× cooldown).
- [ ] **Science Vessel support:** v0.101.0 implements repair friendly/allied ships and structures (autocast and manual, no self-repair); v0.102.0 implements free targeted scan launching physical uncommandable cloaked probe with ship-like sight, 30-year lifetime after arrival, 30-year ability cooldown. v0.101.0 implements Science Vessel and Space Station passive cloak detection in normal sight radius. Verify targetability, expiry, fog/replication, ownership and ability validation.
- [ ] **Construction Ship and supply:** v0.103.0 adds Small constructor, single-source reservation, auto physical delivery and cancellation/salvage. v0.107.0 adds automatic freighter supply; v0.109.0 adds atomic multi-source site escrow. v0.110.0 adds lost-cargo replacement from actual station stock; v0.111.2 validates physical multi-station construction, per-resource conservation and fixes the reach-boundary stall; v0.111.3 passes physical freighter-to-constructor supply and conservation; broader construction-specific peer checks remain. Physically carry required resources to static construction sites anywhere on the map subject to physical placement, including outside territory. Reserve required resources at site admission; delivered material drives build progress. Multiple construction ships service friendly projects automatically; freighters can physically resupply them, but only construction ships deliver to the construction queue. Cancel refunds undelivered reservations and drops delivered materials as salvage. Incomplete sites destructible, health grows with progress. New static structures have no population cost or territory influence; preserve existing structure requirements.
- [ ] **Resource Depot:** v0.103.0 adds construction and explicit load/unload with independent caps. v0.107.0 adds automatic routes using station thresholds; v0.111.0 adds independent receiving ceiling, dispatch floor and enable switches; v0.111.3 passes physical depot routing, interruption, ownership/worker parity and 2/3-peer policy replication; hardware/UI acceptance remains. Standalone storage, independent resource caps inversely scaled by fixed reference economic value (not live price; no Antimatter storage), no population, production, shipbuilding or influence. Freighters collect and deliver; revisit depot command card and import/export controls with user as needed.
- [ ] **Walls and diplomacy:** v0.105.0 implements physical wall placement, chain reservations, nodes/segments, cascade removal and visual preview. v0.106.0 integrates indexed interception for movement and weapon fire; v0.108.0 adds bounded automatic detours and v0.111.1 handles additional disconnected blocking components; v0.111.2 passes actual detour movement and neutral/hostile interception fixtures; v0.111.3 records isolated 100/400-hull detour routing and a software-rendered Cruiser interception; complex mixed layouts and hardware performance remain. Wall nodes connected by straight independently destructible high-HP segments, auto-place maximum-length segments on drag plus shorter end, attach to existing nodes, allow corners/junctions; destroying a node destroys attached segments. Completed walls obstruct non-permitted movement and non-allied weapons fire, take intercepted hostile damage; incomplete walls do not obstruct. Use indexed swept segment checks for all ship paths and weapons, including missiles/railgun; avoid all-wall scans. Neutral empires cannot attack walls without declaring war; no automatic war. v0.100.0 adds directional Open Borders permission and Empire toggle; walls must consume it for movement (not weapon passage or hostility); allies pass by default, neutral closed by default. v0.107.1 renders authoritative intercepted laser endpoints; v0.111.3 visually checks Cruiser interception in a frozen software-rendered match; broader weapon and peer checks remain. Reconcile permissions on relationship changes. No walls or other new static structures contribute territory.
- [ ] **Defense Cannon:** v0.104.0 implements physical construction, three-level cannon and upgrade delivery; verify runtime, targetability, cancellation and peer replication. Static upgradeable weapon platform, provisional three levels increasing damage/range/HP; construction ships physically deliver upgrade materials. No population or influence.
- [ ] **Interface and acceptance:** consult user before any command-card rearrangement/submenu if slots insufficient. Existing fully upgraded shipyard has 3 free production slots (one Small, two Large); inspect capacity per actual tier and ability cards. Each feature uses existing authority validation, deterministic state and physical logistics, AI integration within approved design, updated Codex, focused gameplay and 2/3-peer real ENet regressions plus normal import/parse/economy/solo checks. Provisional costs, wall length, depot value budget, cargo capacity, repair rates and health to balance in play. No speculative optimization rewrite.

## Optimization — implementation closeout and remaining validation (v0.97.102)

This is the finite optimization closeout roadmap. Implementation is closed; validation and measured regression fixes remain. The earlier eight-phase program, P0–P4 priorities, versioned slices and old profile observations are preserved in [THOUGHTS_ARCHIVE.md](THOUGHTS_ARCHIVE.md#optimization-roadmap-history-through-v09791). Do not reimplement an archived slice merely because its old checkbox was open. Implementation, focused validation, integrated validation and performance acceptance are separate statuses. [COMPLETED.md](COMPLETED.md#performance) records delivered work; [PERFORMANCE.md](PERFORMANCE.md) records benchmark conditions and results; [ARCHITECTURE.md](ARCHITECTURE.md) documents ownership and existing reference paths.

### A. Implemented with recorded validation (not whole-program acceptance)

| Delivered slice | Recorded evidence | Remaining boundary |
| --- | --- | --- |
| Reproducible fleet profiling, slowest-batch diagnostics and live render harness (v0.64.1, v0.97.38, v0.97.79–83) | Seeded headless and graphical captures recorded in PERFORMANCE.md | Higher counts, representative mixed fleets, constrained real peer measurements and manual CI artifact run |
| Single-writer threaded authority, default enabled (v0.97.71–78) | Godot parsing, worker parity, solo and 2/3/8-peer smoke at earlier revisions; 2/3-peer checks repeated in v0.97.87–89 | Full latest-main suite, teardown issues, native coexistence and publication cost |
| Optional native targeting (v0.97.70/77) | Windows build and ordered laser/missile parity; no meaningful measured speedup | Native batch migration, Linux/build distribution, thread safety and throughput |
| Census and mining candidate improvements (v0.97.69, v0.97.82) | Economy and focused candidate/census parity | Logistics startup and sustained 1x/5x deadlines still fail |
| Pose/minimap/texture batching, span vision and hot kind/HP tables (v0.97.84–86) | Economy regressions and isolated/live render captures on documented reference machine | Combined live acceptance, persistent GPU buffers and publication work |
| Packed contact, soft separation and steering; demand-driven service/threat/exploration work (v0.97.87–89) | Focused exact parity, economy, battle replay and worker/solo/ENet checks as recorded; swarm median 649.367 → 470.074 ms on Linux | Dispersed speedup inconclusive, teardown warnings; derived buffers are not authoritative packed storage |
| Grouped sensor spans/cache and exact Voronoi query bins (v0.97.90–91) | Isolated patch tests on supplied v0.97.86 checkout; dense vision 22.194 → 6.940 ms, territory influence 44.022 → 9.723 ms | Current-main integrated regression, ENet, graphical and throughput validation |
| 120 FPS cap / VSync disabled (v0.97.75) | Project settings verified | Actual display frame pacing not established |
| Private authority live hull index and ordered subset lookup (v0.97.93) | Isolated focused lifecycle, economy, replay, worker and 2-peer threaded checks; eight-ID selection 200.40→12.66 µs | OPT-2 canonical packed hot fields and shared indexes; current-main validation and full-engine profiling |
| Peaceful combat phase work elimination (v0.97.94) | Isolated exact state/threat parity, economy, worker, solo, 2-peer threaded ENet and battle/AI replay; 2,000 swarm combat 83.817→50.259 ms; 1,000 mixed peaceful 5x combat 294.073→197.310 ms | OPT-3 broader per-fleet activity/wake scheduling; active battle/tail profiling, integrated acceptance |
| Shared empty-rock halos and accepted sweep reuse (v0.97.95) | Isolated exact crowded navigation, economy, battle replay, worker, solo and 2-peer threaded checks; repeat 2k swarm total 470.303→431.067 ms | OPT-3 movement/formation work; dispersed 5x not improved, integrated performance acceptance remains open |
| Shared operation and lane formation batches (v0.97.96) | Isolated exact formation/lifecycle and replay parity, economy, worker, solo and 2-peer threaded ENet; 2k moving formation median 312.234→300.765 ms | OPT-3 remaining dense interactions; OPT-2 canonical typed storage still open; current-main and scale acceptance |
| Native contact accumulation and Linux build (v0.97.97) | Current-checkout import, exact contact/targeting and 50/100-tick replay, native worker, solo and 2-peer threaded ENet; 2k swarm median 415.342→384.633 ms | Native full economy timed out near end; Windows/distribution, separation/steering/targeting batches, dispersed tail and scale acceptance remain open |

| Native soft separation (v0.97.98) | Linux build/import, exact force and movement settlement parity, full native economy, 50/100-tick battle replay, worker, solo, two-/three-peer threaded ENet, loading-disconnect and host-leave; 2k swarm total p50 382.841→337.891 ms | Native remains opt-in; steering/targeting, Windows, dispersed tails and scale acceptance open |

### B. Implemented foundations with incomplete acceptance evidence

These are not independent reimplementation tasks. Validate surviving paths, retire superseded experiments only after parity, and use the bounded validation gates below; broader work is deferred. Where historical notes say runtime pending, that statement is historical, not proof that a later integrated test passed or failed.

| Existing TODO slices | Status / validation remaining |
| --- | --- |
| v0.64.4–9, 19–27, 35–38; P1a–i; v0.97.47–50, 61, 63 | Shared sector/hostility/repair/logistics/target/route indexes and fleet candidate reuse implemented in slices; consolidate phase-safe lifecycle, verify casualty/ownership changes, dense opposing fleets, repair and logistics. |
| P2a–f and P3a–f (v0.64.47–58) | Step-local stable-ID refs, operation sets and frozen packed combat fields; persistent canonical store and incremental membership not finished. |
| v0.64.28–31, 34; v0.97.51–55, 67–68 | Retry/weapon/AI scheduling, motion sleep, inactive scans, calendars, economic coefficients and failed trade search rates; exact deadline/wake and rate validation remains. |
| v0.97.56–59 | Predictive direct corridors and cardinal/arbitrary-heading samples plus explicit-order fast path; limited dense-fleet applicability, no general trajectory replacement; benchmark realistic eligibility and wake behavior. |
| v0.64.32–33; v0.97.60, 62, 64 | Ordered spatial buckets and fused movement preparation, later evolved into packed contact/separation/steering; validate current production paths rather than restoring obsolete intermediate representations. |
| v0.64.10–14, 16–17; v0.97.65–66 | MultiMesh hull/effect/overlay batches, asteroid meshes, projection, retained fog and minimap work; zoom, selection, fog, close-up art, GL Compatibility and frame percentiles remain acceptance work. |
| v0.64.15, 18 | Static territory shader candidates and cached stationary hull regions; moving regions now indexed, incremental totals and geometry acceptance remain. |
| v0.97.38, 45 | Profiling script and non-gating manual workflow job implemented; record current-main comparable results and verify the manual artifact job. |

### C. Implementation closeout — v0.97.102

The bounded optimization implementation phase is closed; return to gameplay development while completing validation. Do not start another optimization rewrite without a measured gameplay bottleneck.

- [x] **OPT-5 bounded pass:** Reuse exact unchanged immutable map snapshots; keep mutable records detached, preserve urgent publications and wire schema.
- [x] **OPT-6 bounded pass:** Reuse exact unchanged client territory spillover inputs; retain all authoritative and presentation semantics. No standalone territory performance claim.
- [x] **OPT-1 build preparation:** Add manual pinned Windows/Linux native build, parity, threaded smoke and artifact workflow. Preparation is not proof of Windows execution.
- [ ] **OPT-1 acceptance:** Run [native validation](https://github.com/Allumnium/krangblade/actions/workflows/native-validation.yml), check Windows artifacts and compare hardware performance. Keep native opt-in with GDScript fallback until validated beneficial; default activation is conditional, not assumed.
- [ ] Complete OPT-V1/V2 below. Fix demonstrated regressions rather than expand the implementation scope.

Deferred, not completed: canonical packed authority (OPT-2), broader predictive/activity scheduling (OPT-3/4), further native navigation/target batches, replication/pose-delta redesign (OPT-5), persistent GPU rewrite and deeper incremental territory changes (OPT-6), multicore restructuring (OPT-7). Preserve existing optimizations. Full original package descriptions are in [THOUGHTS_ARCHIVE.md](THOUGHTS_ARCHIVE.md#optimization-implementation-roadmap-before-closeout-v097101).

### D. Validation and scale acceptance — separate from implementation

- [ ] **OPT-V1 — Current-main integrated correctness and cleanup gate.** v0.97.102 Linux Godot 4.7.2 local integrated pass: native-enabled full economy, import, lobby, construction, fog, speed, snapshot codec, worker, solo, exact native/reference 50/100-tick battle replay, 2/4/8-peer threaded ENet. Host and all clients exited 0; ObjectDB exit warnings and 4/8-peer post-round packet-send errors remain. Run the remaining normal ENet, disconnect/teardown and full manual CI checks; independent AI replay not rerun in this pass. Run resource import, parser, full economy and domain regression, independent-process seeded AI/battle and old/new command checkpoints, worker/solo, pause/1x/5x, real 2/3/8-peer normal and threaded ENet, loading-disconnect, host-leave and repeated round teardown. Verify exact state when representable; document any allowed numeric motion tolerance and prove interaction/arrival equivalence. Resolve ObjectDB/ENet teardown warnings, investigate regressions rather than weakening assertions, verify manual profiling artifacts. Restore automatic CI only at the user's direction. Record exact version/hash, test scope and results.
- [ ] **OPT-V2 — Comparable profiling and realistic multiplayer acceptance (P0 / phase 1 and all phases).** Primary 1x targets on an agreed reference PC: ordinary 1v1 50–100 total ships, aim for 120 FPS; large 1v1 100–200, developed four-player 200–400 and developed eight-player 400–800, stable 60+ FPS on host and guests (p95 frame ≤16.7 ms), responsive commands, sustained 10 completed simulation batches/s without noticeable calendar slowdown. Ship counts are benchmark envelopes, not caps. 2,000–5,000+ hull tests are diagnostic/stress headroom, not release requirements; report 5x separately. Prioritize seeded live 100/200/400/800 and representative mixed-fleet, dense combat, logistics, AI and diplomacy across solo/host/guest. Record hardware/build/seed/renderer/zoom/resolution/duration, frame/batch percentiles and misses, elapsed calendar, publication, encode/decode, bandwidth, state age and command responsiveness. Do not claim hardware FPS from headless or software-rendered runs. Earlier 2k/5k acceptance thresholds are superseded by the user's November 26 clarification; retain historical results in PERFORMANCE.md. User reports >30 FPS with infrequent lag in 1v1 50-v-50 play, not yet stable 60. Current 100/400/800 synthetic benchmarks and publication diagnostics in PERFORMANCE.md.

**Current known baseline:** v0.97.99 native Linux 100/400/800 1x swarm median 19.346/63.001/124.175 ms; 0/2/40 of 40 batches exceed 100 ms. Real hardware live acceptance, Windows native validation/default activation and broader multiplayer validation remain open.

- [ ] v0.97.44: Complete durable real-ENet resource handoff verification by consuming the observed authoritative transfer flag in each empire's command-check dictionary; remove the redundant simultaneous miner-empty/Freighter-full snapshot gate, which could still fail after a valid haul. Preserve event, cumulative cargo statistics, all peer and construction requirements. Test-only; runtime 3-/8-peer validation pending.

- [ ] v0.97.43: Make real-ENet miner-to-Freighter handoff validation observe authoritative source/target cargo transfer events or persistent dropped/picked statistics rather than relying on simultaneous transient cargo snapshots. Add economy regression assertions for transfer records and cumulative cargo accounting. Keep every command, throughput and peer-validation requirement intact. No gameplay/network schema changes; rerun pending.

- [x] v0.97.42: Archive 64 historical v0.94–v0.97.30 change entries from the top of AGENTS.md into THOUGHTS_ARCHIVE.md without changing their wording or removing the standing workflow/UI/design instructions. Keep recent notes and a direct archive link for AI agents. Documentation-only; game and CI untouched.

- [ ] v0.97.41: Prevent a local variable shadow in the ENet smoke harness by naming the per-scenario timeout separately from the lobby discovery deadline. No gameplay or test assertion changes. Godot parser and multiplayer validation pending.

- [ ] v0.97.40: Repair multi-peer ENet stress fixtures from run #395: initialize staged/dock freighters at actual 400-HP max instead of half health (which could trigger repair/retreat and abort resource handoffs), retain every construction and handoff assertion, increase wall-clock budgets for 3-/8-process jobs on shared CI runners, and print per-hull handoff state on timeout. No gameplay changes. Godot/runtime and rerun of multi-peer CI pending.

- [ ] Re-run full manual GitHub Actions validation after v0.97.40 fixture correction; run #395 stalled at `miner_resource_handoff` for one of three empires, while 8-player test only reached ~40 simulation years before the 65-second timeout and remained short of sequential construction checks. This is **not** yet confirmed fixed until a successful 3-/8-player run: https://github.com/Allumnium/krangblade/actions/runs/45320109745

- [x] v0.97.39: Clarify connected GitHub repository access and GitHub Actions read/log capabilities in AGENTS.md, record run #395's actual failing 3-/8-player ENet results, and note the project-only memory continuity model. Documentation only; no game code or test changes.


- [ ] v0.97.37: Make smoke tests independent of UI widgets: replace solo menu row/button checks with public GameSession roster/seed/starting-fleet validation; replace network trade-slider, rendered ship-pose, and private lobby-view checks with authoritative inventory/trading, finite motion/revision and lobby-state invariants. Remove exact objective-description text assertion. Preserve construction, colony, chat, diplomacy, replication, and network scenarios. Godot/runtime and real ENet not executed in this environment.

- [ ] v0.97.36: Extract base construction recipes, nominal work estimates and pending-job lookup into stateless construction_queries.gd behind EconomyRules wrappers, passing canonical multipliers/cost tables explicitly. All discounts, crew/GC reservation, queue validation and mutation remain authoritative in EconomyRules. Add isolated recipe assertions to manual CI and architecture index. Runtime/determinism and ENet pending.

## Final high-value cleanup pass (approved 2026-11-22)

**Stopping rule:** Resume gameplay development once the targeted boundaries below are verified, not when every file or helper is small. Refactors must be deterministic and behavior-preserving; use separate PRs for gameplay fixes. [ARCHITECTURE.md](ARCHITECTURE.md) is the onboarding map.

- [x] Restore the seeded economy/solo/two-peer baseline (v0.97.26–v0.97.30; recorded passing).
- [x] Add independent-process determinism replay and static UI API checks (v0.97.31, v0.97.34; committed but CI execution pending).
- [x] Extract pure repair queries and snapshot encoding without changing their callers' public contracts (v0.97.32–v0.97.33; runtime tests pending).
- [x] Replace the 59 match UI calls to underscored economy helpers with public queries (v0.97.34; parser/runtime pending).
- [x] Document current simulation, session and presentation ownership, critical state, cache lifetimes and test commands (v0.97.35).
- [ ] **Validation gate:** Run manual Godot validation and resolve failures in new modules and tests; confirm solo, 2-peer, 3-peer, loading-disconnect, host-leave and 8-peer stress. Restore automatic PR/main CI triggers after a successful full pass.
- [x] **Selective simulation extraction:** Move canonical construction recipes and nominal work into a pure domain module (v0.97.36). Existing authority-side wrappers preserve the public contract; runtime validation remains part of the validation gate.
**Performance gate:** Tracked under [OPT-V2 above](#d-validation-and-scale-acceptance--separate-from-implementation); the original gate is preserved in the optimization archive.
- [ ] **Handoff:** Reassess necessity of splitting the 369-line match draw orchestrator and 20-byte motion packing **only if they obstruct a planned feature or fail profiling**. Do not rewrite stable UI/network code for size alone.

**Deferred:** Whole-entity rewrite, speculative packed-array migration, cosmetic file-size targets and unmeasured combat optimization. Independent gameplay bugs (blocked asteroid anchors, held freighter handoffs) remain separate gameplay work.

- [ ] v0.97.35: Add a concise architecture and state-ownership guide, a bounded cleanup checklist with acceptance gates and explicit deferred work, and an AGENTS navigation link. Preserve historical standing instructions; only the documentation/version changed.

- [ ] v0.97.34: Replace all 59 direct match.gd calls to 16 underscore-prefixed EconomyRules helpers with named public query wrappers. Internal simulation helpers, argument signatures, validation and behavior remain unchanged. Add a static CI guard preventing new underscore-prefixed EconomyRules calls from match.gd. Gameplay/parser and multiplayer tests pending.

- [ ] v0.97.33: Extract the session's stateless map-ore delta, planet-template compaction, full-fallback and replica encode/restore algorithms into snapshot_codec.gd. GameSession retains public/private wrappers, all RPC signatures, peer validation, revision/timing, snapshot template lifetime and recovery policy. Add isolated codec round-trip and malformed-input regressions to manual CI. Wire schema and simulation unchanged; Godot/ENet validation pending.

- [ ] v0.97.32: Extract stateless repair-damage checks, ordered repair target spatial buckets and cooldown readiness into repair_queries.gd, retaining EconomyRules wrappers, simulation call order, target iteration order, epsilon and all gameplay/network interfaces. No state or cache is owned by the module. Runtime, deterministic replay and ENet validation pending.

- [ ] v0.97.31: Add a deterministic replay guard to manual Godot validation: independent-process seeded AI and 400-hull battle runs must produce matching parsed state-hash checkpoints, failing on missing output, Godot errors, mismatches or timeouts. Keep CI triggers manual-only until the agreed final cleanup gate. Runtime/ENet not executed locally; pending workflow run.

- [ ] v0.97.30: Behavior-preserving splits of command_miners, _valid_unit_order, territory_claims, _ai_station_goal and _work_resource_stage into focused helpers. Parser clean, determinism identical, economy suite 0 failures, solo and ENet two-peer smoke pass.

- [ ] v0.97.29: Behavior-preserving splits of _build_combat_frame, _fire_hull_lasers, _resolve_ship_contacts, create and _finish into focused helpers. Determinism probe identical; economy suite 0 failures; parser clean. Runtime/ENet not rerun.

- [ ] v0.97.28: Behavior-preserving splits in economy_rules.gd: pirate decisions (group gathering, retreat, patrol, assignment), AI diplomacy choice (peace scoring, third-party pressure), local rock route planning (grid, start, goal, compaction), mining field choice (assignment validation, chunk search, target assignment) and continuous repeat refill (queue state, cycle refresh, station repeat). Economy suite 0 failures, determinism probe identical; no gameplay change.

- [ ] v0.97.27: Fix Follow never arriving at large map coordinates (pre-existing since v0.51.2): float32 position rounding left followers stalled exactly at standoff reach, so follow_arrived and queued successors never triggered. Follow arrival now accepts a 0.5-unit tolerance. Regression sweeps 32 approach angles at far coordinates (8 stalls before, 0 after). Economy suite 0 failures, determinism probe identical, solo/ENet smoke pass.

- [ ] v0.97.26: Repair stale solo and ENet smoke fixtures: freeze objective clock in pause check, Medium yard for Colony, distance-derived colonization/AI budgets; ENet stages station jobs within the 4-entry queue, finishes at 5x so sequential construction completes, retires removed territory_last overlay assertion, checks only fog-visible ships, records rogue/pirate observation once, refreshes a Military objective (v0.78.4 rejects refresh with unspent CP), and checks tax income rather than spendable balance. Solo and two-peer ENet smoke pass (6 consecutive ENet runs); three-peer not run.

- [ ] v0.97.25: Fix pulsar home clearance regression from v0.93.0: pulsar placement margin used the old 48-unit radius after fields doubled to 96, so some seeds (e.g. Grid seed 31, 6 players) placed a pulsar edge closer than the agreed 700 pre-normalization units to a home system. Placement now uses the shared ANTIMATTER_RADIUS. Affected seeds generate different maps; all economy tests pass (98), determinism probe identical.

- [ ] v0.97.24: Repair remaining stale economy fixtures: isolate PDS fire from station lasers/missiles and assert dock-berth approach; derive doubled fighter crew (v0.82.0) and Crystal Incubator population gate (v0.89.46); direct civilian paths validate endpoints only (v0.94.0). Opening pacing smoke becomes a regression guard at current provisional balance (~200-215 yr first colony, 3 worlds, 6 fighters by year 360; identical on v0.97.2) versus original 180 yr/4 worlds/8 fighters targets: AI opening pacing needs playtest review. map_layouts still fails on a real generator bug (next).

- [ ] v0.97.23: Empty miners finishing a delivery lane no longer spend a second movement budget in the same tick (moved up to 2x speed on arrival; verified pre-existing on v0.97.2). Repaired civilian-waiting, depleted-field and wide-patrol fixtures: hull max HP for freighters (avoids miner auto-repair parking), Auto-Trade off to isolate the waiting miner, field-to-field adjacency, and the 15% contact-correction budget. Runtime/ENet validation pending.

- [ ] v0.97.22: Withdrawing armed hulls now steer to their repair station when an earlier direct order (patrol, remote position) already left dest at that station with no route; previously they froze in place until fully regenerated (verified pre-existing on v0.97.2). Repaired sector-entry, local-position and tactical-order fixtures for contact correction, regen-before-withdrawal, free-space attack retargeting and same-sector patrol. Runtime/ENet validation pending.

- [ ] v0.97.21: Repair economy helper fixtures under current rules: Colony cargo, starting-fleet hull index, isolated station weapons/missiles, military dest at their node, capital savings with 4kt Metals storage, explicit warp traveler, passing fire, contact budget, Colony food delivery, follow standoff wait, float32 step tolerance. Verified bug (pre-existing on v0.97.2): generated asteroid anchors can lie inside a rock disk; non-miner sector/route orders to such a field never arrive (_move/_move_formation require exact node point). Fixture isolates rocks; fix needs agreed arrival rule (e.g. nearest clear berth). Remaining failing helpers: sector entry, local position, tactical, civilian waiting, depleted routes, wide patrol and later.

- [ ] v0.97.20: Economy test main body completes. Fixture updates for current rules: fighter speed, station weapons isolated via _disarm_structures, Crystal station baseline, passive regen, funded crew recipes, crew-reserved staffing, one-hold long mining and Organics-only residents. Generated-map AI startup window 36 to 60 years (measured first Colony year 41, Fighter 47 on all four seeds: possible slow AI opening, playtest). 22 helper scenarios and two script errors remain.

- [ ] v0.97.19: Repair stale economy test fixtures (yard classes, crew reservation, refunds, mining rate/hold, gradual dropoff, delivery pods, shipyard repeat, direct navigation routes, freighter kind). Root cause of the reported econ-test hang: a failed assert aborts _initialize so quit() never runs. Test-only; no gameplay change. Remaining failures continue from line ~2739.

- [ ] v0.97.18: Split enqueue into _enqueue_admissible, _resolve_enqueue and _enqueue_yard_port; public signature and rejection order unchanged. Parser, determinism probe and economy failure signatures unchanged.

- [ ] v0.97.17: Split _work_planet into _produce_planet_resources, _retain_yard_jobs and _next_yard_job. No behavior change; parser, determinism probe and economy failure signatures unchanged.

- [ ] v0.97.16: Split _ai_military_orders into _ai_reference_hull, _ai_scan_hostiles, _ai_attack_goal and _ai_assign_military. No behavior change; parser, determinism probe and economy failure signatures unchanged. Note: economy_rules_test hangs (not merely slow) after the tenfold asteroid fixture even with a 900 s timeout; pre-existing.

- [ ] v0.97.15: Split _work_salvage into _salvage_pickup, _next_wreck_salvage, _salvage_delivery, _salvage_depot and _unload_salvage. No behavior change; parser, determinism probe and economy failure signatures unchanged.

- [ ] v0.97.14: Restore original Follow order reset: Follow keeps existing tactical order (v0.97.13 helper also cleared it). Pre-existing on v0.97.2 baseline: solo_smoke fails at original line 146; two-peer ENet smoke times out missing station_plating, station_port_three, miner_deposited and objective checks; persistent_follow is timing-flaky. Parser and determinism probe pass.

- [ ] v0.97.13: Split _execute_unit_order: follow, sector entry, transform and position orders move into _order_* helpers; the repeated salvage/tactical/hold/work reset sequence becomes _reset_unit_for_order (six call sites, same call order). Determinism probe identical, economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.12: Split the 124-line _work_opportunistic_salvage into _salvage_nearby_cells, _nearest_salvage (ID tie-break unchanged), _approach_salvage and _finish_salvage_pickup. Claim order, threat computation and return values unchanged. Determinism probe identical, economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.11: Split freighter resource staging: _choose_resource_stage delegates to _stage_census, _best_mining_stage and _best_salvage_stage (salvage scan skipped when mining_only; pure, same result); _work_resource_stage delegates to _resource_stage_safe, _abandon_resource_stage, _salvage_site_available, _survey_mining_stage and _leave_loaded_stage. Strict-less scoring order unchanged. Determinism probe identical (helpers exercised in ai_match), economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.10: Split the 134-line _work_miner into per-mode handlers: _miner_evacuated (hostile return/evacuation), _miner_idle, _miner_delivery, _miner_outbound, _miner_extract and _miner_return. Field/anchor/service-point setup and call order unchanged. Determinism probe identical, economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.9: Split the 120-line _separate_ships into _separation_cells (spatial bucketing), _separation_exempt (order/state exemptions), _separation_force (neighbour push accumulation) and _clip_to_sector. Iteration order, budgets and clipping unchanged. Determinism probe identical, economy failure set unchanged, fleet benchmark within noise. No gameplay change; runtime/ENet pending.

- [ ] v0.97.8: Split the 149-line _sync_operations into _group_operations (owner/role/objective grouping), _reserve_operation_ids (persistent wave and same-key IDs), _match_operation_id (greatest-overlap inheritance), _assign_formation_slots and _classify_operation_members. Iteration order, ID allocation and slot assignment unchanged. Determinism probe identical, economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.7: Restore project.godot after an open Godot editor rewrote it in canonical form during v0.97.6, dropping the [display] window/stretch/hidpi settings and gui snap_controls_to_pixels. File content identical to v0.97.5 apart from the version. No gameplay change.

- [ ] v0.97.6: Split the 193-line _ai_turn into _ai_resettle (homeless colony recovery), _ai_census (hull/queue counts, reserved targets, useful fields, thresholds), _ai_station_goal (ordered goal selection) and _ai_pursue_station_goal (prerequisite substitution, funding and enqueue). Shared counts dictionary keeps per-station enqueue visibility; drop an unused team local. Determinism probe identical, economy failure set unchanged. No gameplay change; runtime/ENet pending.

- [ ] v0.97.5: Split the 339-line step into ordered stages sharing a per-substep step_frame.gd: _step_economy, _step_ai, _step_combat (+ _step_resource_handoffs), _step_formations, per-hull _step_hull (_step_hull_overrides, _step_hull_services, _step_hull_routine, _step_military_motion) and _step_settle_movement. Loop continue became return true so wander eligibility is unchanged. Determinism probe identical, economy failure set unchanged, battle tick p50 within 0.5%. No gameplay change; runtime/ENet pending.

- [ ] v0.97.4: Split the 469-line _combat into frame-based stages: _build_combat_frame, _combat_hull (missiles, focused attack, lasers, structure fire), _fire_station_weapons, _fire_planetary_defenses and _resolve_combat_damage/_resolve_shipyard_damage. Per-step buffers live in a new combat_frame.gd data holder. Bodies, iteration and mutation order are unchanged; determinism probe (AI match and battle) is identical, economy test failure set unchanged, battle benchmark within noise. No gameplay change; runtime/ENet pending.

- [ ] v0.97.3: Restore test baseline for refactoring. Fix duplicate loop variables that kept economy_rules_test.gd from parsing since v0.94.11; commit missing combat_kernels.gd.uid. Add tests/determinism_probe.gd: seeded AI match and two-empire battle print per-key state hashes at checkpoints; extractions must reproduce them exactly. economy_rules_test still has 24 failed assertions, 2 test-side script errors and a stall after line ~2214 (pending triage). No gameplay change.

- [ ] v0.97.2: Extract ordered combat target block construction, laser/missile nearest-target kernels and simultaneous damage accumulation into combat_kernels.gd behind the existing EconomyRules facade. Preserve packed arrays, bounds, tie order, EPS, mutation order and all network contracts. No gameplay change; runtime/ENet and benchmark validation pending. Next: repair spatial queries and combat phase orchestration.

- [ ] v0.97.1: All voluntary construction cancellations, including queued and active ship builds, return actual prepaid materials immediately to the originating station (allow temporary overflow), retain full GC and existing crew refunds, and create no salvage. Irreversible colony morphs and combat destruction unchanged. Queue hints, Codex and core assertions updated; Godot/ENet validation pending.

- [ ] v0.97.0: Rebalance major conquest multipliers, increase storage/housing/damage ranks, and add 17 repeatable economic/military/tech upgrades (extraction, loading, building speed, tax, upkeep, colony assembly, hull assembly, missiles, station repair/HP, sensor range, antimatter, staffing, delivery, orbital food, crystal/Dyson costs). Initial tuning. Independent unpaid hulls clear orders and escape conservative building claim/weapon envelopes while neutral; transform in place to a non-empire pirate owner, grey unmarked, no economy or diplomacy. Host pirate strategic decisions every three simulation years, local groups capped at 12, full-map sampled targets, strength ratio 1.5, retreat from danger, focused standard weapons and pirate-friendly combat buckets. No artificial spawning. Defer remaining brainstormed speed, cargo size, weapon/tractor range and incoming missile reduction pending cross-system refactor. Verify Godot parser, actual escape, group coordination, rewards/HUD, performance and ENet; runtime pending.

- [ ] v0.96.8: Non-Harvesters use earlier 240-unit lookahead, 26-unit preferred clearance and 12-unit swept physical clearance, cached bounded local AStarGrid2D detours for nearby clusters, compact swept waypoints, two-sided angular fallback and per-step planning budget (12 ships, at most two bounded searches each). Hull contact correction also respects rocks; miners retain existing access. Increase seeded rotation for roughly 30% of rocks, detail-only with cached rates. Codex and multi-rock regression fixture updated; runtime parser, blocked goals/tight pockets, high fleet counts, FPS and multiplayer validation pending.

- [ ] v0.96.7: Every empire opens with Economic: Upgrade a shipyard to Medium (one completed level-2 yard upgrade, not a queued job) and Military: Build 7 fighters (existing lifetime fighter counter). Both opening objectives can be rerolled via existing independent 60-second cooldown. Subsequent objectives use the normal eligible random draw after CP is spent; remove forced colony-chain successor but retain colony goals and their prerequisites. Codex and authority regression fixtures updated; runtime and ENet validation pending.

- [ ] v0.96.6: Soften territory visuals only: world fill opacity 9.5% → 4.5%, rim 38% → 19%, white rim highlight 24% → 12%; minimap/setup baked alpha 45/95 → 28/65 (retain legibility at small scale). Claim geometry, colors, fog/visibility, influence, navigation and warning destinations unchanged. Visual verification pending.

- [ ] v0.96.5: Cloaking Field requires three previously purchased military-category rewards (repeatable military ranks count; general/economic/tech do not). Existing unique claim, Scout effect and cost unchanged; eligibility checked by draft and authority purchase. Add subtle GPU parallax to existing three starfield layers, with depth factors 1.5%, 4.5%, 8.5% of screen-space camera travel plus slight logarithmic zoom. Cache camera uniforms; menu backdrop, haze, gameplay entities and networking unchanged. Codex and authority fixtures updated. Godot runtime, visual/FPS and multiplayer validation pending.

- [ ] v0.96.4: Multiply ordinary asteroid radii by four while preserving seeded size variation, rock count, RNG sequence and ore amounts; choose existing placement samples using edge clearance, cache rock extent for culling/picking; collision and mining use actual radius. Pulsars unchanged. Base (level 0) station Metals storage 4,000 t; other base resources remain 2,000 t and upgraded tiers/starting holdings unchanged. Resource-specific capacity drives production, thresholds, empire totals, cargo bays, HUD and AI. Attach compact MM:SS simulation clock above the minimap, reserve notice/chat clearance; no network change. Verify large rock gaps and map bounds, storage/thresholds, timer layout and FPS, solo and ENet; runtime pending.

- [ ] v0.96.3: Limit station infrastructure, each shipyard and unit command chains to four entries including active jobs/orders (pending planetary delivery still counts). Authority enqueue rejects full queues before payment; repeats remain armed and wait for space, shipyard shared unassigned pool retains aggregate capacity. Build hints and station count use the common cap; Codex and rule fixtures updated. Asteroid detailed meshes use cached seeded clockwise/counterclockwise spin at 0.003–0.008 rad per simulation year; rotate with one basis per visible rock, no distant/fog animation or new simulation/network state. Godot parser, visual, solo/ENet and FPS verification pending.

- [ ] v0.96.2: Add Shipyards (Z) to the station Build submenu's bottom-left slot; share the primary card's selection action, completed-yard count, disabled state and hint for single or grouped stations. Keep Return bottom right and construction Shipyard (X) unchanged. Codex updated; visual/runtime verification pending.

- [ ] v0.96.1: Mining Freighters prioritize worker readiness and pickup travel time, account for depot distance and competing haulers, track returning workers, and compare further pickup time or another mining pool against a bounded distance/load-dependent idle window (8–40 yr). Front receivers accept physical handoffs during approach. Loaded Harvesters compare cooperative rendezvous ETA with depot ETA, using a per-owner spatial index of eligible front berths within 1,600 units and per-step full-load capacity commitments; existing physical transfer, autonomy, safety, and fallback delivery rules remain. No new RPC or order type. Provisional thresholds; benchmark worker searches, route churn, throughput, full and partial cargo, empty/unsafe sites, queue ranks and ENet. Runtime pending.

- [ ] v0.96.0: Replace ordinary field footprints and group selection with individual rock rendering, selection and inspection across setup, fog and minimap. Maintain seeded initial rock memory and per-rock last-seen depletion; existing field discovery still gates mining orders. Keep invisible pools for generation, AI, mining policy and logistics. Non-Harvesters avoid individual conservative rock disks using a depletion-invalidated spatial grid, nearby tangent steering and swept step clipping; Harvesters retain mining access. Freighter berth and queue checks use local rocks. Pulsar exclusion unchanged. Slow visual rotation at detail zoom only; defer translational drift and asteroid-to-asteroid physics until performance is measured. Core fixture updated; verify parser, gap traversal, picking, fog, freighter delivery, large fleet benchmarks and ENet.

- [ ] v0.95.3: Remove setup preview legend; draw immutable asteroid outlines rather than enclosing radius circles in setup, minimap and unexplored fog. Unexplored ordinary terrain is visible without revealing current ore, discovery or mining commands; pulsar discovery unchanged. Vary belt length (1–13 lobes), width and curvature, use 16–26 rocks per lobe and seeded best-of-six spaced samples, variable rock sizes and silhouettes. Dark gray/brown stones with embedded pink crystal flecks; existing ore amounts per rock and crystal share cap preserved. Lower rock count also lowers total ore on average. Verify seed diversity, preview, fog/selection, zoom, generation time and ENet; Godot runtime pending.

- [ ] v0.95.2: Colonize travels to the near radial point on the existing station orbit from the actual hull position, updating approach after obstacles; order visualization uses the same endpoint. At irreversible assembly start persist orbital phase in authority-created colonize order; completion copies to station dictionary so orbit stays continuous. Existing stations and legacy fixtures retain default phase. Shipyard footer replaces unused second slot with Build (B), selects primary parent station and opens its existing Build submenu after selection refresh. Codex updated; economy and ENet fixture assertions expanded, runtime/visual/peer validation pending.

- [ ] v0.95.1: Starter military construction objective counts seven completed Fighters via existing fighters_built metric; subsequent objectives unchanged. Triple all eight paid hull upkeep rates, zero-upkeep structures unchanged. Small yard row Scout, Fighter, Harvester; other rows already cost ascending. Right-click known asteroid hit assigns its chunk ID across full belt extent; empty field space uses existing exact move (Shift queues), minimap clicks move except pulsar collection. Use remembered rock data, depletion-scaled hit radius and existing authority validation. Codex and economy/peer fixtures updated; visual/runtime/ENet pending.

- [ ] v0.95.0: Grow ordinary asteroid deposits into seeded open chains of 2–10 overlapping lobes (36 rocks per lobe), with irregular union outlines, protected star corridors, nonadjacent and inter-belt separation, and open perimeter. Retain original anchors, graph ports, resource policy and special pulsars. Non-miners route along padded belt outlines; miners enter, freighter staging exits along return rays. Belts persist until depleted. Fix trailing empty line in structure_view.gd. Verify generated density, connected free space, multi-obstacle routes, queue staging, picking, render/load scale, parser, solo and ENet; runtime pending.

- [ ] v0.94.20: Draw incoming planetary production pods after their station and shipyards so they remain visible over the opaque station hull and storage circles. Preserve original live-fog gate, detail fade, offscreen culling, destinations, upgrade-delivery ordering and simulation. Codex remains accurate. Verify close-zoom arrival layering and fog; visual/runtime/ENet pending.

- [ ] v0.94.19: Command info prioritizes red blockers above effects; show exact missing planet/deposit, completed cap, pending job, staffing, yard size and full queue reasons. Permanently unsuitable station cards receive a subtle red background/icon tint; only if all selected stations are unsuitable for group commands. Resource and GC shortage styling, repeat toggles, construction and authority unchanged. Codex updated. Verify single/group selection, short panels and disabled/armed hover in Godot; visual/runtime/ENet pending.

- [ ] v0.94.18: Residents consume Organics only; remove metal upkeep, reserve-production workaround, Material Efficiency research and Crystalline Synthesis civilian metal penalty. Keep food/growth, construction costs, taxes and ship wages. AI saving uses mineral output without civilian demand, and food net output. Metal/crystal hover omits demand; Colonize (C) replaces Send Colony on the neutral system card, existing dispatch and hotkey overrides retained. Verify consumption/stock conservation, reward draws, AI, neutral/fog targeting, shortcut and ENet; runtime pending.

- [ ] v0.94.17: Allocate mining Freighters by active Harvester throughput and estimated depot round trip, including outstanding resource hauls. Empty idle freighters prioritize bounded mining coverage, excess ships seek trade (penalize already assigned routes) and salvage. Mining arrivals form a stable FIFO line tangent to a shared field-edge berth with 80-unit spacing; only the front receives there, loaded ships depart toward storage. Detailed Freighter cargo and hull draw together to avoid cross-hull layer bleed. Provisional throughput and spacing require playtesting; verify multi-site demand, moving/depleted workers, partial cargo, safe queue points, trade balance, render performance and ENet.

- [ ] v0.94.16: Station Build repeat uses one authority eligibility policy independent of current requirements; production and PDS may be armed while planetary prerequisites are missing, and orbital housing repeats one prepaid job at a time. Manual construction remains gated, capped upgrades stop at completion, right-click toggles remain available while blocked. Verify low population, stock/GC shortages, unsuitable planets, mixed selections and ENet; runtime pending.

- [ ] v0.94.15: Once Colony assembly begins, morphing is irreversible: reject replacement/queued orders, direct dispatch and autocast on authority, drop pending orders, prevent AI redirection and wage defection during assembly, reserve the site for the first morph and keep the hull vulnerable. Follow the orbit continuously until completion; display noncancelable progress bar and blank command card. Mixed fleet orders exclude morphing hulls. Single shipyard inspector reuses local station stock, production and population breakdown (including hover), alongside yard queue. Verify competing colonies, attempted cancellation/RPCs, progress and shipyard layout; runtime/ENet pending.

- [ ] v0.94.14: Shared command-card construction cost numbers use the standard white text when affordable and red for shortages, including GC. Preserve gold credit icon, treasury HUD color, upkeep, actual costs and validation. Codex remains accurate; visual/runtime checks pending.

- [ ] v0.94.13: Fix repeated station storage polygon triangulation errors. Cull offscreen storage rings, approximate invisible quarter-pixel fill/empty caps with empty/full circles, use screen-size-dependent circular segment tessellation and validate triangulation before drawing. Preserve bay centers, counts, colors, stock and bottom-up fill. Codex already accurate. Check tiny/near-full fill across zoom levels, error log and FPS; Godot/visual/ENet pending.


- [ ] v0.94.12: Colony settlement (Send Colony, queued colonize and Transform) flies directly to the normal station orbital position, then transforms over 30 simulation seconds at that orbit. The live ship owns progress until completion, when crew/cargo transfer once and the station/founding yard become operational. Interrupted/invalid orders clear progress; contested target remains neutral until completion. Draw expanding station ring and founding yard with fading colony hull; remove prior star-to-orbit slide. Verify 1×/5×, cancellation, competition, population conservation, peers and visual continuity; runtime pending.

- [ ] v0.94.11: Station Build right-click repeat applies to all selected owned eligible stations, including Habitation, PDS and Shipyard. PDS and Shipyard repeat enqueue at most one job of each type at a time, retry funding, and stop at existing limits. Orbital housing remains manual (uncapped). Mixed repeat toggle enables all eligible if any off, otherwise disables all. Shipyards selects every completed yard of selected owned stations. Trade edits apply the displayed resource's complete percentage/toggle policy to all selected owned stations; other resources unchanged. Existing validated per-station RPCs retained; regression, visual/runtime/ENet pending.

- [ ] v0.94.10: Tighten regular asteroid navigation disks to the surviving rock extents plus clearance, cached per map/rock count; preserve pulsar exclusion and generated topology. Freighter mining stages require actual owned working or nearby returning Harvesters. Use their actual rock-to-useful-depot direction, projecting a reachable berth beyond the exclusion boundary when necessary; refresh on staggered searches, abandon inactive sites, retain physical handoff range, safety, trade priority and partial/full delivery rules. Verify deep-rock exits, depletion, multiple miners and peers; runtime/visual/ENet pending.

- [ ] v0.94.9: Remove the legacy home-system-only Freighter construction gate from manual/group building, station repeat/maintain, shipyard autobuild and empire fleet refill/availability. AI may use suitable non-home yards while retaining its home investment strategy. Preserve ownership, Medium/Large yard fit, staffing, prepaid materials/credits, crew reservation and queue limits. Remove obsolete command-card requirement and update Codex. Regression covers non-home orders and automated admission; runtime/visual/ENet pending.

- [ ] v0.94.8: Consecutive Shift-queued patrol orders form a persistent closed circuit from the original start through every waypoint and back. Preserve the single-leg arrival and combat/repair rules; a queued non-patrol successor exits after the last forward waypoint (or the current return endpoint). Keep all waypoints within the 30-order budget, render the entire selected circuit and replicate through existing ship dictionaries. Verify repeated cycles, queue interruption, invalid targets, formation/repair and real peers; runtime/visual pending.

- [ ] v0.94.7: Resource HUD bars include one blue fleet-cargo segment alongside existing station stock segments; total fill uses station storage capacity plus actual onboard cargo, while net trend remains storage-relative. Hover lists total, station stock/storage capacity and ship cargo. Scout base construction doubles to 120 Metals, 4 Organics, 244 GC and 200 crew; existing reward modifiers and discounts apply, work and upkeep unchanged. Verify empty/full/cargo-only bars, transfers, crew reservation, pricing and solo/ENet; runtime/visual pending.

- [ ] v0.94.6: Station storage bays use circular resource-colored outlines and proportional bottom-up circular fill, preserving bay positions, counts, colors and stock rules. Verify empty, partial and full bays at detail zoom; runtime/visual/ENet pending.

- [ ] v0.94.5: All conquest reward effects use concise player-facing descriptions, HUD resource/population and command icons, separate green benefit and red cost rows, and Select buttons. Research effects reflect base additive bonuses or approximate marginal reductions for divisor-based ranks. Preserve actual costs, rewards, rarity and authority. Verify card wrapping at narrow resolutions and live reward availability; visual/runtime pending.

- [ ] v0.94.4: All construction remains prepaid for local materials and GC. Hull admission atomically reserves the full crew via existing population_cost minus population_allocated; available crew excludes other reservations and preserves eligible shipyard staffing. Reserved residents still pay taxes, produce and consume at 0% progress; first positive work transfers the full crew out of resident population, counted once in construction crew. Preserve 50k colony origin resident gate, cancellation material policy, credits and crew refunds. Manual, group, repeat, per-yard and empire autoqueue share authority admission; command info reflects unreserved population. Actual resident losses after reservation can postpone embarkation without enabling overbooking. Update core regression assertions; Godot and ENet validation pending.

- [ ] v0.94.3: Right-click known neutral star with selected Colony issues existing automatic colonize order; Shift appends, explicit Move/Alt preserves movement. Use fog memory and actual star hit (including minimap); host revalidates unclaimed target on issue and execution. Active selected Colony shows dotted command line and star-sized white ring. Multi-selection retains per-hull contextual commands. Core and peer fixtures extended; runtime/UI/ENet pending.

- [ ] v0.94.2: Command info tracks unmet requirement lines separately from resource shortages; colony origin population line uses authoritative threshold for single and group shipyards, and production/warehouse/yard upgrade population gates are colored red independently of cost affordability. Tooltip signature includes gate state so color refreshes as population grows. Visual/runtime validation pending.

- [ ] v0.94.1: Start with explored (not live) space at three times the initial visible territory radius; seed authoritative star/field discovery and reconstruct opening fog memories once. The only ship-activity exclusion for Send Colony is an active colonization assignment; dispatch cancels retreat and ignores previous sector ownership. Neutral-star selection rings hug the drawn star. Visual, runtime and ENet validation pending.

- [ ] v0.94.0: Direct civilian navigation migration. Normal freighter, colony, miner delivery, evacuation and salvage routes retain destination only; miners fly from their actual position to a rock and back to a useful owned warehouse without field access-star stops. Resource staging and AI colony targeting use physical distance; scouts choose direct system objectives rather than lane neighbors. Retain endpoint permissions, dock range, cargo checks, integer route format and legacy map geometry for non-navigation consumers. Command line displays final intended destination (not obstacle detour). Verify direct travel, hostile exposure, docking, mining, old route fixtures, large fleets, asteroid detours and real peers; runtime pending.

- [ ] v0.93.2: Color insufficient local population red in the command information panel, matching missing resource costs. Visual validation pending.

- [ ] v0.93.0: Double field radius (fourfold area), quadruple rock count using original rock sizes; expand placement search. Non-miners detour around conservative field disks during shared navigation. Interior target handling, formation/collision bypasses, depletion, map placement and ENet require further verification; runtime pending.

- [ ] v0.93.1: Send Colony can replace any ordinary movement or work order, including an active sector route. Preserve existing colonization assignments and destination validation; retreat exclusion superseded by v0.94.1. Runtime and ENet pending.
- [ ] v0.92.1 (movement restriction superseded by v0.93.1): Send Colony displays Colony En Route and prevents duplicate automatic dispatch to the same world. Nearest available selection accepts local work and autonomous cargo delivery, excluding assigned colony travel, other sector routes and retreat. Host chooses using existing request. Verify rerouting, cargo retention, cancellation, arrival and ENet; runtime pending.

Living roadmap. Build a playable, low-micro galactic RTS with conventional direct military control and autonomous physical logistics. Policies and regional card assignments are intentionally removed. Preserve the working RTS foundation while developing the agreed neutral diplomacy and hidden global Revelation direction below. Promissory notes and older endgame proposals remain subject to review. Target 10–30 minute matches at 1×, subject to playtesting.

Review AGENTS.md before work. This is a prioritized backlog, not blanket approval to invent mechanics. Numerical balance remains provisional. Earlier implementation history and the superseded policy roadmap are preserved in git (v0.17.36 and earlier).

- [ ] v0.89.42: Verify rearranged HUD, control group and F1–F4 strip alignment (v0.89.51), persistent empty center/right panels and input blocking at varied resolutions.

- [ ] v0.89.44: Playtest quadratic production population gating (v0.89.46; 30k base), precise blockers and diagnostics lens placement; run economy and peer checks.

- [ ] v0.89.47: Diagnostics below Menu, horizontal common-scale simulation phase bars with exact values, separate network metrics; resident tax halved to 0.5% per year. Upkeep unchanged. Verify overlay fit and economy/peer checks.

- [ ] v0.89.48: Shorten command, resource and control tooltips; retain icon costs and yield. Ship construction GC fees scale 2× small, 3× medium, 4× large; material costs and wages unchanged. Visual table/icon follow-ups and runtime validation pending.

- [ ] v0.89.49: Allow direct manual navigation within enclosed three-sector junctions using cached Delaunay faces of mutually overlapping sector disks; retain existing region boundaries, discovery restrictions and open-space rejection. General multi-region smoothing and autonomous miner anchor detours remain follow-ups. Validate on actual maps and peers.

- [ ] v0.89.50: Stations gain one launcher using existing 120 damage, 1200 range, 12 s cooldown. All missiles apply full damage within 30 world units to hostile hulls and structures only via frozen combat cells. Station missile tracer uses station snapshot metadata. Runtime/peer validation pending.

- [ ] v0.89.52: Empire dialog uses wide independent diplomacy and fleet columns, compact rows, sparse slider labels, numeric targets and explicit active/queued counts. Borderless in-game modals with internal labels/actions; no external title bar or X. Visual verification pending. Check narrow windows, keyboard dismissal and authoritative target updates.

- [ ] v0.89.53: HUD refinement: 10% shorter deck, left-aligned queues, numeric HP unchanged, compact aligned shortcuts, passive header styling and inline GC, color-only population segments, objective progress strips, brighter minimap/explored fog and subtler logistics backgrounds. Preserve slots and commands; validate small windows and readability. Further icon and map hierarchy tuning after visual review.

- [ ] v0.89.54: Remove player-facing 1× simulation-speed qualifiers from command hints, ship summaries and Codex; retain baseline durations and rates. Increase shared hotkey badges to 13 px and global F1–F4 buttons to 52×40 px, restoring captions. Verify icon/badge fit and small-window strip layout; runtime validation pending.

- [ ] v0.89.55: Replace physical-resource header annual deltas with white directional chevrons at the storage fill edge. One below 0.5% capacity/yr, two from 0.5%, three from 2%; hide below 0.05 t/yr or without capacity. Keep precise hover breakdown and local rates. Credits and population unchanged. Verify contrast and fit at empty/full bars.

- [ ] v0.89.56: Shorten command captions to Plating, Lasers, Shipyards, Upgrade, Clear and Shipyard; preserve contextual tooltip details, hotkeys, slots and mechanics. Verify visual fit.

- [ ] v0.89.58: Render visible cloaked scouts at 30% hull opacity, including overview dots, instead of a purple status ring; suppress their exhaust while cloaked. Keep ordinary selection rings and authority visibility predicates. Use separate recycled translucent MultiMesh batches, preserving opaque hull buffer format. Visual/peer validation pending.

- [ ] v0.89.59: Darken construction/upgrade command backgrounds whenever the corresponding manual build cannot start, including repeat-enabled and multi-selection cards. Preserve right-click automation and authority eligibility; omit redundant queued-upgrade hints. Check recovery when population or resources arrive, queue completion and mixed selections. Visual/runtime validation pending.

- [ ] v0.89.60: Center white trend chevrons in resource and population bars; population retains total but drops numeric growth rate. Use existing capacity-aware net_rate for resource trends; full stores with surplus but no room contribute zero. Preserve demographic growth semantics and existing magnitude thresholds. Place GC before storage tiles; compact resource/population widths to 104 px and reduce GC minimum/padding. Hover retains precise rates. Visual/runtime/peer validation pending.

- [ ] v0.89.61: Increase resource/population/GC balance labels to 15 px and left-align beside icons. Reserve the conquest column beside population; start objectives at the top when space permits, otherwise below the header. Keep notifications/chat left of objectives. Underline Total Conquest Points like Objectives. Anchor F1–F4 at the right wing's left edge; control groups remain to their left, with a stacked fallback in narrow windows. Visual/runtime/peer validation pending.

- [ ] v0.89.62: Assigned control-group tiles show the most numerous surviving ship type (alphabetical type key breaks ties) or structure portrait, followed by the exact membership count; unassigned tiles retain their key number. Size occupied tiles to fit the count, preserve numbered recall and hover hints, and reflow the existing shortcut layout when membership changes. Visual/runtime/peer validation pending.

- [ ] v0.89.63: Every completed objective grants exactly 1 CP in its category, regardless of completion order or ties. Keep first-finisher metadata solely for existing presentation/audio. Category headers show names only; Upgrade hover and lifetime scoreboard remain. Verify first/tied/later payouts, no repeat award, spending and ENet synchronization. Runtime/peer validation pending.

- [ ] v0.89.64: Right-align objective and lifetime CP headings with collapse controls on their left. Move combined personal notices, tactical warnings and all-chat above minimap, newest at bottom, ten-second fade when closed. Enter opens a translucent scrollable local history (250 messages); Enter sends chat, Esc closes, slash commands stay local. Debug-only /devmode, /help, /status, /speed and /clear share the panel; speed remains host/solo-only. Preserve clickable warning locations, no new RPC. Verify scrolling/focus, resize, fading/history dedup, alert navigation, debug/release and ENet. Runtime and visual checks pending.

- [ ] v0.89.67: Replace inline numeric GC net income with centered white chevrons beneath balance, without storage fill. Share the resource chevron drawing and tiers; scale recurring net income to current treasury with STARTING_GC as the minimum reference (not a cap). Retain hover rates and unpaid wage warning. Visual/runtime validation pending.

- [ ] v0.92.0: Completed infrastructure grants live vision over its full compact territory influence support (including merged claims) plus 160 world units. Preserve existing ship/structure sensors, cloak and alliance vision permissions. Uses shared radial reach and cached map radius; verify fog, discovery, loss of infrastructure and ENet. Runtime pending.
- [ ] v0.91.11: Revert the v0.91.9 radius doubling across world, minimap and setup preview; retain reduced opacity. Visual validation pending.
- [ ] v0.91.10: Solo and lobby map previews draw the shared cached minimap territory fields beneath stars and deposits, using actual starting infrastructure and roster colors. Refresh on map or ordered roster/color changes; no simulation or network changes. Verify preview alignment, recoloring and setup responsiveness; runtime pending.
- [ ] v0.91.9: Double the visual building territory kernel radius; halve map and minimap fill and contour opacity. Preserve cached fields, fog memory and simulation rules. Profile rebuild cost and verify overlapping claims visually; runtime/ENet pending.
- [ ] v0.91.4: Replace temporary fleet glow with cached building-only continuous territory fields. Compact radial contributions merge for each empire; strongest above threshold claims the point, neutral space remains empty, and GPU contours mark only external/rival boundaries. Same cached fields drive minimap. Track last-observed infrastructure through fog; rebuild on known building weight/ownership/color changes, not hull movement. Remove star name overlay; retain inspector names. Legacy tactical alerts/navigation remain independent. Tune provisional reach/strength/opacity and verify shader compatibility, fog, overlapping claims, large maps and real peers; runtime/visual validation pending.
- [ ] v0.90.2 (fleet-glow presentation superseded by v0.91.4): Hide sector and highway borders, minimap grid/lanes and setup preview links; show localized soft player-color presence around visible infrastructure and fleets, shared with minimap. Asteroid boundaries only when selected; sector order outlines become target reticles. Keep existing hidden navigation, influence and tactical warning rules until free-space movement is migrated explicitly. Validate fog/cloak, scale, overlap, large-fleet performance, solo and ENet; visual/runtime validation pending.
- [ ] v0.91.0: Stage 1 free-space navigation: exact position/formation, patrol, guard, follow and manual service travel use straight-line steering to bounded coordinates, regardless of discovery at the destination or territory influence. Known POIs are bookkeeping anchors only. Preserve target discovery/ownership checks, arrival, docking and queue semantics. Legacy POI routing, autonomous logistics, tactical sector restrictions and map graph remain pending migration. Runtime and ENet validation pending.
- [ ] v0.91.2: Fix the reported _launch_to_rally Array-to-Array[int] runtime error from v0.91.1: _rally_path constructs one explicitly typed integer array on every return branch. Extend existing shipyard rally semantic fixture for same-system, remote and invalid endpoints, plus direct remote launch travel. Runtime/ENet validation pending.
- [ ] v0.91.1: Stage 2 free-space navigation: military deployments, AI fleet allocation/redirects, repair travel and launched rally movement now use direct destinations. Strategic distance estimates use actual hull positions; the legacy distance/next dictionary remains a compatibility adapter. Coordinated formations use their existing shared advance only when aligned; off-axis groups approach destination slots directly. Shipyard rally target eligibility remains unchanged. Civilian logistics, colonization, scout exploration and tactical proximity migration remain open. Runtime, benchmark and ENet validation pending.
- [ ] v0.91.8: Stop pauses normal movement/automation for the existing arrival cooldown even if a behavior normally has zero cooldown; new orders or enabling automation override the pause. Emergency withdrawal remains higher priority. Wander uses per-hull idle-position anchors and nearby spatial groups rather than sector/star centers; held ships return directly to their captured coordinates. Remove Last seen labels while keeping remembered fog data. Remaining civilian/Explore routes still use legacy sectors. Host ship fields stop_until and wander_anchor are replicated with existing dictionaries and reset on orders; regression fixtures updated, runtime/ENet pending.
- [ ] Free-space navigation follow-up: remove dependence on hidden sectors and highways for movement, combat, automation and logistics; define valid destinations and preserve discovery, service, diplomacy and safety semantics. Stage separately with multiplayer regressions.
- [ ] v0.90.0 (hidden rules only; visual borders superseded by v0.90.2): Continuous bounded Voronoi influence map: stable system/field/highway-midpoint sites, cached polygons and shared borders, actual polygon adjacency spillover, matching minimap. Keep existing local tactical disks, point-order targeting and highway graph separate for this stage; broader selection/local combat/automated logistics migration pending; manual shortcuts require full-strength exclusively friendly/allied influence over the whole segment. No new replication fields. Validate map coverage, visuals/fog, boundary ties, route fallback on influence loss, combat/AI, solo/ENet and fleet performance.

## Agreed design direction — hidden global Revelations

- [ ] Dynamic diplomacy: replace fixed team membership with independent bilateral relationships between empires. Allow overlapping, non-transitive mutual alliances, neutrality and multi-sided wars. Empires without an alliance or war start neutral, not hostile. Explicit war declaration or confirmed deliberate attack initiates war. Before an explicit attack on a neutral ship or station, show a declaration confirmation identifying the targeted empire; confirmation initiates war and issues the attack, cancellation leaves neutrality and discards the order. Ordinary movement, patrol and autonomous weapons never initiate war; area attack-move does not implicitly declare war. Reject attacks and declarations during an active truce. Either side may offer peace, requiring mutual agreement. Enforce a 100 simulation-year bilateral no-combat truce. Put diplomacy in Empire. Define war acts, queued orders, alliance formation/breaking, whether allies must join wars, lobby migration and victory semantics before implementation; validate ownership and treaty state at authority, including AI and real peers. Do not equate alliances with exclusive team IDs or assume friendship/hostility propagates along alliance chains.
- [ ] Per-alliance permissions: shared vision and trade enabled by default, configurable independently for each alliance; repair service always enabled while allied. Resources remain separately owned, never pooled or freely exchanged. Ordinary inter-empire exchanges require fair compensation; explicit gifts are an exception. Gift command specifies recipient, resource and quantity; autonomous logistics ships physically deliver from the giver's export-enabled stations, honoring export thresholds, available cargo and destination capacity. Define bilateral permission change/acceptance rules, gift eligibility when trade is off, in-flight cancellation and trade valuation before coding. Use Galactic Credits for compensated trade; see currency requirements below.
- [ ] Galactic Credits: empire currency with passive tax revenue proportional to resident population; add a credit expense to every construction recipe (ships, stations, structures and upgrades). Reference trade valuation uses 1 GC/t Organics, 2 GC/t Metals and 8 GC/t Crystals as provisional baseline, with Antimatter roughly 50,000 GC/t as directed. Credits are transferred electronically while materials remain physical. v0.86.0 implements 5,000 GC per empire and annual tax of 1% of resident population (exclude ship crews and embarked construction crew), with authoritative fractional accrual, existing snapshots and HUD/Codex. Verify against opening income and construction prices. v0.87.0 adds prepaid construction fees based on half of fixed reference material valuation, full GC cancellation refunds, repricing refunds and common authority affordability for AI/automatic construction. Colony station deployment is prepaid; Warp Gates have a separate 1,000 GC fee. Validate balance and then implement upkeep and automatic market pricing. Resource trade prices fluctuate automatically in response to supply and demand, using reference valuations as anchors rather than fixed transaction prices. Keep adjustments predictable and bounded; tune rates and limits by playtesting. Preserve material and crew costs and prevent double spending at authority. Show balances, income and costs in HUD/inspectors and Codex when implemented.
- [ ] Fleet operating costs and unpaid wages: v0.88.0 implements recurring upkeep on completed mobile hulls, civilian-first payments after tax and before production, no borrowing or back pay, continuous unpaid timestamps, net income and clickable grouped warnings. Validate rates and real peers. v0.89.0 implements prolonged-unpaid defection: 60-year grace, 0.5% per 10-year check, deterministic host roll, neutral independent passive hulls preserving cargo and crew, cleared orders and owner-only grouped clickable notice. No implicit war or violation of truces. Verify runtime, AI replacement pacing, legacy fixture compatibility and eventual rogue behavior. Keep accounting and defection authority-owned, bounded at large fleet sizes, and visible to the owning player. See THOUGHTS.md for proposed tuning.
- [ ] Hidden global event framework: investigations via science vessels, fog-dependent anomalies and random events offer resources, buffs and ambiguous clues. Support at least 20 distinct shared match outcomes with substantially different mechanics, objectives and team dynamics; avoid clues that uniquely telegraph an outcome. Every outcome should account for earlier player choices, investment and preparation. Preserve alternate roles for peaceful and military empires; define pacing, elimination and victory rules before implementation.
- [ ] Prototype information channels (private findings, optional public news, deliberate sharing), genuine authority-side secrecy and fog-filtered replication. Define a seeded host-authoritative scenario/event director and reusable anomaly chains; keep mini-games and individual scenario rules subject to review. See THOUGHTS.md for unapproved candidates.

### Revelation 01 — Imposters (agreed concept; implementation details pending)

- [ ] Foreshadow with apparently friendly phantom ships emerging from fog and inexplicable population spikes. Mix with other ambiguous anomalies; reuse motifs across unrelated Revelations so they do not uniquely identify this scenario.
- [ ] Reveal that shapeshifting aliens already constitute more than half of every player's population, including rulers. Each individual player (not team) has 30 seconds with full map vision to select any existing ship belonging to their own empire as their queen, retaining its normal properties. Opponents can identify queens only through behavior, not appearance, inspector data or other queen-specific cues; keep queen identity private in network state. Dissolve all alliances and put all empires at war with one another, superseding earlier diplomatic arrangements for this Revelation. AI manages all empire units, production, economy and wars; only each player's own queen accepts their commands. Reveal the entire map to every player. AI treats queens like ordinary ships, with no special protection or targeting; queens must blend in. Do not introduce docking mechanics.
- [ ] During queen survival, allow each player to suggest an enemy station as an attack target through the Empire menu; AI retains control over the attack and all empire forces. Increase all weapons' damage globally by an additive 10 percentage points of their base damage per minute, including queens, AI ships and defensive systems. Clock semantics and suggestion priority/cooldown remain to be tuned. Automatically assign an eligible own ship when a player misses the 30-second selection deadline. Announce queen deaths globally without revealing death location or killer.
- [ ] Last surviving queen wins, transforms into a small spaghetti monster and inherits every remaining player's ships, structures, units, sectors and resources. Preserve the world rather than resetting it. Players with no surviving ships at selection do not participate. Resolve reveal handoff timing and protection, normal abilities, simultaneous last-queen deaths, solo/AI/disconnect behavior and post-victory controls. Implement in stages: (1) authoritative diplomacy/phase primitives and dev-console Revelation command (no dedicated button); (2) queen selection, controller handoff, private identity and AI takeover; (3) attack suggestions, global damage escalation and queen-based win/asset transfer; (4) hidden scenario selection, shared ambiguous anomaly chains and news. Test each stage independently and on real peers before enabling normal hidden matches. See THOUGHTS.md for proposed details, not approval.

## Engineering structure

- [ ] v0.89.19: Verify README no longer becomes locally modified when opening Godot after pulling the whitespace-independent diagram.

### Code organization and maintainability

User requested AI-friendly structure and fewer duplicate definitions. v0.89.4 documents the ownership map and pre-edit rules. Baseline v0.89.3 has 22,787 lines across 11 production scripts (counts include trailing newline), with match.gd and economy_rules.gd accounting for ~82%. Prioritize safe extraction over a broad rewrite. The following is a staged engineering plan; each unchecked item needs implementation and validation.

- [ ] P0: v0.89.5 adds shared local/CI tracked-script discovery (`tools/check_gdscript.py`); establish a runnable parser baseline on current main; repair actual parser failures before extracting. Keep manual CI mode unless user requests otherwise. Add a local/CI entry point that checks every tracked GDScript (including future modules), existing metadata/import, semantic core, solo and real peers. Report missing runtime explicitly; avoid brittle regex substitutes for Godot.
- [ ] P1: v0.89.66: Extract chat widgets, notice history/dedup, fade drawing, hit rectangles and scroll lifecycle into match_notice_ui.gd. Match retains keyboard/modal gating, camera jump, authority chat dispatch and tactical tracker. Preserve existing layout, cap, timings, color and command behavior. Codex unchanged; runtime/peer validation pending.  v0.89.65: Extract local saved audio/camera preferences, config persistence and hotkey editor into match_settings.gd; preserve settings file, callbacks, widget creation order, conflicts and input gating. Match reads camera settings and retains menu lifecycle, key dispatch and music ownership. Codex verified unchanged; runtime/peer validation pending.  v0.89.57: Extract construction queue flow, tile reconciliation, progress/blocker styling and job labels into construction_queue_view.gd. Match retains queue dictionaries, job icon callback, selection and cancellation dispatch. Runtime/peer validation pending.  v0.89.6 extracts client-only tactical alert detection and cooldown state into `scripts/tactical_alerts.gd`; drawing and navigation remain in match.gd. v0.89.7 extracts CostButton and UI_TEXT formatting/read-only previews; Codex now shares ship names. v0.89.8 extracts reusable command-card widgets, command icons/cache and hint/fast popup helpers into command_card_ui.gd; card-specific actions and selection remain in match.gd. v0.89.10 partitions `_build_ui` into 13 responsibility-specific builders without reordering node creation or wiring. v0.89.11 extracts the independent trade threshold widget into trade_range.gd. v0.89.12 extracts command hotkey registration, conflict checks, override loading, badges and dispatch into command_hotkeys.gd. v0.89.13 moves hull geometry and portrait/hull/shield texture caches into hull_art.gd. v0.89.15 extracts per-client fog tracking, raster cache and drawing into fog_of_war.gd. v0.89.16 extracts territory layer/shader and influence caches into territory_view.gd. v0.89.18 extracts camera state, projection, zoom and pan math into camera_view.gd. v0.89.24 extracts snapshot audio history and world/upgrade cue detection into match_audio_tracker.gd; match retains camera context and mixer lifecycle. v0.89.25 extracts developer console and Perf sampling/presentation into match_developer_tools.gd; match retains input routing and deck geometry. v0.89.26 extracts conquest display, scoreboard, refresh buttons and upgrade cards into match_conquest_ui.gd; match retains chat/tactical notices and input routing. v0.89.27 extracts Empire fleet management, diplomacy rows and war confirmation into match_empire_ui.gd; match retains input, attack intent and modal checks. v0.89.28 extracts resource header and hover presentation into match_resource_hud.gd; shared delta formatting remains single-source and match retains local inspector ownership. v0.89.29 extracts ship interpolation, heading/thrust history and world pose cache into ship_motion_view.gd; match retains projection/visibility and draw ordering. Existing network smoke target-position assertion follows the new owner. v0.89.30 extracts GPU world render batches into world_render_batches.gd; match retains geometry generation, visibility and reset/flush ordering. v0.89.31 extracts celestial geometry, visual clocks, surface art and asteroid meshes into celestial_view.gd; match retains picking/visibility and system/production draw orchestration. v0.89.32 extracts destruction, beam/blaster effects and transfer animation history into world_effects.gd; match retains target/anchor resolution and draw/flush order. v0.89.33 extracts station/shipyard art, storage and construction drawing and shared station bay geometry into structure_view.gd; match retains picking, selection and draw order. v0.89.35 extracts command route/target indicators, queued destinations and formation preview art into order_view.gd; match retains selection, formation generation and dispatch. v0.89.36 extracts minimap drawing, projection and hit hints/pointer drag into minimap_view.gd; match retains modal checks, camera updates and command dispatch. v0.89.37 extracts logistics lens widget/state and station stock/population/traffic overlays into logistics_view.gd; match retains overlay and deck layout. v0.89.38 extracts selection portrait, weapon readouts and multi-ship tile/cache into selection_inspector.gd; match retains selection/focus and entity-specific detail panels. v0.89.40 extracts planet production and upgrade-delivery cargo pod rendering plus shared read-only production source/rate queries into planet_traffic_view.gd; match retains system draw ordering and inspector presentation. v0.89.43: Extract local control group storage, pruning, additive assignment and button refresh into control_group_manager.gd; match retains selection application, recall timing and layout. Runtime validation pending. Parser, visual and peer validation pending. Continue to extract client-only cohesive panels/helpers from match.gd, starting with tactical alerts and self-contained tooltip/formatting code; separately partition `_build_ui` into HUD, console, command cards, inspector, Empire and conquest components. Preserve fixed layout, hotkeys, selection state and presentation behavior. Later isolate camera/input and rendering layers, fog/territory, hull geometry and FX. Keep data flow through explicit inputs/signals, not copying the entire controller or per-frame state.
- [ ] P2: v0.90.1: Extract deterministic body generation, orbital position and system radius queries into system_geometry.gd; preserve EconomyRules facade, RNG order and canonical constants. Runtime/peer validation pending. Split simulation behind existing economy_rules facade: begin with shared constants/recipes and pure queries, then diplomacy, economy/construction, navigation, logistics, unit orders, combat, AI, objectives/rewards. Choose extraction order by actual dependencies; avoid circular preloads. Keep `create`/`step` and exact authoritative mutation sequence stable. Public queries replace match.gd private-helper calls gradually; UI/AI use the same rules. Move cache ownership/invalidation with its domain; no duplicate authoritative data or hot-loop allocation regressions.
- [ ] P3: Extract snapshot encode/decode and motion packing into a transport codec independent of scene lifecycle. Retain GameSession RPC endpoint names, sender/round/ownership checks, protocol and ordering. Document canonical state fields, units, lifetime, ownership, replication, derived indexes and reset paths beside responsible modules.
- [ ] P4: Break large test entry points into named domain scenarios with shared fixture builders while preserving all existing semantic assertions and deterministic scenarios. Separate lobby, economy, logistics, combat, diplomacy, orders and objectives coverage. Preserve real two-/three-peer and restart regressions; do not add styling tests.
- [ ] P5: Prune verified duplicate helpers/dead code, migrate consumers to public interfaces, and reconcile historical instructions/docs without deleting design history. Update source map and links per PR. Review diff for behavior parity, parser/import, core/solo/ENet tests and fleet/contested benchmark impact before closing module extraction items.

## 1 — Basic RTS (current priority)

- [ ] v0.89.21: Shared gold credits icon on HUD, construction costs and command upkeep; Codex uses the same icon and clarifies net income, production previews, F1–F4 and credit discounts. Verify layout, affordability colors, asset import stability and visual consistency.

- [ ] v0.89.17: Match detail panel width exactly to the command wing; display current incremental production at local population first (v0.89.20: omit 'now (X local)' suffix), reference per 10k (farms at 10k planetary residents) second, retain small-rate precision. Verify wrapping and local versus empire population in play. v0.89.14: Correct oversized command detail overlay reported in v0.89.9: explicit 55% deck height (65% ceiling), bottom flush with command wing, compact text, remove custom native cost tooltip and route live Trade hints through panel. Instant anchored command information for fleet, station, build, yard, asteroid and Trade controls; preserve dynamic recipe/affordability, icons and useful mode/target descriptions. Verify disabled/hidden commands, changing selection/stock, resizing and no duplicate native popup in play.

- [ ] v0.89.2: Simplify all station/build/yard upgrade tooltips: requirements, incremental benefit, current population yield and resource icon; native custom tooltip only on construction cards. Repeat production buildings need 500 residents × target level. Remove planetary mineral output ceiling; preserve asteroid limits, storage, blockade and farm behavior. Verify UI, authority gate, rates, balance and actual peers.

- [ ] v0.89.1: Explore ignores shared arrival/order cooldowns and starts whenever a scout is idle with no queued/manual orders; retain Hold, Wander exclusivity and all other cooldowns. Wander bottom-right, Explore adjacent, shift Repair/Trade to former Wander slot. Performance label above fog. Added authority and ENet fixture cases; visual/runtime verification pending.

- [ ] v0.89.0: Verify defection eligibility, recovery before grace, probability, stable hull IDs, neutral/passive behavior, objective/fleet/vision effects, authority-only transfer, notifications and snapshot replication. Regression, codec and real-peer fixture cases added; runtime and actual peer execution pending. Next: dynamic market pricing.

- [ ] v0.88.1: Prevent letter-by-letter wrapping of diplomacy relation labels; clip long empire names, wrap action buttons as a group and keep fleet heading next to fleet rows. Verify first open, narrow windows and all relations manually.

- [ ] v0.88.0: Validate recurring ship upkeep, net HUD income and red unpaid warning, civilian priority, speed/pause, payment recovery and snapshot arrears. Unit and codec checks added; Godot parser/runtime and real peers pending. Next: rogue defection mechanics after design review.

- [ ] v0.87.0: All queued construction reserves GC and materials atomically; fixed reference valuation × 50%, rounded up, after existing material discounts. Refund GC on explicit cancellation and yard compaction; combat destruction forfeits destroyed-job fees. Colony conversion is prepaid in the colony hull; warp deployment costs 1,000 GC. AI and autoqueue obey the same treasury guard. Tooltips, queue details and Codex show fees. Verify rejection, cancellation/compaction, completion, discounts, ownership, AI pacing, real peers and GUI; runtime pending. Next: upkeep and warnings.

- [ ] v0.86.1: Control groups draw at HUD depth above fog and territory; named star-system sectors render once in a passive above-fog overlay, including unexplored systems. Preserve tactical concealment and existing discovery/command rules. Verify camera pan/zoom, fog transitions, HUD overlap, clickable groups and solo/guest presentation; Godot runtime pending.

- [ ] v0.86.0: Galactic Credits foundation: independent 5,000 GC starting balances and 1% resident tax per simulation year, accrued from beginning-of-substep residents; no expense, trade or upkeep yet. HUD balance/net annual rate and hover breakdown; Codex. Economy, solo and actual ENet fixture coverage added for initialization, separate balances, ownership, pause/resume, restart and snapshot codec. Validate Godot parser/startup, economy, solo, peer sync and HUD at small resolutions before closing. Next: construction fees/refunds and AI budgets, then upkeep/defection, market, compensated shipments and gifts.

- [ ] v0.85.3: Correct extra indentation in `_refresh_territory` introduced in v0.85.0; verify Godot parse/startup and tactical territory warning destinations in solo and ENet. Static indentation and delimiter scan of eight GDScript files touched by v0.85.0–0.85.1 found only this malformed block; full runtime validation remains pending.

- [ ] v0.85.1: Strategic AI diplomacy approved and implemented: stagger slow authority decisions, estimate own/visible fleet strength and station defense, account for existing fronts, distance, common threats and possible third-party intervention. AI initiates/accepts reciprocal peace/alliance offers and declares profitable wars through existing treaty guards; respects truce and never auto-enters an ally's war. Provisional opening/cadence/thresholds require AI-v-AI, human-v-AI and ENet playtesting with fog and large fleets. Prevent diplomacy overrides during future forced Revelation phases. No automatic alliance betrayal or new victory rules.

- [ ] v0.85.0: New matched solo/ENet sessions initialize bilateral neutrality; remove lobby team picker, make selection/territory/alerts/AI target/explore/formation logic empire-aware, retain independent last-surviving-empire conquest fallback and legacy fixture API. Update Codex and solo/network fixtures. AI autonomous declarations, alliance and peace responses implemented in v0.85.1; coalition/alternate victory and paid trade/gifts remain pending. Validate parser, solo, real peers and visual interaction before closing.


- [ ] v0.84.3: Opt-in Empire diplomacy rows, two-sided alliance and peace offers, vision/trade preference buttons, mandatory repair display, war confirmation for explicit neutral-target attacks. Fix route cache separation of legacy and bilateral states. Extend existing two-/three-peer ENet smoke sequence with paused bilateral-mode lifecycle checks after legacy tests. Runtime, visual/peer validation pending. Enable normal matches only after fixed-team lobby/victory/remaining simulation and UI migration; paid trade and gifts still pending.

- [ ] v0.84.2: Neutral transit for opt-in civilian logistics/mining/salvage routes; relation changes invalidate route caches, ordinary transfers remain owned. Host RPCs for declarations, offers, alliance preferences and explicitly confirmed neutral attacks with round, sender, target ownership/visibility and armed-unit validation. Validate route changes in flight and actual peers; Empire UI and attack confirmation prompt, victory/lobby migration, paid trade and gifts remain pending. Normal matches retain legacy rules.

- [ ] v0.84.1: Opt-in diplomacy services: direct, non-transitive sensor/strategic sight and cloak detection; bilateral repair/follow with own-only material transfer; per-empire internal logistics group IDs, civilian threat caches and withdrawal eligibility. Verify all neutral routes, cargo orders, allied repairs, treaty cache invalidation and peer fog behavior. Paid inter-empire transport, gifts, neutral transit path migration, diplomacy RPC/UI, lobby and victory still pending; do not enable normal matches.


- [ ] v0.84.0: Bilateral diplomacy foundation implemented but opt-in only: authoritative independent pair rules, reciprocal offers, 100-year truce, permissions, relationship-aware combat bucket/explicit focus/AI hostility/blockade checks. Validate regression fixtures and migrate remaining ownership/team consumers (civilian threat/route/repair/trade, fog, lobby, victory, UI, RPCs and replication) before activating ordinary neutral matches. No free allied material transfer. Preserve legacy behavior until end-to-end authority checks pass.

- [ ] v0.83.0: Validate conquest elimination only after all owned stations and ships are gone; preserve surviving fleets, AI and commands, including stationless last hulls. Regression fixture covers fighter/miner survival and last-hull defeat. Verify slash commands in shared chat in editor/debug builds; developer commands absent in release, `/devmode` reveals speed controls only inside console, host-only simulation commands (including direct guest RPC rejection), no chat/hotkey conflict or duplicate audio bindings. v0.89.22 fixes lazy-dialog nil access and repeated signal connections; runtime pending. Add scenario trigger once Revelation framework exists. Runtime and peer validation pending.

- [ ] v0.82.2 / v0.89.34: Verify station bottom row remains Select Shipyards (Z), Build (B), Trade (T), empty before and after Dyson unlock; check single/grouped station selection, disabled Select Shipyards and unchanged hotkeys/Return slots.

- [ ] v0.91.7: Discovered systems and fields remain selectable and render dimmed last-observed infrastructure, orbital positions and asteroid inventories when outside live vision; inspectors use cached data without additional labels. No hidden ship ghosts or live production/weapon effects; remembered neutral systems expose Send Colony using last-known eligibility and existing authoritative dispatch. Cache is client-only, clears on map/viewer change, no wire fields. Validate scout reveal/loss, hidden construction/mining/depletion, neutral colonize, re-reveal, selection, fog/minimap and peer rendering. Runtime and visual checks pending.
- [ ] v0.91.6: Colony ships recruit 25k crew and require 50k originating residents to enqueue and begin recruitment. Started construction can continue below 50k with sufficient remaining crew and yard operating reserve. Applies to player, AI, repeat orders and UI. Settlement transfers actual crew exactly, including planetless systems, with no free extra residents at founding. Regression fixtures updated; runtime and ENet pending.
- [ ] v0.82.0: Validate mutually exclusive Scout Explore/Wander toggles (v0.82.1), route choice, manual interruption, multiple scouts, cooldown and peer ownership; doubled crew allocation, colony affordability and founding populations, AI pacing. Runtime pending.

- [ ] v0.81.0: Validate invulnerable PDS fire and loss on station destruction; Dyson unlock eligibility, queue/cancel, affordability, all ship discounts and station loss, UI art and peer synchronization. Runtime pending.

- [ ] v0.80.4: Verify manual movement, patrol, follow, formations, combat pursuit and civilian service routes stay in sectors/highways; investigate avoidance crossing boundaries. Verify lifetime CP persists through purchases and replicates to guests. Runtime pending.

- [ ] v0.80.3: Verify fog topology outlines, hidden contents and ownership tint, allied-only logistics, Scout sight and overlay layering at all zooms. Runtime/visual pending.

- [ ] v0.80.2: Verify fog exterior at extreme zoom/pan, smooth mask edges, minimap crop and finer-grid CPU cost at 10k hulls. Runtime pending.

- [ ] v0.80.1: Verify thinner shield glow preserves team colors across zoom levels while remaining visible.

- [ ] v0.80.0: Complete fog of war: authority-side sight and target validation, remembered structures/ownership and resource state, fog-safe inspectors/effects, AI visibility, per-team filtered snapshots and reentry baselines. Validate initial client overlay and team sight on real peers, profile 10k ships and compare FPS/network bandwidth. Runtime pending.

- [ ] v0.79.3: Playtest Crystal income and affordability (1.25 station, 0.06 Incubator, 4× recipes); verify AI, construction premiums and peer economy. Updated economy assertions; runtime pending.

- [ ] v0.79.2: Verify menu navigation and automatic music playback without the standalone toggle; shared settings remain honored.

- [ ] v0.79.1: Verify menu soundtrack audible at default volume, saved mute/zero volume and recovery via match audio settings, navigation and match return. Listening/runtime pending.

- [ ] v0.79.0: Audition layered SFX and original menu loop; assess startup synthesis cost, clipping, loop seam, mute/volume persistence, menu navigation and return from match. Runtime/audio pending.

- [ ] v0.78.6: Verify halved station/yard hull durability and station shield capacity, reinforced plating, 5%/s shield recharge, structure destruction and host/guest combat replication. Runtime pending.

- [ ] v0.78.5: Verify labeled fleet slider ticks, intermediate integer dragging and persisted targets with host/guest, narrow windows and endpoints. Integer round-trip and authority fixtures added; runtime/visual pending.

- [ ] v0.78.4: Verify completed goal stays until all category CP is allocated, no immediate reroll completion, skipped lifetime tiers, independent categories, host/guest synchronization and mixed combat/civilian box selection (including Shift). Economy regression extended; runtime/manual pending.

- [ ] v0.78.3: Verify eight-player lifetime CP scoreboard readability, updates after earning/spending, independent inline +/− collapse/expand for objectives and scoreboard (v0.89.41; scoreboard collapsed initially) at different resolutions and through Tech unlock, local-only conquest notifications and fanfares, host/guest public balances, no private draft leaks. Runtime/visual checks pending.

- [ ] v0.78.2: Manually verify the first F4 opening after match start matches subsequent openings, including small windows, unlocked ship types, scroll and Close/Esc. Runtime/visual pending.

- [ ] v0.78.0–0.78.1: Validate three-choice reward drafts after all one-time rewards, repeated ranks and real effects, peer synchronization, endless objective tiers and reward pacing. Manually verify no scrolling/clipping at supported window sizes, especially lengthy shield/cloak descriptions. Runtime/visual validation pending.

- [ ] v0.77.3: Audition personal objective / first-place fanfares and silence for other players; verify simultaneous events, no replay on snapshots, SFX mute and voice priority in crowded matches. Runtime/audio pending.

- [ ] v0.77.2: Playtest ship-ready and tactical warning sounds, off-camera allied hull damage/instant loss, approaching combat counts and click-to-center on host/guest; check dense fleets, narrow HUD, cooldowns and cloak visibility. Verify hull glow aligns at tactical/overview zoom and selection rings remain distinct.

- [ ] v0.77.1: Verify Godot startup after Crystal dictionary parse fix, and match notification alignment, player-colored names, wrapping, fade and chat replication on real peers.

- [ ] **Replace prototype sound effects with authored audio later (v0.77.0).** Supply normalized WAVs in assets/sfx for laser, blaster, missile, explosion, heavy_explosion, mining, repair, tractor, select, click, order, queue, complete, ship_ready, warning, notice, objective_complete and objective_first. Keep the cue mixer and attenuation/polyphony; audition at 1× and crowded 5×, check host/guest, music balance, mute, camera movement and sustained combat. Runtime/audio validation pending.

- [ ] v0.76.0: Playtest station baseline, 0.04 Incubator rate and fivefold Crystal prices, especially expensive Laser Matrix/third yard storage requirements and AI sourcing. Verify actual two-/three-peer chat delivery, sender validation, rate limit, typing focus, wrapping, pause/fade and restart. Runtime and visual checks pending.

- [ ] v0.75.3: Verify immediate Harvester reassignment after final freighter transfer, including manual movement, partial deliveries, conservation and remote snapshots; verify available Upgrade pulse and independent damaged-only world bars/selection shield meters. Runtime and visual checks pending.

- [ ] v0.70.6: Visually verify centered single-selection portraits and HP captions for ships, stations, shipyards and planets at varied window sizes.

- [ ] v0.70.3: Verify immediate full infrastructure cancellation refunds, ship-only cancellation salvage, and ENet replication.

- [ ] v0.70.1: Verify grouped station construction allows any eligible station and resolves housing per destination; test mixed levels, ownership, resources and ENet.

- [ ] v0.66.4: Playtest tenfold lower incubator base production, crystal scarcity and AI access to advanced construction.

- [ ] v0.66.1: Verify direct local asteroid access rather than detouring through an alternate anchor, including multi-access field regression and physical delivery.

### Objectives and specialization (v0.75.0)
- [ ] v0.75.2: Compare actual time-to-completion for starter objectives at 1× across map seeds and strategies (80k population, 3kt Metals, two colony ships, 1kt colony food, military builds/kills); tune if outliers remain. Verify tier progression and boundaries; no starter target satisfied by initial stock.
- [ ] Validate one active Economic/Military goal each, Tech unlock, colony construction before colonization, lifetime colony food after loss/conversion, military construction/kill credit, random eligible refresh with independent 60 s cooldown, same-tick ties, top-center fading notices and header-height square refresh/Upgrade buttons with inline CP balance (v0.75.1). Economy and real-peer refresh fixtures added; runtime pending.
- [ ] Validate unique reward race, permanent first-player reservation, no charge on rejected claim, replacement drafts and purple labels. Two-/three-peer ENet race fixture added; runtime pending. Verify fixed conquest modal parser and layout.
- [ ] Validate categorized CP payouts (exactly 1 for every completion, including first, simultaneous and later finishers; v0.89.63), 10-second objective transitions, current stock/cargo and resident/crew accounting, category pools and compact counters in solo/ENet.
- [ ] Validate compact choice modal, immediate close at zero CP, category-specific + general random draft, stale/wrong-category rejection, shared reward invalidation, AI selection and exhausted pools. Private drafts implemented in v0.73.0; unique unlock announcements added in v0.74.0. Verify peer privacy and announcements.
- [ ] Validate Empire F4 autoqueue, 500 target cap, eligibility filters, mixed yard levels, affordability, manual/repeat interaction and replication.
- [ ] Validate Shields 1–3 and armor damage, recharge, costs/refunds, AI construction, selection/world health indicators and peer replication; provisional values. Mixed-selection shield bars and world rings implemented in v0.73.0; improve SVG-matching shield glow if needed.
- [ ] v0.73.0: Validate Scout-only cloaking, 250-unit detection and 5 s reveal on fire, no shield/armor stacking, Crystal cost, explicit/automatic target checks, minimap/picking and replication. Full hull state remains on peers; adversarial packet privacy and AI/influence behavior remain pending.
- [ ] v0.72.0: Validate Tech Warp Gates: loaded science vessel conversion in owned sectors, one gate per system, stable links, approach/teleport, cooldown, destruction, costs, selection/map art and real two-/three-peer ENet. Add AI deployment/transit and dedicated peer regression.
- [ ] Expand category-specific and shared reward pools, particularly Tech and Military; keep drawbacks optional and thematic.
- [ ] Science objectives, antimatter uses and victory condition; retain physical cargo.
- [ ] Carrier: large expensive hull with 1,000 t storage, fighter/scout production commands using its cargo, repair beams and lasers, distinctive central shipyard art. Integrate AI, costs, population, salvage and peer tests; no drones or additional mechanics without agreement.
- [ ] Verify v0.66.4 crystal production scarcity, logistics lens and inherent grades; validate objective modal and station side-by-side resources/queue at constrained sizes.

### Large-fleet scalability — approved engineering program (v0.62.1; T-026)

See the [consolidated optimization program above](#optimization--active-engineering-program-reconciled-2026-11-25-v09792). The original eight-phase plan and P0–P4 slices are preserved in the [optimization roadmap history](THOUGHTS_ARCHIVE.md#optimization-roadmap-history-through-v09791).

### Existing RTS implementation and validation backlog

- [ ] v0.64.63: Playtest lower habitation capacity, cubic occupancy penalty and sustainable population bar; verify food shortages, housing upgrades, late-game crew supply and AI growth.

- [ ] v0.64.62: Playtest global selection buttons and remappable F1/F2/F3 shortcuts, grouped commands, ownership, narrow window and UI scaling.

- [ ] v0.64.61: Verify mixed-building Shift-selection and Tab cycling, grouped station operation dispatch, destruction pruning, and separate ship selection. Extend mixed building highlights, complete group control recall and aggregate availability/trade semantics.

- [ ] v0.64.60: Playtest mixed-team and enemy-only drag selection, Shift-add after enemy inspection, allied selection and unchanged command ownership.

- [ ] v0.64.59: Verify mixed-type move clicks, minimap and drag formations affect all owned selected hulls while specialized commands remain focused; inspect GPU selection rings and health overlays beneath the HUD at all UI scales.

- [ ] v0.64.7: Playtest F and group recall focus with compact fleets, isolated stragglers, split fleets and casualties; preserve zoom and building focus.

- [ ] v0.64.3: Verify upgrade badges initialize without missing-metadata errors; repeat profiler capture before geometry caching.

- [ ] v0.64.2: Playtest Tab/Shift+Tab mixed hull cards, type-scoped commands and formation, selection changes, foreign hulls and guest command ownership.

- [ ] v0.63.1: Inspect closed region contours at sector mouths, highway crossings/sections, small fields, map edges and all zoom levels; compare influence boundaries to commands and profile shader cost. Preserve this appearance in scalability phase 5 cached geometry.

- [ ] v0.63.0: Validate one-hop adjacent influence, threshold, proportional blends, fog boundaries and long highway seams; retain adjacency in scalability phase 5 incremental totals.

- [ ] v0.62.3: Playtest shipyard rows before/during/after upgrades, mixed-level selections, hotkeys and locked class visibility on host/guest.

- [ ] v0.62.2: Verify highway influence section boundaries, exact cap, independent color transfer, direct travel across seams and minimap/peer parity. Include section geometry in scalability phase 5.

- [ ] v0.62.0: Validate influence membership and mixed colors, highway traversal/intersections, infrastructure destruction, minimap, fog visibility, rendering cost and peer parity.

- [ ] v0.61.3: Playtest persistent drag ghosts, reselection, queues, combat/repair interruptions, patrol reversals, cancellation, arrival and large fleets on host/guest.

- [ ] v0.61.2: Inspect soft corridor rims and rounded junctions at all zooms; check connection readability without static tactical centerlines.

- [ ] v0.61.1: Playtest bounded sector selection, object priority, friendly stations, exact star/near-star click and drag orders, minimap and colony commands.

- [ ] v0.61.0: Validate corridor geometry, command bounds, bidirectional/interior movement, remote routing, patrol, guard, queues, formations and peer parity. Inspect performance and field intersections.

- [ ] v0.60.1: Validate Scout combat pursuit, guard/patrol, field routing, fleet allocation, retreat and peer parity.

- [ ] v0.60.0: Validate gap outlines/map edges, performance, retreat default-off, opt-in thresholds, cancellation and peer toggle parity.

- [ ] v0.59.1: Validate hull and structure HP, plating damage preservation, repair/withdrawal timing, peer health replication and neutral sector borders at all zooms; profile expanded shader coverage.

- [ ] v0.59.0: Validate blaster cadence, target and ally filtering, scout movement, capital simultaneous weapons, conquest pacing, effects and multiplayer damage/trace parity.

- [ ] v0.58.10: Inspect capital silhouettes at all zooms, portrait fitting, selection rings, weapon origins, shipyard construction and crowded fleet readability.

- [ ] v0.58.9: Validate AI capital resource/crew progression, mixed military fleets, bounded remote salvage and delivery return, and automatic human colony conversion with host/guest parity.

- [ ] v0.58.8: Validate exact Hold poses, queued Hold, crowded fleets, repair detours and guest replication; inspect resource planet palettes at all zooms.

- [ ] v0.58.7: Validate nearest-idle Colony dispatch and Shift Stop/Hold/Deliver/Transform, including queue activation, cancellation and guest commands.

- [ ] v0.58.6: Inspect acceleration exhaust on starts, turns, steady cruise, stopping, docking, idle formations, pause/speed changes and guest interpolation at different zooms.

- [ ] v0.58.5: Inspect station Select Shipyards with zero/one/multiple completed yards, Build Shipyard costs, queued slots, max capacity, and grouped commands on host and guest.

- [ ] v0.58.4: Validate doubled repair throughput, stationary idle recipients, resumption after beam interruption/full HP, explicit orders and multiplayer parity.

- [ ] v0.58.3: Validate gap moves and formations for all hulls, queued movement, return to sectors, repair, map bounds and host/guest parity.

- [ ] v0.58.2: Validate salvage-first targeting with both toggles, local mining-route interruption, field detours, safe return to mining and host/guest parity.

- [ ] v0.58.1: Inspect shared group command lines for mixed orders, sector entry, same-point moves, follow/attack, patrol and peer motion interpolation.

- [ ] v0.58.0: Validate planetary upgrade delivery timing, target, cancellation, concurrent station fabrication, peer replication and close-zoom art.

- [ ] v0.57.2: Inspect quarter-size planetary cargo capsules and paired side jets at close zoom.

- [ ] v0.57.1: Benchmark large fleets, inspect cached hull parity and edge culling, single-ship command lines and team double-click selection.

- [ ] v0.57.0: Validate capital hull HP, no cargo, missile cooldown/range/focus/teams, laser volleys, costs and peer visuals.

- [ ] v0.56.12: Verify population bar against summed habitation and orbital capacity, upgrades and new colonies.

- [ ] v0.56.11: Inspect cargo rocket art and blockade visibility, neutral-sector command card and separate station/yard jobs.

- [ ] v0.56.10: Verify live planetary production details match particles, including undefended planets, blockade and multiple matching bodies.

- [ ] v0.56.8: Verify one command tooltip, fast delay, cost/crew rows, hover transitions and ordinary native tooltips.

- [ ] v0.56.7: Validate production blockade and resumption, friendly presence, orbital output, particle origins and peer synchronization.

- [ ] v0.56.6: Check routed command lines, queued connectors, escort/rally and multi-selection on host and guest.

- [ ] v0.56.5: Validate interrupted automatic/manual deliveries, partial handoff, empty order cancellation and peer replication.

- [ ] v0.56.4: Verify yard upgrade icon and progress at each berth, concurrent station jobs and unchanged ship construction visuals.

- [ ] v0.56.3: Inspect three new hulls, portraits, breakup, targeting and construction ghosts across zoom levels.

- [ ] v0.56.2: Verify overlapping field/star and hull/star clicks at all zooms, unchanged orders and selected yard rally flags.

- [ ] v0.56.1: Verify command-only tooltip timing, recipe display, level badges, target levels and renamed cards at all UI scales.

- [ ] v0.56.0: Validate Scout/Cruiser/Destroyer construction, movement, combat, withdrawal, commands, artwork and peer replication; runtime pending.

- [ ] v0.55.11: Validate starting/converted station HP, baseline and upgraded laser fire, cooldown, friendly exclusion and peer rendering. Runtime pending.

- [ ] v0.55.10: Validate eight-year inactivity timeout refreshed by every handoff and salvage pickup, depleted-site fallback and departure at capacity. Runtime pending.

- [ ] v0.55.8: Validate station repair standoff, safe withdrawal, crowded approaches, twin beams and peer rendering. Runtime pending.

- [ ] v0.55.7: Verify shipyard class rows, sequential upgrade buttons and mixed-yard selection, costs and shortcuts in game. Visual validation pending.

- [ ] v0.55.6: Validate Stop versus Hold, cancellation in transit, ownership and real peer Stop; inspect station hub progress with concurrent production and different zoom levels. Runtime pending.

- [ ] v0.55.5: Verify lifetime counters and lethal-hit attribution, default groups, manual Colony conversion and AI expansion, doubled transfer ranges and peer replication. Runtime pending.

- [ ] v0.55.3: Validate current command borders, mixed selections, moving escort, lane passing fire, gap targeting, freighter HP/repair and capped regeneration on host and guest. Runtime pending.

- [ ] v0.55.1: Validate station storage art and ship/ship and station/ship transfer particles on host and guest; profile busy hubs. Runtime pending.

- [ ] v0.55.0: Validate size-gated manual/repeat/AI builds, unchanged starting fleet, upgraded-yard fixtures and peer replication. Runtime pending.

- [ ] v0.54.3: Validate local avoidance across opposing lanes, formations, mining and crowded docks; profile dense fleets on host, verify guest motion and cargo conservation with new extraction/dropoff rates. Runtime pending.

- [ ] v0.54.1: Verify damaged-unit bars at all zooms, queued dock spacing and cargo conservation, guard arrival/engagement/return and cancellation, Pulsar lane travel and peer replication. Runtime pending.

- [ ] v0.54.0: Verify renamed hulls, crew details without world labels, Collect Antimatter targeting and default-off autocast; validate manual/automatic cancellation, ownership and peer replication. Runtime pending.

- [ ] v0.53.7: Verify passing miner handoff between sectors, manual movement, hold, trade toggle, capacity and same-tick station unloading conservation; verify fighter combat interrupts and resumes movement. Runtime pending.

- [ ] v0.53.6: Validate rate-limited mining, trade, handoff, farm and manual deliveries, cargo conservation, full warehouses, pause and peer replication; verify sector pursuit, hold, move-only and withdrawal. Runtime pending.

- [ ] v0.53.5: Verify full-height map and header input, crew label, permissive contact in dense fleets, class speed and ETA, depot-facing staging and miner handoffs, economy and peer synchronization. Runtime pending.

- [ ] v0.53.4: Visually verify smooth orbit motion, pause and speed changes, PDS targeting/repair and camera tracking on host and guest; check exhaust scaling across ship classes and acceleration. Runtime pending.

- [ ] v0.53.3: Verify crowded docking, leftover trade cargo, partial and full warehouse retry, distinct crew totals, 10-bay freighter art, transparent top HUD, hidden zero rates and two-/three-peer docking regressions. Runtime pending.

- [ ] v0.53.2: Visually verify 12× ship overview scaling, ship selection and beam alignment, preserved structure scale and smooth transition to tactical art. Runtime pending.

- [ ] v0.53.1: Verify cooldown seconds at all speeds, shipyard ghost and port alignment, cancellation conservation/authority for queued and active hulls/buildings and upgrades, persistent salvage recovery and peer replication. Runtime and visual validation pending.

- [ ] v0.53.0: Validate colony farming, 100 t cap, hold/colonization precedence, full-depot fallback, manual delivery, mixed command cards, two-/three-peer farm toggle and cargo replication. Runtime pending.

- [ ] v0.52.0: Validate science vessel build, travel, authority, interruption, 30-year collection and cargo persistence; inspect Pulsar art and animated containment, compact HUD and overlay on peers. Antimatter uses deferred; prototype costs subject to balance. Runtime pending.

- [ ] v0.51.10: Verify spaced starter/yard launches, independent converging movement, mixed owners, dense fleets, dock/repair/hand-off contact stability, sector boundaries, snapshot interpolation and eight-player cost. Economy assertions added; runtime and peer testing pending.

- [ ] v0.51.9: Validate 10 t mining and 100 t hauling, repeated handoff, full and partial dispatch, conservation, 100 t salvage staging threshold, cargo art and two-/three-peer replication. Economy and peer fixtures revised; runtime pending.

- [ ] v0.51.8: Verify PDS repair approach/range, exact battery HP, manual and automatic repair, orbit alignment, pause and peer rendering; monitor orbit smoothness on guests. Economy assertions added; runtime pending.

- [ ] v0.51.7: Playtest Trade checkbox labels, insets, slider/checkbox interaction, standard-height panel and bounded expansion/scroll at small windows and UI scales; verify Return and normal wing restoration. Runtime and visual checks pending.

- [ ] v0.51.6: Validate default 50/80 trade thresholds at initialization and station reset, exact boundary behavior, player overrides, AI pacing, and top HUD net t/yr readability at narrow UI widths. Economy assertions added; runtime pending.

- [ ] v0.51.5: Validate full depot fallback for resource and trade freighters, cargo conservation, resumed delivery, lost stations, single-unit order lines and solo/peer rendering; runtime and visual checks pending.

- [ ] v0.51.4: Verify zero repair and five-year mine/salvage cooldowns after manual orders/arrival, independent 30-year Wander/Trade, radial overlay timing, pause/game speed, and authoritative peer state. Regression timing assertions updated; execution pending.

- [ ] v0.51.3: Verify six starting hulls (three miners, two fighters, one logistics ship) per human and AI in solo and real peer matches. Confirm normal construction progress tests distinguish newly built freighters from starter ships.

- [ ] v0.51.2: Validate friendly follow, moving/stationary target, lane and field transitions, groups, target destruction, ownership/cycles, Hold/new commands and queued successors. Economy and peer assertions added; parse, solo, visual and real peer execution pending.

- [ ] v0.51.1: Playtest cargo/salvage glow at overview and close zoom, clarity of resource colors and empty bays, no asteroid glow, field card toggles and hotkeys (ordinary/antimatter), selection transitions and peer policy replication; parse/startup and visual checks pending.

- [ ] v0.51.0: Validate idle logistics staging, mining/salvage transfers, full and partial departures, storage-full fallback, ownership/capacity conservation, hostile routes, explicit order cancellation and Auto-Trade/Auto-Salvage independence in solo and real peer matches; regression fixtures added, runtime execution pending.

- [ ] v0.50.3: Validate immediate Wander activation during cooldown, new-order reset, other modes retaining cooldown, Hold/queued order precedence, mixed-selection mode layout and both mouse buttons; economy and peer smoke assertions updated, execution pending.

- [ ] v0.50.2: Inspect star surface, glow and spark subtlety at overview, intermediate and deep zoom; verify warm/cool distinction, camera/selection and orbital layers, and profile large maps. Confirm autocast enabled borders animate without missing repair metadata errors. Parse, solo and peer startup pending.

- [ ] v0.50.1: Playtest zoom visibility at minimum, intermediate and tactical zoom on small/large maps; check station/yard overlap, ship selection, selection rings, weapon origins, ghost previews, and normal close-up framing. Solo/peer startup and parse checks pending.

- [ ] v0.50.0: Playtest independent autocast flags, mixed selections, either click and hotkeys, 30-year cooldown and clock animation, queued/manual work while disabled, cargo delivery, combat/withdrawal, and solo/guest replication; run economy and two-/three-peer ENet smoke tests.

- [ ] v0.49.2: Verify half-sized queue tiles, sector outlines, star click/drag and minimap targeting, Alt precise moves, border routing across multiple lanes for all ship kinds, queued entry, combat and arrival wait; run economy and real two-/three-peer smoke tests.

- [ ] v0.49.1: Validate local/remote move and formation arrival waits, sector movement, immediate queued successor and Hold override, civilian resumption, combat/withdrawal, pause and speed scaling, guest snapshot status and two-/three-peer movement replication. Regression assertions added to existing economy tests; run before marking done.

- [ ] v0.49.0: Verify local camera speed sliders, disabled zero-speed panning, simultaneous input, wheel zoom; edit/reset hotkeys, conflict rejection, badge/tooltip updates, persistence after restart, nested modal isolation, Codex compact header at small/large windows and solo/peer startup.

- [ ] v0.48.0: Playtest Standard-style contextual shortcuts and badges for all card pages, unavailable/foreign commands, left/right targeting and formation drag, minimap, Escape, group add/replace/recall and modal/input isolation in solo and peer matches. Q/E no longer cycle stations. Confirm no duplicate action per keypress.

- [ ] v0.47.1: Inspect the refreshed tactical, station, shipyard and queue icons at native 1152×648 and larger sizes, including disabled/pressed states, repeat borders, owner-colored hulls and resource-specific building recognition. Verify unchanged commands and solo/peer startup.

- [ ] v0.47.0: Playtest four-row shipyard commands at supported sizes, Select Space Station from single/grouped yards, rally/clear and unchanged queues; verify arrows, edge pan, middle drag, focus loss/reentry, modal dialogs and match exit in solo and multiplayer windows.

- [ ] v0.46.2: Verify bounded Codex at small and large windows, article wheel and scrollbar drag to final content, fixed sidebar/header, search, Escape/Close and passive chart/table/diagram styling. Confirm match input isolation and uninterrupted simulation.

- [ ] v0.46.0: Visually verify Codex at supported resolutions, search/navigation, scroll, Escape/Close, charts and tables, no leaked map/keyboard orders, and uninterrupted solo/host/guest simulation. Check startup, script parsing and peer smoke tests. Keep reference articles synchronized with authoritative mechanics.

- [ ] v0.45.3: Validate 60-year max doubling, 0/25/50/75/100% local food reserve multipliers, warehouse and orbital independence, food shortage decline, population hover, AI opening pacing and two-/three-peer economy replication. The provisional fixed full-growth reserve is 200 t; starting food remains 300 t, existing crew costs and timings unchanged. Existing opening-pacing targets may need reconsideration after measuring the slower economy; do not relax them without evidence.

- [ ] v0.45.2: Playtest the bottom-aligned Shipyard Return footer from single and grouped shipyard selections; verify it restores the parent system overview without changing production queues, upgrades, or rally state.

- [ ] v0.45.0: Validate three-resource economy, basic construction without Crystals, advanced crystal gates, removal of legacy stock/thresholds/recipes, local recovery and AI opening pacing, physical mixed cargo and raw antimatter deposits, refunds, HUD and four-row grids, and two-/three-peer ENet replication. Tune costs only after playtesting.

- [ ] v0.44.2: Verify exact reconstruction of stable planet attributes from the initial host template, full-live fallback if attributes change, omission of host-only AI scheduling/ID counters, and 20-byte pose records (32-bit position coordinates retained; half-float visual heading). Run normal two-/three-peer ENet, test recovery/restart, compare compressed sizes and heading error, then measure actual traffic. No gameplay or simulation changes.

- [ ] v0.44.1: Validate first reliable state installs the host's immutable map template; subsequent independent snapshots contain only ore changes from that template and reconstruct depleted/partially mined rocks exactly. Check compact snapshot size, 10 Hz changed-only pose updates with 1 Hz full refresh, first match and restart, topology fallback and actual two-/three-peer ENet. Run existing normal network smoke mode (no human partner needed). Full economy deltas remain deferred until validation.

- [ ] v0.44.0: Validate guest movement stream at 10 Hz, reliable state at 2 Hz during steady play plus urgent accepted commands, existing authority, pause/resume, destruction, lobby restart, and two-/three-peer ENet regression. Compare RTT, reliable loss, receive cadence, local packet age, decode/encode time and aggregate/per-guest throughput under real internet and impaired links. Follow with baseline-acknowledged deltas/static-map separation, timestamped interpolation buffer and bounded extrapolation, then profile the host simulation hotspots. Do not assume performance targets are met until measured.

- [ ] Playtest v0.43.8 larger production queue icons, progress bars and cancellation, including wrapped queues and scroll access in small middle panels.

- [ ] Playtest v0.43.7 compact station resource table, local hover boundaries and narrow-window resizing without affecting queue centering.

- [ ] Playtest v0.43.6 centered station and shipyard queue tiles, including single orders, wrapping, resizing and switching station tabs.

- [ ] Playtest v0.43.5 shared command slot alignment at different window sizes, resource readability and per-resource cost shortage colors, looping match music and mute/volume settings, and safe mining-to-salvage detours without cargo on fighters.

- [ ] Playtest v0.43.4 single-lane station construction across infrastructure and upgrades, cancellation/repeat, independent shipyard work, PDS range and planet detail cleanup; check Trade checkbox contrast and scroll reach at small window sizes.

- [ ] Playtest v0.43.3 world-center camera and F2 double recall at all zooms/resolutions; local movement onto rendered PDS planets, station side-by-side resources and queue visibility and hover, command-card row placement and concise upgrade/weapon tooltips.

- [ ] Playtest v0.43.2 translucent territory, four-row station Build card, single-ship facing drag at different zooms and population-blocked shipyard orders yielding to eligible hulls and resuming on recovery.

- [ ] Playtest v0.43.1 metal-rich long-lived asteroid inventories and longer salvage expiry, Trade-only doubled right wing at various window heights and fighter/miner/mixed command availability.

- [ ] Playtest v0.43.0 safe civilian salvage search and delivery, retreat/claim release when enemies arrive; minimap right-click movement, attack, mining, repair, rally and Shift queue at all camera zooms; F2 owned fighter selection without camera movement.

- [ ] Playtest v0.42.2 native 100% UI and crisp tooltip text/icon rendering across actual window resolutions and OS DPI settings; verify new resource building names in build card and queue. Prior UI-scale acceptance items now mean window-size checks at fixed 100%.

- [ ] Playtest v0.42.1 F and double control-group centering at overview/close-up zoom and different window scales; check opaque recipe hover cards, icons, crew, disabled commands and tooltip placement near screen edges.

- [ ] Playtest v0.42.0 timed warehouse/habitation/orbital housing upgrades, queue progress/refunds and AI orbital construction; verify concise resource tooltips, health-colored grouped building tiles, top-left control groups and relation-colored selected-ship target circles at all zoom levels.

- [ ] Playtest v0.41.0 station command card's three numbered shipyard ports, build/select/pending states, one-time Reinforced Plating and Laser Matrix, weapon details for single armed entities, dual defensive beam visuals and provisional upgrade costs. Check rebuilding a destroyed middle port without moving its neighbors.

- [ ] Playtest v0.40.0 station command subcards at varied window sizes: Build/Trade/Return placement, cost/effect tooltips, repeat borders, sequential infrastructure queue tiles (v0.43.4), clicking to refund, persistent resources beside the station queue, trade sliders, and station-anchored logistics lens. Verify F/portrait follow never snaps zoom, even for dispersed fleets.

- [ ] Playtest v0.39.0: station-first selection and neutral-only sector rings, generic field names, full minimap view bounds, map interaction through empty panels, Escape menu toggle, double control-group recall without tracking, shared guest time controls, crowded rally release and red rally/selected purple patrol routes.

- [x] Host-authoritative solo/multiplayer, flexible teams, up to eight players, lobby chat, selectable empire colors, seeded maps and AI slots.
- [x] Physical navigation, construction, local trade thresholds, finite extraction, autonomous miners/freighters, repeat and maintain orders.
- [x] Starting three miners, two fighters, one logistics ship, one planetary defense per home; physical cargo bays, repair and combat, destructible shipyards and planetary defenses.
- [x] Territory visualization, colonization, hostile occupation, elimination/recovery and conquest victory prototype.
- [x] Implement hold-position orders (including mid-lane), Ctrl+1–9 control groups, Shift-click toggles, selection summaries and selected route feedback in v0.19.0.
- [ ] Manually validate direct selection and orders: click, drag-select, Shift add/toggle, group recall, hold, right-click a discovered sector, mid-leg retarget, automatic combat, repairs and rejoining. Keep lane navigation and authoritative positions; check selection responsiveness and visual feedback. Freighters remain autonomous; colony ships use direct settlement orders. Verify mixed selections and miner field/rock assignments, cancellation, physical delivery, depletion fallback and multiplayer replication (v0.20.0).
- [ ] Validate upfront local material payment for every construction/upgrade, atomic rejection, full refunds, repeat/maintain waiting, shipyard repricing and HUD affordability (v0.20.0). Review storage capacity versus high-level upgrade costs.
- [ ] Playtest combat group formation, targeting, arrival/capture, patrol boundaries and AI defense/attack. Evaluate explicit hostile-target orders after basic movement and hold feel good; do not require policy allocation or mandatory human rally.
- [x] Explicit hostile-ship focus targeting, automatic attack-move via POI orders, repeated two-POI patrol, tactical cancellation/repair priority, selected order feedback and AI lane-distance/ready-hull defense improvements (v0.27.0). Regression tests cover ownership, enemy team, focus priority, loss/cancellation, bounded patrol, repair-aware AI and actual peer replication.
- [x] Reproducible 15-minute contested AI benchmark for Radial/Grid 1v1 and Hex Grid 4-player, including economic expansion, combat losses, stock/cargo and fleet-size reporting (v0.27.0).
- [ ] Manual acceptance pass: verify hostile ship right-click versus salvage/POI, Patrol card, same-sector tracking, mixed foreign/owned selections, target loss, repair and group travel at useful zooms. Review ongoing gameplay balance after actual human contested matches; treat automated simulation as evidence, not a replacement.
- [x] Per-hull Shift order queue (30 total), direct/hold cancellation, FIFO execution and destination chaining, attack/move colors, dotted selection outlines, and right-drag formation placement/ghost previews (v0.33.0).
- [ ] v0.91.5: Use one dashed command-line style for active single/group routes, patrol, follow, rally, formation preview and queued legs. Preserve command-specific tint, active/queued opacity, numbers, ghosts and target rings. Keep weapon effects, physical warp links and flag artwork unchanged. Visual verification pending.
- [ ] v0.91.3: Display the complete selected local ship/fleet Shift-order queue on a mouse-transparent overlay above fog and below the HUD. Draw shared active intent and numbered dashed legs, aggregate identical legs, retain distinct formation destinations/ghosts and label nonspatial or hidden/lost-target commands without inventing a destination. No changes to authority or network schema. Verify fast Shift queueing, mixed and divergent fleets, formation slots, fog, target loss, command completion, zoom and large fleets; runtime/visual/ENet pending.
- [ ] Playtest chained order visibility at zoom levels, fast Shift clicking and attack-target loss, command-card modes, mixed civilian/fighter formations, invalid sector slots, line spacing and final facing, and right-drag cancellation over the console (v0.33.0).
- [x] Compact clickable production queue tiles with inline active progress and responsive wrapping; time controls directly above minimap (v0.33.1).
- [x] Space Station ownership anchor with attached production modules, neutralization and recolonization, 20% storage salvage, physical docking, and consistent move-only right-click (v0.34.0).
- [x] Direct field-to-field navigation, radial antimatter corridor, precise arbitrary-point fighter patrol, command icons/opaque tooltips, modifier-based selection filtering, and compact aggregate cargo (v0.35.0).
- [ ] Validate v0.36.0 station-first delivery/repair approaches, half-size shipyards with two 20% size upgrades, eight-item per-shipyard queues and right-click round-robin autobuild, persistent destination ghost hulls, and move/attack/patrol placement along curved right-drag strokes. Verify pulsing border, queue cancellation, and ghosts in actual play.
- [ ] Visually verify compact v0.36.1 fixed four-column shipyard card at narrow and wide console sizes; command mode stays clear via button highlights and cursor without extra text.
- [ ] Visually verify v0.36.2 single-selection health wireframes for all hulls, shipyards, space stations and defended/undefended planets across UI scales; verify home-sector starting camera on each map layout and client.
- [ ] Playtest right-button formation placement for armed Move, Attack and Patrol (v0.37.0 supersedes both-button placement), including Shift queueing, Escape, click fallback, and unarmed selection.
- [ ] Playtest v0.36.4 formation arrival into normal wandering/work, progressive wheel zoom at overview and close range, and shared icon-only cargo display for empty and loaded single ships.
- [ ] Playtest v0.36.5 control-group strip, Ctrl+0–9 assignments, recalls and compatible Shift additions; verify foreign/dead removal, structure slot invalidation, cargo footer and station Economy construction/cancellation at narrow UI scales.
- [ ] Playtest v0.37.0 weak miner self-defense, paired laser visuals, extraction interruption/resumption and balance; verify right-only movement/attack/patrol placement, left-selection cancellation, dashed rings and planet header alignment.
- [ ] Playtest v0.38.0 miner Repair autocast/priority and beam visuals, loaded miner remote travel, focused hull/structure attacks, manual drop/transfer and station deposit fallback, portrait double-click focus, and continuous star size/opacity. Evaluate provisional repair range/rate and withdrawal balance in contested fields.
- [ ] Playtest radial field links and exact patrol points in same sector, across sectors and in open space, including repair and queue interruption; verify modifier-click selection tiles, opaque tooltips and aggregate cargo layout at narrow UI scales.
- [ ] Playtest station scale, orbital motion, shipyard attachment and selection, explosive breakup, resource collection, station repair/docking, AI station attacks and planetless recolonization; verify ordinary clicks and formation drags versus explicit Attack and rally attack-move.
- [ ] Visually verify queue wrapping, cancellation of active and pending jobs, blocked/offline progress colors and time toolbar fit at narrow window widths.
- [ ] Validate v0.18.0 unified Economy buildings (no individual production upgrade tab): zero-stock recovery, repeated construction, colony economy, industrial capacity, crystal extraction, housing, PDS availability and sensible resource recipes. No production building consumes its own output; provide reliable bootstrapping. Validate storage tiers, reserve production and trade behavior.
- [x] First opening-pacing pass (v0.19.0): lighter colony crew with minimum retained staffing, doubled baseline industry, lower hull food inputs, larger cargo holds, warehouse construction reserve, AI production recovery and logistics before further expansion. Three seeded six-minute economic simulations.
- [ ] Validate spider-web radial outer/inner ring connectivity, spokes, central clearance and small-player-count pacing; compare exact lobby/solo preview with in-match map and test rerolls/roster changes (v0.22.1).
- [ ] Playtest Radial (default), Grid, Hex Grid and Scramble across player counts/seeds, comparing opening access to ordinary mining, lane lengths/choke points and travel to protected antimatter. Validate lobby host-only layout selection, guest readiness reset, and authoritative seed/layout replication (v0.22.0).
- [ ] Validate v0.23.2 combined POI degree cap, nearest feasible field access and hex cluster gaps, including early mining access and protected antimatter across seeds.
- [ ] Playtest v0.23.1 individual-system hex cells and 80/20 clustered/standalone mix across layouts, including opening mining, lane timing, fleet pathing and eight-player performance.
- [ ] Verify unified setup and visible previews across screen sizes; test LAN broadcast, explicitly entered IP discovery, host shutdown/full/start expiration, and direct-IP fallback (v0.23.0). Internet-wide lobby discovery remains deferred until Steam or a directory service.
- [ ] Verify v0.24.1 independent eco population, shipyard completion/loss, crew refunds and regeneration, net Organics, opening pacing, and multiplayer housing totals.
- [ ] Playtest v0.24.0 planetless 50% distribution, fighter capture, orbital housing imports/crew, AI development and reduced planetary expansion supply; validate numerical housing costs and population balance.
- [ ] Balance sustained mid/late match, combat losses, growth, food, overpopulation curve, staffing, warehousing, trade and AI expansion. Stress-test sustained development including bankrupt stockpiles, depleted fields, isolated colonies and lost shipyards.
- [ ] Ensure RTS UX is compact and understandable: map controls, economy/HUD, construction and route feedback, constrained windows, UI scale, audio, and multi-peer interactions. Manual playtesting rather than widget assertions. Verify color-coded theoretical local and empire annual resource deltas against the actual-flow hover, including full/empty storage and compact top-bar layouts (v0.20.2). Verify collapsed construction/upgrade recipes and build durations, including narrow inspectors and upgraded/offline shipyards; verify single-row icon amounts and clock/duration inside action buttons at all UI scales (v0.20.6). Verify planet hit-testing at different zooms, stable names, selection highlighting, PDS construction/cancellation and ownership changes (v0.21.0). Verify system Economy planet selector has complete parity with planet-level defense actions and status; enforce system-first access for all future upgrades (v0.21.1). Verify numerical economy previews against exactly one completed upgrade at fixed population, including first extraction, capped mines, labor caps, food and max tiers (v0.21.2). Verify ship title counts with off/finite/unlimited maintenance and queued construction, including narrow UI (v0.21.3).
- [ ] Verify match lifecycle, hostile civilian rerouting, territory/capture interruption, elimination and conquest result; profile fleet-heavy matches at 5× speed. Run eight-peer stress validation before major releases.
- [ ] Evaluate supply/repair costs, raiding and escort mechanics only if required by the basic RTS loop. Distinct ship classes and additional races remain later scope.

## 2 — Promissory notes

- [ ] Define the smallest useful set of bilateral promises/transactions, independent of policy cards: what is promised, who holds it, how it is fulfilled, and when it expires or is consumed.
- [ ] Decide acceptance, payment, resource transfer, and obligation semantics, including authority validation, ownership, duplicate redemption, and how agreements affect combat and ongoing direct orders.
- [ ] Prototype compact diplomacy UI and host-authoritative replication; test with real multiplayer. Implement the agreed war/peace/truce rules above first; complex treaties and galactic votes remain deferred unless approved for a Revelation.

## 3 — Core match loop

- [ ] Existing finite raw antimatter deposits, extraction and physical delivery (v0.17.33) are a foundation. Define refining/processing, storage, ownership, and the minimal antimatter objective and victory condition.
- [ ] Integrate conquest, industrial development and promissory notes into a complete game. Decide team scoring and end-of-match handling if antimatter victory differs from conquest.
- [ ] Playtest at 1× in 1v1, four-player and larger teams; balance travel, economy, conflict, negotiation and antimatter timing. Measure runaway-leader risk, comeback opportunities and meaningful decisions per minute.
- [ ] Consider activity-driven technology or system specialization only if they serve the core loop. Policy cards, Wildcard slots, regional allocations and policy-dependent diplomacy are not planned.

## Ongoing validation and deferred work

- [ ] Keep gameplay rules, startup, parsing, imports/metadata, solo, two-/three-peer ENet and disconnect regressions mandatory; verify real internet behavior and visuals separately.
Fleet-heavy late-game profiling and scale acceptance are consolidated under OPT-V2; the original requirement is preserved in the optimization archive.
- [ ] Steam integration, additional races, elaborate technology trees, ship customization and campaigns remain deferred.

See THOUGHTS.md for active observations and THOUGHTS_ARCHIVE.md for resolved or superseded history.

- [ ] Playtest v0.24.2 compact variable-spacing galaxies across all layouts and roster sizes, especially initial mining access, travel pacing, smaller hulls at zoom levels, and automatic flat-price PDS construction/cancellation. Later expose map size as a setup parameter.

- [ ] Visually inspect v0.24.3 fighter/miner/colony art at overview, selection and close zoom; check silhouette clarity, ownership outlines, small-size legibility and fleet-heavy render time.

- [ ] Visually verify v0.24.4 colored hull breakup and dual mining arm/nose beam alignment at multiple zooms, multiple simultaneous kills, pause/speed changes and guest snapshots. Check effect budget in fleet-heavy combat.

- [ ] Visually verify v0.24.5 shipyard art, click hit-testing at useful zooms, planet/ship overlap, enemy read-only inspection, slot compaction after construction/destruction, upgrade progress/refunds and source-colored lasers for all player colors.

- [ ] Visually verify v0.24.6 fighter close-up scale on narrow/wide windows and different galaxy sizes; selection following through formation travel, high speeds and partial/total losses, mouse/WASD release, reselect, box selection, control-group recall, zoom and pan. Check low-zoom hull sizing, close-up effects and render performance.

- [ ] Verify v0.24.7 civilian motion for all three noncombat classes, storage-blocked miner recovery, territory after claims/shipyard loss and population changes, owner-colored hulls and breakup, and unselected defended planet/beam alignment at all zoom levels.

- [ ] Visually verify v0.24.8 radial lane endpoints after rerolling, including long ring/spoke routes and local third-port availability; verify PDS selection only highlights the selected planet across multiple defended systems. Exercise stranded empty miners reopening safe routes after capture.

- [ ] Playtest v0.25.0 sector-local positioning and hold/release for mixed hulls, group selection, mining, logistics, colony travel, sector edges, repair and multiplayer latency. Check right-click POI versus empty-space disambiguation and selected destination marker at different zoom levels.

- [ ] Visually playtest v0.25.2 finer Grid/Hex Grid at all roster sizes; compare cell recognition, preview legibility, alternate paths, ordinary mining access and travel pacing. Check seed rerolls and balance on real matches.

- [ ] Manually verify v0.25.3 foreign-only and mixed-empire box selections, Shift-add/toggle, group recall, selection loss on destruction, fleet cargo totals and camera tracking. Confirm commands and hold/release affect only the owned subset. Check 2850 A.D. and the rightmost Menu at constrained HUD widths.

- [x] Expire drifting salvage independently after 90–180 simulation seconds; opportunistically collect with any hull when safe and with cargo room, retaining manual claims/orders (v0.28.0; extended v0.43.1).
- [x] Replace side inspectors with a full-width bottom command console, responsive card grids, shared controls and map projection centered above it (v0.28.1).
- [x] Compact the bottom command console and add a persistent interactive minimap with camera viewport, live hulls, system ownership and navigation (v0.28.2).
- [ ] Playtest the bottom console at different resolutions/UI scales: system/resource overview, shipyard activity, build/economy/trade actions, fleet/field/planet/shipyard inspection, scrolling, hover breakdowns and camera/input alignment. Evaluate preferred console height after human playtesting.
- [ ] Playtest salvage after mixed fleet battles: debris motion and zoom readability, group claims, competing empires, partial tractor collection, combat interruption, automatic pickup/expiry, full depots, cancellation, lane delivery, cargo racks and unload controls. Evaluate recovery rates and passive cargo distribution.

- [ ] v0.29.1: Manually validate three-zone command console: raised minimap and command wings, center selection details, right-side shipyard/economy/trade and fleet orders, narrow layouts, empty/foreign selections and all UI scales.

- [ ] v0.29.2: Verify the raised left/right console silhouette (not merely recessed center content), including transparent playfield above the center, at multiple resolutions.

- [ ] v0.29.4: Validate the three-column console after structural stabilization: center details visible, command wing scrolls, toolbars stay in their respective wings, and no clipping at 100%/scaled UI.

- [ ] v0.29.5: Verify right-click fighter commands resolve to the sector containing the cursor, including clicks near adjacent-sector boundaries and direct POI clicks.

- [ ] v0.29.6: Verify continuous map rendering behind the raised HUD, center panel 20% wider, and no fighter capture of empty unclaimed systems without population/shipyards.

- [ ] v0.29.7: Verify selecting a ship, drag-selecting a fleet, and recalling control groups never auto-pan; F explicitly starts following the current ship/fleet, while manual panning cancels follow.

- [ ] v0.29.8: Verify the center HUD remains an empty, fully filled panel with no selection, and displays details normally once a selection is made.

- [ ] v0.29.9: Verify hostile contested sectors cycle participant empire colors while allied co-presence does not flash, including neutral and owned sectors in multiplayer.

- [ ] v0.29.10: Test fighter local move commands near sector boundaries and POI icons; same-sector clicks must never route via adjacent sectors.

- [ ] v0.29.11: Test local fighter commands while crossing sector boundaries, especially before lane waypoint updates `at`; confirm no teleporting or detour to adjacent sector.

- [ ] v0.29.12: Confirm local orders normalize `at` to the physically occupied sector when clearing an in-progress lane route.

- [ ] v0.29.13: Reproduce near-boundary fighter clicks: within 64 screen pixels of selected fighters, a cursor slightly outside the simulation sector should clamp to the current sector edge rather than snap to the adjacent POI; distant clicks still travel normally.

- [ ] v0.29.14: Verify painted territory edges coincide with actual clipped sector disks, including neutral neighbors, asteroid fields, and same-sector fighter moves near shared borders. Run local-position regression when validation is available.

- [ ] v0.29.15: Check ship construction, yard activity, economy and trade tabs at small window sizes and UI scales; speed controls now live below the global header. Verify territory edge antialiasing without changing hit geometry.

- [ ] v0.30.0: Validate command-card targeting (Move, Stop, Hold, Patrol, Attack Move, salvage Load, Unload), health tiles and mixed selection, and move-only behavior over ENet. General manual loading of system resources remains a separate design task.

- [ ] v0.30.2: Playtest selection-independent planet detail fade at galaxy and system scales, including direct body selection, PDS overview indicators and close-up frames. Tune screen-radius thresholds against user screenshot if needed.

- [ ] v0.31.1: Validate shipyard-specific build assignment, blocked queue/cancellation, destruction/slot compaction, rally arrival for each hull kind, selection/command card at small resolutions and two-/three-peer replication. Review whether asteroid-field rally support is desired later.

- [ ] v0.31.3: Playtest rounded sector intersections against actual hit boundaries around clustered systems and asteroid fields. Check shipyard portraits, names, disabled states and detailed cost tooltips at small window/UI scales.

- [ ] v0.31.6: Playtest soft hull separation for local group orders, rally arrivals, fleet transit, and sector boundaries; confirm docking, mining, salvage, combat and repair retain their authoritative arrival semantics, including multiplayer. Check doubled shipyard artwork/picking and removed redundant controls.

- [ ] v0.31.7: Verify local movement arrives idle, allows autonomous combat and salvage, preserves civilian duties and repair resumption, and remains distinct from explicit Hold/Stop; verify replication under two-/three-peer ENet.

- [ ] v0.31.8: Visually verify equal-width console wings and larger center with empty, system, ship and shipyard selections at multiple window sizes/UI scales; confirm all commands and tabs remain accessible.

- [ ] v0.31.9: Playtest dark console interiors, icon-only Logistics lens toggle and persistent active state, and health-colored hull outlines against neutral dark selection tiles at different UI scales. Confirm the strip does not obstruct minimap dragging or map input.

- [ ] v0.31.10: Playtest F framing for single/mixed foreign fleets, distant group members, spreading fleets, partial/total losses, systems, planets/PDS, shipyards and asteroid fields. Check zoom/pan cancellation, orbit tracking, manual zoom-out and different viewport sizes.

- [ ] v0.32.0/v0.39.0: Playtest rally attack-move during lane and local travel, repair/resume, proximity-based rally arrival and civilian behavior. Verify double-click selection of ships/shipyards/PDS by visible type, foreign read-only groups, grouped shipyard actions, F framing, and slot invalidation when structures are lost or completed.

- [ ] v0.64.0: Validate direct exact-point, formation, patrol and manual service travel across nonadjacent sectors, including neutral/hostile transit, arrival anchors, queues, avoidance and two-/three-peer replication. Follow up by separating autonomous logistics and military strategic route selection from physical waypoint travel; retain safety and adjacency rules. Benchmark large fleets.

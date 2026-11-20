# Warbound — development TODO

Living roadmap. Build a playable, low-micro galactic RTS with conventional direct military control and autonomous physical logistics. Policies and regional card assignments are intentionally removed. Prioritize a working RTS, then promissory notes, then a complete match loop. Target 10–30 minute matches at 1×, subject to playtesting.

Review AGENTS.md before work. This is a prioritized backlog, not blanket approval to invent mechanics. Numerical balance remains provisional. Earlier implementation history and the superseded policy roadmap are preserved in git (v0.17.36 and earlier).

## 1 — Basic RTS (current priority)

- [ ] v0.66.4: Playtest tenfold lower incubator base production, crystal scarcity and AI access to advanced construction.

- [ ] v0.66.1: Verify direct local asteroid access rather than detouring through an alternate anchor, including multi-access field regression and physical delivery.

### Objectives and specialization (v0.65.0)
- [ ] v0.68.0: Validate objective tier advancement, authority real-time delay independent of speed, cumulative progress, competitive awards and pause replication. Initial thresholds: Metals 1k/3k/10k, population 200k/500k/1M, colonies 2/4/8. Last fixed tier remains visible pending advanced pool.
- [ ] Add random advanced objectives after fixed tracks, including process two antimatter items; define processing without consuming items needed for gates. Keep rare items physical, science vessel transport, no ordinary global resource counter.
- [ ] Warp gate unlock reward: science vessel carrying one antimatter transforms into immobile high-HP building, consumes item, auto-links to next owned gate; command card selects destination among eligible owned gates, host validates stable IDs, destruction invalidates links. Design actual transit activation, direction, cooldown, and AI before implementing. Include map links, selection, combat, replication and ENet tests.
- [ ] v0.67.0: Validate economic reward drafting, acquisition, AI, replication and upkeep. Expand pool to all approved rewards; private offers, public unlock announcements, true three-card layout and exhausted-pool handling remain pending.
- [ ] Shields: military 30%/station 50% extra rechargeable HP, absorb before hull, five seconds out of damage, blue bars under HP and SVG-matching glow in world/selection tile/center inspector; extra Crystal construction cost. Armor mitigation with extra Metal cost, cloak with attack reveal/detection, exclusive hulls. Integrate costs consistently in quotes, queue, refunds and AI. All cards must communicate net-beneficial tradeoffs.
- [ ] v0.66.3: Validate F4 Empire target editor, hotkey and conquest pulse. Later integrate target quantities with validated authority production policy.
- [ ] v0.66.2: Playtest wider single-line objectives and conquest upgrade modal input, resizing and HUD layering; wire the modal to future reward drafting.
- [ ] Validate default raised logistics lens and inherent resource grades, and objective progression/replication in solo and ENet.
- [ ] Verify v0.66.0 competitive payout (2 first, including same-tick ties; 1 later) and public recent achievement feed; check population column at multiple zoom levels.
- [ ] Implement three-card reward drafting: spend one point, host generates three distinct unowned options, validate offered choice and ownership at authority, prevent repeat purchases, replicate offers privately and chosen rewards publicly. Define actual reward effects and AI selection before enabling. No artificial catch-up modifier.
- [ ] Explore science objectives, technology specialization via rewards, and alternate victories.

### Large-fleet scalability — approved engineering program (v0.62.1; T-026)

**Goal:** sustain 5,000 simultaneous individually simulated and selectable ships across up to eight players (human/AI); 10,000 is the stretch/stress target, not a gameplay cap. Preserve physical logistics, combat, movement, precise commands, influence and host authority. All eight phases are approved roadmap work; implement in dependency order with measured before/after evidence and gameplay regression coverage. Prioritize shared simulation indexing and nonblocking benchmarks; begin phase 7 incrementally alongside phase 2 rather than waiting for all rendering or networking work. Phase 8 follows stable packed state and measured hot kernels. No phase is complete merely because code was merged.

#### Immediate priorities — 2026-11-19 eight-player 5× profile

Observed approximately 5 FPS as the match progressed; Godot profiler set to self-time, debugger showing 62 errors. Ship count, hardware, match seed and exact error messages are not available. Treat this as a regression/stress signal, not a controlled benchmark or proof of error causation.

- [ ] **P0 — Establish baseline (nonblocking).** User confirmed debugger errors are not a concern; defer error triage. Run seeded fleet benchmarks and record ship counts, actual simulation steps/sec, frame/tick percentiles and self-time at 1× and 5×; distinguish CPU simulation from rendering and replication. Compare against earlier versions where practical.
- [ ] **P1 — Unify combat and salvage threat indexing.** Replace independent full-fleet rebuilds in _salvage_threats and _combat with shared packed hull/team/position/region data and ordered spatial buckets. Explicitly refresh after combat deaths and ownership changes; preserve phase-specific armed/hostility predicates, exact salvage safety and movement-time checks. Reduce _hostile_bucket filtering and lookup overhead using team-partitioned indexes without changing traversal/ties.
- [ ] P1a (v0.64.40): Share combat physical-sector results with post-combat salvage threat construction; validate live routing/position signatures and iterate only survivors. Separate threat buckets still rebuilt; packed shared cell index and team partitions remain next. Benchmark and runtime pending.
- [ ] P1b (v0.64.41): Construct frozen salvage threat buckets alongside combat indexing and reuse after validating survivor count, team and routing/position signatures. Rebuild on any mismatch. Eliminate separate bucket construction on unchanged ticks; validation scan remains. Benchmark total self-time and fallback frequency.
- [ ] P1c (v0.64.42): Capture team membership once per combat entity and share across threat construction, hostile bucket filtering and defense checks. Preserve neutral and structure semantics and ordering. Packed positions and actual shared grid remain pending; benchmark/runtime pending.
- [ ] P1d (v0.64.43): Pack combat-produced salvage threat positions, teams and stable IDs into parallel arrays; spatial buckets reference slots. Preserve exact range and legacy fallback, verify parity and benchmark. Full grid consolidation remains pending.
- [ ] P1 (v0.64.44): Use the same packed threat layout for survivor rebuilds, including casualty ticks; retain legacy-query fixture compatibility. Runtime and benchmark pending.
- [ ] P1f (v0.64.45): Filter missile and pursuit candidates in one ordered pass, with distinct positive-team cache; preserve neutral targeting rules. Runtime and benchmark pending.
- [ ] P1g (v0.64.46): Skip homogeneous friendly-only packed threat cells via lazy per-snapshot team classification; retain exact mixed-cell checks. Runtime and profiler pending.
- [ ] P1h (v0.64.48): Cache ordered hostile packed slots per team and occupied threat cell, including mixed-team cells; preserve exact distance and legacy fallback. Measure cache allocation versus query savings; full shared grid pending.
- [ ] P1i (v0.64.49): Reuse combat cell coordinates for aligned two-cell threat buckets; compare frozen routing signatures without allocating replacement arrays. Exact fallback retained; runtime, boundary parity and profiling pending.
- [ ] **P2 — Incremental operations and services.** Maintain stable-ID service references and operation membership on spawn/death, order, owner and objective changes; update dynamic moving/engaged flags at required phase boundaries. Preserve AI wave IDs and deployment semantics; reconcile against full rebuilds in tests.
- [ ] P2a (v0.64.47): Replace repeated linear wave/deployed/prior-operation membership checks with step-local sets; preserve operation identity, order and tie matching. Full incremental lifecycle index and runtime benchmark pending.
- [ ] P2b (v0.64.50): Selective live service-target lookup builds only the requested entity reference; skip unrelated orbital geometry and hull records. Full phase snapshots unchanged; stable ID indexing and runtime pending.
- [ ] P2c/P3a (v0.64.51): Authority-step stable-ID hull reference index, updated on launch and removal; selective service lookup uses live dictionary refs. Outside the step use existing scan. Persistent across steps and packed slots remain pending; lifecycle regression and benchmark pending.
- [ ] P2d (v0.64.52): Use indexed single-hull ownership checks and selective queued follow validation; add live reference/removal regression. Runtime pending.
- [ ] P2e (v0.64.53): Reuse authority-step hull references during operation dispatch; replace deployed membership scans with a set. Preserve fallback and member order; runtime pending.
- [ ] P2f/P3b (v0.64.54): Reuse live hull references in operation synchronization and shallow-copy the step index for frozen combat lookup, retaining simultaneous damage semantics and out-of-step fallback. Runtime and benchmark pending.
- [ ] **P3 — Start packed simulation state (phase 7).** Establish stable ID-to-slot mapping and typed hot fields, migrate shared index queries first, then movement/combat/logistics in measured stages. Keep one authoritative source of truth and compatibility adapters; verify lifecycle and replication parity.
- [ ] P3c (v0.64.55): Combat snapshot uses a stable ID-to-slot map and packed previous-target and sector arrays instead of two dictionaries. Preserve missing-target defaults and simultaneous damage. Position/health migration and runtime measurement pending.
- [ ] P3d (v0.64.56): Pack frozen hull positions and teams alongside sectors and prior targets; attacker loop resolves slot once. Retain ID-keyed structure/target compatibility dictionaries; benchmark duplication cost and migrate target kernels next.
- [ ] P3e (v0.64.57): Pack ordered target-block IDs and coordinates for laser, missile and pursuit kernels; avoid per-candidate position dictionary lookups. Preserve bounds and tie rules; runtime and allocation benchmark pending.
- [ ] P3f (v0.64.58): Store frozen hull HP in packed float64 slots; retain structure HP lookup and sparse damage accumulation. Preserve simultaneous damage and lethal-shot attribution. Runtime and benchmark pending.
- [ ] **P4 — Density-safe algorithms and native/parallel kernels.** Measure contact/separation and nearest-target worst cases; avoid unbounded all-pair work without arbitrary candidate caps. Only parallelize independent reads after stable phase snapshots; evaluate native kernels after profiling.
- [ ] **Secondary rendering and replication.** Profile _draw_minimap and _draw_station; cache static geometry and batch or cadence-limit visual refreshes where measured. Continue phase 6 after simulation baseline is understood, or earlier if actual peer measurements identify a network bottleneck.

- [ ] **1. Reproducible stress benchmarks.** Add seeded headless simulation and graphical stress scenarios at 500, 1,000, 2,500, 5,000 and 10,000 live ships. Cover dispersed fleets, dense opposing battles, same-team swarms, formations/highways, repair, busy mining/hauling/salvage hubs, production/destruction and eight-player mixed AI/human matches. Measure solo, host and guest separately at 1×, 5× and supported stress speeds. Extend Perf diagnostics with per-phase and total simulation time, frame time/FPS, p50/p95/p99/max, missed tick deadlines, draw calls, memory/allocation pressure, encode/decode time, payload size, per-guest/aggregate throughput, RTT/loss/jitter and state age. Record seed, counts, build, hardware, renderer, resolution, zoom, duration and network conditions. Keep reproducible baseline and subsequent reports; use headless tests for simulation, actual graphical runs for rendering and real ENet peers for replication. Initial proposed target on an agreed reference PC: 60 FPS (p95 frame time ≤16.7 ms), sustained 10 Hz authority at 1× with headroom, no growing tick backlog, bounded memory and responsive input at 5,000 ships. Set hardware and network budgets from baseline; report 5× and 10,000 results separately rather than implying guarantees.
- [ ] Phase 1a (v0.64.1): Seeded headless harness in tests/fleet_benchmark.gd; run and record baseline using PERFORMANCE.md. Graphical, AI, production/repair/salvage and peer workloads still pending.
- [ ] Phase 2a (v0.64.4): Static military graph identity fast path, cached squared bisector lengths and bounding-disk rejection. Compare self-time and headless benchmark; validate topology across match restarts and snapshots. Ship membership cache and spatial index remain pending.
- [ ] Phase 2b (v0.64.5): Static sector bounding-disk spatial grid for sector_at and influence core lookup; exact containment and candidate restrictions preserved. Run parity fixture and repeat profiling. Dynamic hull index pending.
- [ ] Phase 2c (v0.64.6): Cache team presence per occupied sector during combat to remove redundant per-moving-hull same-sector hostile scans; preserve neutral teams and move-only behavior. Runtime/benchmark pending.
- [ ] Phase 2d (v0.64.8): Derived primary ship activity enum; early busy exits, no temporary kind/order arrays on idle path, reuse idle/wander eligibility within separation pass. Verify old predicate parity and profile at 1× and 5×. Persisted activity flags and broader phase caching deferred until measured.
- [ ] Phase 2e (v0.64.9): Memoize frozen salvage threat checks at sector centers by team within each threat snapshot; keep live ownership, discovery and exact wreck safety checks. Verify phase invalidation and profile at 5×.
- [ ] Phase 2f (v0.64.19): Shared ordered spatial bucket insertion for combat hulls/structures and salvage threats; skip whole-sector pursuit scan when no hostile teams present. Separate phase snapshots retained; shared full-fleet index and dense hostile search pending. Verify regression and benchmark.
- [ ] Phase 2g (v0.64.20): Cache center membership, bounded salvage topology and per-team/origin reachability within threat phase; recheck local discovery and ownership eligibility to invalidate changed paths. Regression and 5× profile pending.
- [ ] Phase 2h (v0.64.21): Index freighter handoff candidates by owner and local spatial cell before movement; preserve original fleet order and exact safety/range/cargo checks. Add ordering regression. Continue simulation architecture before cosmetic rendering.
- [ ] Phase 2i (v0.64.22): Memoize repair-site safety per owner/site during each withdrawal planning pass; retain live checks during movement and rebuild after combat. Runtime and mass-retreat benchmark pending.
- [ ] Phase 2j (v0.64.23): Index damaged service targets at frozen repair coordinates before movement; retain original tie order, exact range and live damage/team checks. Runtime and benchmark pending.
- [ ] Phase 2k (v0.64.24): Lazily cache hostile-only combat cells and sector buckets per team per combat pass, preserving candidate order and exact weapon checks. Opposing dense fleets still require nearest-target acceleration; benchmark pending.
- [ ] Phase 2l (v0.64.25): Cache ordered laser candidate blocks with conservative bounding-box pruning; preserve approximate ties and exact distances. Measure dense and dispersed fleets; worst-case overlapping blocks and missile/pursuit scans remain pending.
- [ ] Phase 2m (v0.64.26): Reuse ordered bounding blocks for missile acquisition, including structures; preserve positive-team hostility, focus and last equal-distance candidate. Benchmark and runtime pending.
- [ ] Phase 2n (v0.64.27): Reuse ordered bounds for sector-wide pursuit acquisition, preserving positive-team hostility and existing nearest/tie rules. Benchmark spread-out and overlapping fleets; runtime pending.
- [ ] **2. Shared spatial indexing and redundant-scan removal.** Build a reusable world-space index with owner/team, hull kind, region and stable-ID lookups; update at explicit simulation phase boundaries to avoid stale references. Use it for combat (including dense-cell and whole-sector pursuit), missile acquisition, avoidance, repair/safe stations, miner–freighter handoff, resource staging, trade, salvage, discovery, selection and influence. Cache shared sector/team presence and route queries, reuse per-step scratch data, eliminate repeated full-fleet/target-list scans. Preserve exact range/ownership validation, deterministic tie-breaking and conservation; use density-safe search structures rather than silently capping gameplay candidates. Benchmark sparse and pathological crowded cases.
- [ ] Phase 3a (v0.64.28): Align existing mining, unload, salvage-depot and resource-stage retry timers to stable hull-ID slots. Initial/reset searches remain immediate, active work unchanged. Validate timing and 5× spikes; benchmark pending.
- [ ] Phase 3b (v0.64.29): Stagger unsuccessful automatic Harvester repair searches at existing half-year slots; active and explicit repairs retain per-step checks. Newly damaged targets may wait up to 0.5 simulation years. Validate response and benchmark.
- [ ] Phase 3c (v0.64.30): Stagger unsuccessful automatic laser, structure and pursuit acquisition at 0.2 simulation-year intervals; active targets, explicit attacks, missiles and weapon timers remain per-step. Validate first-contact latency and benchmark.
- [ ] Phase 3d (v0.64.31): Reuse in-range hostile laser hull targets between staggered 0.2-year refreshes; immediately rescan invalid targets, bypass reuse for explicit attack, guard and pursuit. Verify target transitions and damage cadence; runtime and benchmark pending.
- [ ] Phase 3e (v0.64.32): Reduce separation/contact pair overhead using squared-distance rejection and packed indexed correction scratch, preserving pair and application order. Verify existing movement/contact regressions and dense swarm profile; runtime pending.
- [ ] Phase 3f (v0.64.33): Cache occupied contact-cell bounds per correction pass and reject entire distant buckets before examining pairs. Preserve pair order and exact contact checks; benchmark sparse and dense fleets.
- [ ] Phase 3g (v0.64.34): Stagger strategic AI turns across eight stable player slots per four-year interval. Initial decisions immediate, first repeat may occur sooner; verify economic/expansion pacing and eight-player spikes.
- [ ] Phase 2o (v0.64.35): Precompute each yard's queue capacity once per candidate search and reuse candidate eligibility; preserve queue order and re-evaluate after earlier yards mutate stock/population. Profile _work_planet self-time and run economy regression.
- [ ] Phase 2p (v0.64.36): Reuse warehouse capacity, next-tier costs and live starting stock across each production resource loop. Preserve thresholds, reserve rules and production/consumption order. Economy regression and profiler pending.
- [ ] Phase 2q (v0.64.37): Precompute conservative guaranteed interior sector radii; bypass radial bisector scans for interior points, retain exact boundary path. Grid parity fixture and profiler pending.
- [ ] Phase 2r (v0.64.38): Cache exact node/position containment results within each authoritative step; clear at step boundaries and bypass other graphs. Preserve all local_sector routing hints. Regression and profiler pending.
- [ ] **3. Multi-rate, staggered decision scheduling.** Retain physical movement and weapon damage/cooldown accounting at 10 simulation steps per normal-speed second; interpolate visuals every rendered frame. Initial tuning candidates in simulation-time terms: target acquisition 2–5 Hz, avoidance 5–10 Hz, repair search 2 Hz, influence refresh 2 Hz, logistics job searches 1–2 Hz and strategic AI 0.25 Hz. Reuse valid targets/jobs; invalidate immediately on destruction, changed ownership, new commands, unsafe conditions or lost range where required. Stagger by stable ID and budget expensive searches to prevent synchronized spikes; preserve elapsed-time accounting and pause/speed behavior. Verify no skipped damage, cargo, repairs, order transitions or unfair target starvation.
- [ ] Phase 4a (v0.64.10): GPU MultiMesh batches for distant dots and simplified hull textures, packed transform upload and retained close-up drawing. User prioritized GPU work alongside phase 2. Validate GL Compatibility, layer order, zoom transitions, draw calls and FPS at 1×/5×; full-detail batching and effects remain pending.
- [ ] Phase 4b (v0.64.11): Single shader-driven instanced exhaust batch, cached hull extents, packed per-instance thrust/phase; extend hull batching to cargo-free detailed ships. Validate plume orientation, alpha, layering and GL Compatibility at all zooms. Debris and cargo overlays pending.
- [ ] Phase 4c (v0.64.12): GPU instance laser/mining/repair beams, missile trails and blaster/missile sprites in two colored quad batches with conservative viewport rejection. Verify effects, layering, GL Compatibility and frame performance; projectile motion still CPU-sampled.
- [ ] Phase 4d (v0.64.13): Batch cargo bay backgrounds, fills and halos, instance detailed cargo hulls except science; cache interpolated world poses per frame/revision and reproject for camera changes. GPU vertex motion interpolation remains pending; verify selection, effects, pause, guest samples and draw order.
- [ ] Phase 4e (v0.64.14): Reuse existing instanced sprite/beam batches for destruction sparks and hull fragments, preserving drift, spin, lifetime and tint. Validate visual layering and mass-casualty frame costs; GPU animation of debris remains pending.
- [ ] Phase 4f (v0.64.16): Instance damaged entity health bars and shader-rendered dashed selection rings in shared overlay batches; retain visibility and colors. Validate ring scale/AA, layer order and runtime at multiple zooms.
- [ ] Phase 4g (v0.64.17): Cache asteroid triangulation and batch visible unique rock fills/edges into one colored mesh per field. Preserve depletion scale and discovery; compare mesh upload cost against previous polygon path before considering instancing approximations.
- [ ] **4. GPU-batched rendering and visual LOD.** Cache one pose/interpolation pass per frame/revision and reuse across main map, minimap, UI, picking and camera. Batch visible hulls using MultiMeshInstance2D or measured equivalent, grouped by mesh/texture and spatial chunk; use packed transforms and color/custom instance data. Preserve individual picking, silhouettes, facing, owner tint and selection. Galaxy view uses simple silhouettes and minimal effects; tactical view recognizable hulls and simplified effects; close-up full art, cargo, weapons and thrusters. Batch and budget cosmetic particles, projectiles, beams, health bars and formation ghosts; cull offscreen effects and avoid unnecessary redraws. Keep GL Compatibility support or explicitly validate any alternative renderer before changing defaults. Compare frame percentiles/draw calls at all zooms; visuals must never change gameplay.
- [ ] Phase 5a (v0.64.15): Precompute conservative per-site bisector candidate rows and squared lengths for the territory shader. Preserve continuous rounded contours and original candidate order. Full region raster/mesh and incremental influence pending; verify deep zoom and GPU timings.
- [ ] Phase 5b (v0.64.18): Reuse exact-position hull region results across local influence refreshes, invalidate on graph replacement and prune dead hulls. Recompute live weights and spillover; incremental totals and moving-hull acceleration remain pending.
- [ ] **5. Cached territory geometry and incremental influence.** Precompute static rounded sector/highway region IDs (tiled high-resolution mask, mesh or equivalent); use region color lookup instead of per-pixel all-site/all-edge distance searches. Invalidate geometry only on topology changes. Maintain per-player influence sums incrementally on spawn, death, movement, construction and ownership changes; periodically reconcile against authoritative full calculation. Preserve 50-point saturation, normalized uncapped shares, region membership, discovery filtering, neutral outlines and minimap parity. Verify boundaries at deep zoom and intersections; profile CPU/GPU cost.
- [ ] **6. Scalable multiplayer replication.** Retain authoritative ENet host/solo design; no lockstep rewrite required. Move hot ship state to versioned compact binary records, stable IDs and bounded validated quantization; separate static/new/deleted entities, discrete reliable events and baseline-acknowledged deltas from unreliable revisioned poses. Coalesce/chunk commands for large formations; preserve ownership checks, per-hull orders and queues. Adapt pose cadence to movement/predictability and relevance without hiding enemy ships or starving distant updates; use timestamped interpolation, bounded extrapolation, periodic keyframes and explicit recovery on loss/reorder/reconnect. Benchmark real two-, three- and eight-peer matches including constrained bandwidth/latency/jitter/loss. Check spawn/death, cargo conservation, health/target/orders, convergence, disconnect/restart, and no unbounded reliable backlog. Current 20-byte/10 Hz pose payload worst case at 5,000 moving ships is 8 Mbps per guest / 56 Mbps host to seven guests before other traffic; measure improvement against that baseline.
- [ ] **7. Data-oriented simulation layout.** Incrementally migrate hot hull fields (ID, position, velocity/heading, HP, owner, kind, target, movement flags) from nested Dictionaries into packed structure-of-arrays/ECS-style storage with stable ID→slot mapping and explicit lifecycle/compaction. Separate cold data such as complex queues and metadata; retain compatibility adapters during migration and a single authoritative source of truth. Port subsystems in benchmark-driven stages and verify gameplay and serialization parity at each step. Avoid one scene node per simulated hull and repeated per-step allocation. Measure cache/allocation/memory and frame/tick gains.
- [ ] **8. Parallel and native simulation kernels.** After shared indexes and packed state are stable, profile target searches, spatial index construction, navigation/AI and other CPU-heavy kernels. Parallelize independent read-only work over immutable snapshots/partitioned arrays; commit results in deterministic authoritative order with explicit synchronization. Keep scene-tree/UI operations on the main thread; avoid concurrent writes to existing shared dictionaries. Evaluate and implement C++ GDExtension for remaining expensive kernels where benchmarks justify it; preserve GDScript-facing interfaces, GL Compatibility, builds/platform support and safe fallback. Validate deterministic outcomes within the authority, thread safety, memory, lifecycle and actual peer replication.

- [ ] **Scale acceptance:** run the complete suite after all phases and publish measured 5,000-ship results and 10,000-ship stretch results; compare with phase 1 and identify remaining limits. Keep automated gameplay and ENet regression checks, and manual visual/Internet validation distinct. Do not mark capacity achieved until sustained representative mixed fleets, dense combat, logistics and eight-player tests pass on documented hardware/network configurations.

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

- [ ] Playtest v0.43.3 world-center camera and F2 double recall at all zooms/resolutions; local movement onto rendered PDS planets, station queue/resource tab visibility and hover, command-card row placement and concise upgrade/weapon tooltips.

- [ ] Playtest v0.43.2 translucent territory, four-row station Build card, single-ship facing drag at different zooms and population-blocked shipyard orders yielding to eligible hulls and resuming on recovery.

- [ ] Playtest v0.43.1 metal-rich long-lived asteroid inventories and longer salvage expiry, Trade-only doubled right wing at various window heights and fighter/miner/mixed command availability.

- [ ] Playtest v0.43.0 safe civilian salvage search and delivery, retreat/claim release when enemies arrive; minimap right-click movement, attack, mining, repair, rally and Shift queue at all camera zooms; F2 owned fighter selection without camera movement.

- [ ] Playtest v0.42.2 native 100% UI and crisp tooltip text/icon rendering across actual window resolutions and OS DPI settings; verify new resource building names in build card and queue. Prior UI-scale acceptance items now mean window-size checks at fixed 100%.

- [ ] Playtest v0.42.1 F and double control-group centering at overview/close-up zoom and different window scales; check opaque recipe hover cards, icons, crew, disabled commands and tooltip placement near screen edges.

- [ ] Playtest v0.42.0 timed warehouse/habitation/orbital housing upgrades, queue progress/refunds and AI orbital construction; verify concise resource tooltips, health-colored grouped building tiles, top-left control groups and relation-colored selected-ship target circles at all zoom levels.

- [ ] Playtest v0.41.0 station command card's three numbered shipyard ports, build/select/pending states, one-time Reinforced Plating and Laser Matrix, weapon details for single armed entities, dual defensive beam visuals and provisional upgrade costs. Check rebuilding a destroyed middle port without moving its neighbors.

- [ ] Playtest v0.40.0 station command subcards at varied window sizes: Build/Trade/Return placement, cost/effect tooltips, repeat borders, sequential infrastructure queue tiles (v0.43.4), clicking to refund, resource details returning on empty queue, trade sliders, and station-anchored logistics lens. Verify F/portrait follow never snaps zoom, even for dispersed fleets.

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
- [ ] Prototype compact diplomacy UI and host-authoritative replication; test with real multiplayer. Keep complex treaties and galactic votes deferred.

## 3 — Core match loop

- [ ] Existing finite raw antimatter deposits, extraction and physical delivery (v0.17.33) are a foundation. Define refining/processing, storage, ownership, and the minimal antimatter objective and victory condition.
- [ ] Integrate conquest, industrial development and promissory notes into a complete game. Decide team scoring and end-of-match handling if antimatter victory differs from conquest.
- [ ] Playtest at 1× in 1v1, four-player and larger teams; balance travel, economy, conflict, negotiation and antimatter timing. Measure runaway-leader risk, comeback opportunities and meaningful decisions per minute.
- [ ] Consider activity-driven technology or system specialization only if they serve the core loop. Policy cards, Wildcard slots, regional allocations and policy-dependent diplomacy are not planned.

## Ongoing validation and deferred work

- [ ] Keep gameplay rules, startup, parsing, imports/metadata, solo, two-/three-peer ENet and disconnect regressions mandatory; verify real internet behavior and visuals separately.
- [ ] Profile late-game 8-player and fleet-heavy matches using the v0.20.4 simulation-phase diagnostics; compare 1× and 5×. Remove redundant work first, then investigate trade matching, miner search, repair safety, discovery scans and frame-budgeted fixed steps. Preserve host authority, gameplay and network behavior. Benchmark path caching, territory rendering, snapshot efficiency, resource hover and large-map performance.
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

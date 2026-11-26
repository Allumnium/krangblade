# Fleet performance baseline

Run from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/fleet_benchmark.gd -- --ships=500 --scenario=dispersed --ticks=100
```

Omit --ships or --scenario to run all five sizes (500, 1000, 2500, 5000, 10000) or all four scenarios (dispersed, battle, swarm, logistics). Options: --seed=827, --ticks=100, --speed=1 or --speed=5. Add --profile-detail for opt-in miner/freighter subphase timings; this adds timer overhead and should not be used for comparable throughput samples. Start with small isolated runs; dense cases may be expensive. Save FLEET_BENCH JSON lines and compare identical options/build configuration/hardware. Each sample is a batch of one or five 0.1-year simulation substeps; a deadline miss is a batch above 100 ms. Percentiles use nearest rank. Phase timing is existing simulation instrumentation, not an exhaustive breakdown; the slowest_tick field records the worst batch's index and phase times. Initial population is synthetic, not paid construction; casualties are not replaced and actual hull counts are reported. Static memory may be unavailable in release builds. No rendering, AI, ENet or background workload is measured by this harness.

## Initial headless samples (2026-11-24)

Godot 4.7.2 stable, Windows, AMD Ryzen 5 7600X (12 logical processors), seed 827, eight synthetic non-AI players, 100 ticks per run. Samples were measured at project v0.97.75; v0.97.76 changes only test fixtures, documentation and the version. These are direct headless `EconomyRules.step` timings, not threaded-session, rendering, AI, ENet or background-load results. `p95`/`p99`/`max` are milliseconds per benchmark batch; a batch above 100 ms counts as a deadline miss.

| Scenario | Ships | Speed | p50 ms | p95 ms | p99 ms | max ms | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dispersed | 500 | 1x | 75.929 | 85.841 | 128.207 | 186.253 | 2/100 |
| dispersed | 500 | 5x | 326.613 | 397.066 | 408.865 | 485.562 | 100/100 |
| dispersed | 1,000 | 5x | 614.284 | 779.307 | 808.902 | 914.837 | 100/100 |
| dispersed | 2,000 | 1x | 315.714 | 341.421 | 353.447 | 543.060 | 100/100 |
| battle | 500 | 1x | 73.557 | 79.403 | 80.486 | 96.618 | 0/100 |
| swarm | 500 | 1x | 82.129 | 95.734 | 99.865 | 108.289 | 1/100 |
| logistics | 500 | 1x | 68.208 | 83.006 | 114.293 | 2,571.718 | 2/100 |

The 2,000-ship 1x and 1,000-ship 5x dispersed targets miss the 100 ms batch budget on every measured tick. The logistics run had one large outlier (2,474.214 ms in its Civilian logistics phase); investigate with repeated profiles before attributing it to a stable hotspot. These samples establish a headless baseline only, not a graphics or real-time acceptance result.

## Repeated target samples and native parity (2026-11-24)

Godot 4.7.2, Windows, AMD Ryzen 5 7600X, seed 827, eight synthetic non-AI players, 100 ticks. `native` uses the optional Windows x86_64 extension; `GDScript` is the reference path. Times are milliseconds per batch; combat and movement columns are phase p50.

| Scenario | Ships | Speed | Backend | p50 ms | p95 ms | p99 ms | max ms | Combat p50 | Movement p50 | Misses |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dispersed | 2,000 | 1x | GDScript | 313.385 | 339.465 | 467.357 | 515.077 | 130.977 | 106.239 | 100/100 |
| dispersed | 2,000 | 1x | native | 312.762 | 336.487 | 437.967 | 439.151 | 128.842 | 106.808 | 100/100 |
| dispersed | 1,000 | 5x | GDScript | 575.027 | 777.689 | 816.518 | 925.608 | 241.928 | 194.215 | 100/100 |
| dispersed | 1,000 | 5x | native | 579.165 | 771.278 | 786.455 | 971.661 | 245.728 | 196.036 | 100/100 |

The optional extension built and its targeting-parity tests passed. The same-machine runs show less than a 1% p95 difference, within run-to-run variation; they do not demonstrate a native speedup, so the backend remains opt-in. The largest measured phases are Combat / repair and Other movement. Both target workloads still exceed the 100 ms batch budget on every tick.

## Broader 1,000-ship profiles (2026-11-24)

Godot 4.7.2, project v0.97.78, the same Windows/Ryzen 5 7600X system, seed 827, eight synthetic players, and 100 batches per run. These remain headless simulation measurements. Phase columns are p50 milliseconds per batch.

| Scenario | Speed | p50 ms | p95 ms | p99 ms | max ms | Combat p50 | Other movement p50 | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| battle | 1x | 146.459 | 162.447 | 171.402 | 180.991 | 56.436 | 57.396 | 100/100 |
| swarm | 1x | 162.395 | 193.896 | 198.021 | 199.727 | 36.599 | 88.784 | 100/100 |
| logistics | 1x | 133.845 | 171.946 | 181.315 | 5,168.152 | 30.383 | 58.829 | 100/100 |
| battle | 5x | 657.433 | 750.979 | 760.932 | 766.313 | 262.399 | 245.030 | 100/100 |
| swarm | 5x | 745.313 | 917.316 | 978.028 | 987.283 | 191.905 | 350.973 | 100/100 |
| logistics | 5x | 957.403 | 1,077.075 | 1,143.770 | 5,614.859 | 152.194 | 438.823 | 100/100 |

The 1x logistics case was repeated three times: each slowest batch was tick 0, with 4.9–5.0 seconds attributed to Civilian logistics. The 5x case also spikes at tick 0 (5.0 seconds in Civilian logistics). Later batches are much lower, but still miss the 100 ms budget; this synthetic cold-start workload is not a steady-state measurement. The exact subroutine behind the initial route/work selection spike remains unprofiled.

Two-/three-/eight-peer normal ENet and threaded-authority smokes pass locally, as do the two-peer loading/host-disconnect cases. The earlier `max channels: 0` errors were reproduced when the smoke clients disconnected simultaneously after the lobby transition; staggering their test teardown produced clean host/client logs in both eight-peer normal and threaded runs. This was a harness teardown race, not a match simulation failure. Higher-count battle/swarm/logistics profiles and combined live-simulation/rendering capture remain outstanding. The current initiative acceptance target is 60 FPS and sustained 10 Hz at 2,000 ships at 1x and 1,000 ships at 5x; do not infer this from isolated graphics or headless results.

## Initial match-scene render samples (v0.97.79)

Run with the project window (not `--headless`) to exercise the real match renderer. The harness stops the economy timer, disables fog, injects a seeded synthetic fleet, disables camera panning, warms up for 30 frames, measures frame intervals, and writes a screenshot under Godot's `user://` directory. It does not measure live simulation, AI, ENet, or background workload.

```sh
godot --path . --script res://tests/fleet_render_benchmark.gd -- --ships=2000 --frames=300 --zoom=5
```

Godot 4.7.2 stable, Windows, Compatibility renderer, 1280×720, AMD Ryzen 5 7600X, NVIDIA GeForce RTX 5060 Ti, seed 827. All 2,000 synthetic fighter poses were visible.

| Ships | Zoom | Frames | p50 ms | p95 ms | p99 ms | max ms | Frames >16.67 ms | Avg draw calls |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 5 | 100 | 8.331 | 8.353 | 8.394 | 8.402 | 0/100 | 368 |
| 100 | 5 | 300 | 8.329 | 9.166 | 10.325 | 11.467 | 0/300 | 467 |
| 2,000 | 5 | 300 | 82.916 | 92.407 | 99.621 | 105.171 | 300/300 | 2,367 |
| 2,000 | 0.1 | 100 | 78.115 | 86.553 | 99.569 | 106.264 | 100/100 | 2,225 |

The 100-ship sample remained below the 16.67 ms frame budget. The 2,000-ship sample improved from a prior 107.968 ms p95 capture to 92.407 ms p95 after pose-cache and drawing-loop changes, but still misses 60 FPS on every measured frame. The lower-zoom diagnostic is not directly comparable in sample length; it indicates that simply reducing detailed hull size does not remove the large-fleet cost. Screenshot paths are printed by the harness. These are isolated renderer measurements, not initiative acceptance results.

## Miner startup follow-up (v0.97.80)

Godot 4.7.2, Windows, Ryzen 5 7600X, seed 827, eight synthetic players. The per-step mining candidate cache retains original chunk order and checks live depletion; station positions are evaluated once per resource/access search rather than once per rock. The economy rule regression fixture passed, including miner target, multi-access anchor, depleted-field and route cases.

| Scenario | Ships | Speed | Ticks | p50 ms | p95 ms | max ms | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| logistics | 1,000 | 1x | 100 | 135.853 | 167.942 | 1,852.020 | 100/100 |
| logistics | 1,000 | 5x | 100 | 946.480 | 1,056.529 | 2,432.823 | 100/100 |

The 1x cold-start batch is 1,852.020 ms, down from the earlier 5,237.772 ms sample. An opt-in three-tick subprofile attributes 1,724.985 ms of the first batch to Civilian logistics, with 1,538.844 ms in miner field selection: 653.207 ms candidate scoring, 371.957 ms depot search, and 20.228 ms access-path work. This identifies the startup bottleneck but does not meet the 100 ms budget; steady 1x batches also miss it. The 5x logistics run likewise misses on all measured batches. A per-rock depot-distance cache experiment increased the startup batch to 2,342.356 ms and was discarded.

## Mining access deduplication (v0.97.82)

Depot choice and rock scores are anchor-independent when a field-center origin is supplied. Evaluate them only for the first reachable access anchor; retain original field/chunk order and live depot/storage/ore checks. Focused validation: `tests/economy_rules_test.gd -- --mining-selection-only` passes skipped access anchors, access/rock ties, preferred rocks, depletion and full-storage recovery.

Same Godot/hardware/seed and 1,000 ships throughout each 100-batch sample:

| Scenario | Speed | p50 ms | p95 ms | p99 ms | max ms | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| logistics | 1x | 99.652 | 126.916 | 134.819 | 1,179.527 | 49/100 |
| logistics | 5x | 720.295 | 823.579 | 871.301 | 1,564.590 | 100/100 |

A separate three-tick detailed run measured miner selection at 1,013.250 ms, including 411.215 ms scoring, 335.132 ms depot search and 16.841 ms access checks. Both throughput samples still fail acceptance. Other phases also ran faster than the previous session, so these sequential measurements are not a controlled estimate of the optimization's isolated speedup. No combined rendering, worker, AI or ENet workload is measured here.

## Combined live-threaded captures (v0.97.83)

Use `--live` to start an independent authority worker on the seeded synthetic render fleet; omit it to retain the simulation-stopped mode.

```sh
godot --path . --script res://tests/fleet_render_benchmark.gd -- --ships=2000 --frames=300 --zoom=5 --live --speed=1
godot --path . --script res://tests/fleet_render_benchmark.gd -- --ships=1000 --frames=300 --zoom=5 --live --speed=5
```

Godot 4.7.2, Windows, Ryzen 5 7600X, RTX 5060 Ti, Compatibility renderer, 1280x720, seed 827. These are dense, same-owner Fighter fleets in a solo match, with synthetic treasury funding to avoid unpaid/defection behavior. Renderer warmup occurs before starting simulation; the measurement includes simulation startup, movement, snapshot publication and interpolation. No AI, opposing combat, logistics or ENet is included. All ships remain alive throughout each sample. These are short target-scale probes, not sustained late-game acceptance.

| Ships | Speed | Seconds | Frames | Frame p50 ms | Frame p95 ms | Frames >16.67 ms | Completed batches | Batches/s | Sim p95 ms | Batches >100 ms | Worker overruns | Copy p95 ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,000 | 1x | 30.636 | 300 | 78.180 | 176.752 | 300/300 | 93 | 3.036 | 251.687 | 93/93 | 200 | 15.148 |
| 1,000 | 5x | 12.560 | 300 | 38.255 | 79.562 | 300/300 | 21 | 1.672 | 583.574 | 21/21 | 103 | 6.785 |

Published simulation advance was 9.3 and 10.5 years respectively; one 1x batch advances 0.1 years and one 5x batch advances 0.5 years. Every frame and observed batch misses its budget. Completed throughput is far below 10 batches/s; worker overload coalescing slows simulation. Snapshot-copy time is reported separately from simulation work. Screenshots confirm the dense fleet and HUD are rendered; they do not establish long-session interaction or internet behavior.

The small 100-ship live startup/teardown check completed nine batches at 11.612 ms maximum simulation time with zero worker overruns. The unchanged paused mode completed 100 frames with 8.358 ms p95 and no frames over 16.67 ms. No full suite or CI run was performed for this test-harness increment.

## Render path batching (v0.97.84)

Same harness and hardware as above, 200 measured frames.

| Mode | Ships | Speed | Frame p50 ms | Frame p95 ms | 2D draw calls | Batches/s | Sim p50 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Simulation stopped | 2,000 | - | 32.3 | 35.8 | 368 | - | - |
| Live threaded | 2,000 | 1x | 36.9 | 156.5 | 370 | 3.04 | 231.1 |
| Live threaded | 1,000 | 5x | 18.5 | 25.2 | 370 | 1.66 | 530.3 |

Before this change the stopped 2,000-ship sample measured 74.8 ms p95 with about 2,367 draw calls. Temporary probes showed the minimap at 20 ms (one draw call per hull), pose rebuild at 16.7 ms and the ship loop at 10.9 ms. The minimap now submits all hull dots in one triangle array from the frame pose cache; poses use one frozen projection and a per-owner shared-vision memo; service targets are cached per snapshot/motion revision; the ship loop caches hull textures per kind/owner. Live 2,000-ship p95 is dominated by frames that coincide with batch publication; simulation throughput is unchanged and both targets still fail.

## Publish-frame spikes (v0.97.85)

Same harness, 200 measured live frames. Temporary probes showed frames coinciding with a batch publication spent about 80 ms in the territory/fog refresh, mainly `team_vision` at about 63 ms. Ship vision now stamps per-row cell spans of the same disk predicate, with per-owner share/sensor memoization (economy-rules parity test against per-cell stamping). Selected-unit command-card refreshes scan only selected roster entries rather than calling `selected_units.has()` for every hull.

| Ships | Speed | Frame p50 ms | Frame p95 ms | Frame p99 ms | Batches/s |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2,000 | 1x | 35.1 | 99.4 | 105.2 | 3.48 |
| 1,000 | 5x | 18.1 | 23.1 | 54.6 | 1.55 |

Fog per publication fell from about 66 to 17 ms. Remaining per-publication main-thread work is about 55 ms (fog 17, HUD/inspector refresh about 15, territory warnings about 10, motion sync about 8, tactical alerts about 4). Simulation throughput is unchanged and is now the dominant unmet target.

## Simulation profile (v0.97.86)

Headless step probe, 2,000 same-owner fighters on 1x (about 218 ms per batch): movement 92 ms (`_step_hull` 57, settlement 36), combat/repair 69 ms with no enemies present (frame build 21, per-hull combat 21, withdrawals 8, threat reuse 7), formations/orders 31 ms, conquest/exploration 12 ms, economy 11 ms. Nearly every fighter steers through `_move_formation` ? `_navigate` (about 16 ?s each); the predictive direct-travel fast path never qualifies in this dense converging fleet. Cost is diffuse per-hull Dictionary work, roughly 100 ?s per hull per tick.

v0.97.86 replaces per-call literal containers (`ship_max_hp` table and 38 military/armed kind arrays) with constants and avoids a per-hull `range()` allocation in the combat frame sector fallback.

| Ships | Speed | Frame p50 ms | Frame p95 ms | Frame p99 ms | Batch p50 ms | Batches/s |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,000 | 1x | 35.7 | 96.1 | 106.4 | 214.2 | 3.56 |
| 1,000 | 5x | ? | ? | ? | ? | 1.82 |

Meeting 10 Hz at 2,000 hulls requires roughly a 2x simulation speedup at 1x and about 5x at 1,000 hulls on 5x. Further constant-factor GDScript trimming yields only a few percent; the remaining path is structural (packed per-hull arrays for movement/combat/formations, or native kernels enabled by default after parity).


## Local Linux packed movement batches (v0.97.87–88)

Godot 4.7.2, Linux container, Intel Xeon Platinum 8573C (5 logical processors exposed), seed 827, eight synthetic players, headless only. The user supplied the executable and matching checkout. Sequential short samples from the v0.97.86 baseline and staged v0.97.87–88 code (version string was bumped after measurement). Do not compare absolute times with the Windows/GPU captures above; shared-container timing is variable.

| Scenario | Ships | Speed | Batches | Version | p50 ms | p95 ms | Other movement p50 ms | Misses |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| swarm | 2,000 | 1x | 40 | 0.97.86 | 649.367 | 808.978 | 442.813 | 40/40 |
| swarm | 2,000 | 1x | 40 | 0.97.87 | 580.122 | 655.443 | 412.794 | 40/40 |
| swarm | 2,000 | 1x | 40 | 0.97.88 | 494.189 | 546.051 | 329.954 | 40/40 |
| dispersed | 1,000 | 5x | 20 | 0.97.86 | 981.321 | 1073.165 | 351.653 | 20/20 |
| dispersed | 1,000 | 5x | 20 | 0.97.87 | 881.947 | 1930.334 | 341.500 | 20/20 |
| dispersed | 1,000 | 5x | 20 | 0.97.88 | 903.210 | 1317.648 | 347.357 | 20/20 |

All 2,000 swarm hulls survived; all dispersed samples ended with 977 hulls. Swarm median falls 24% across both changes, movement median 25%. Dispersed medians improve 8% across both changes but tail timings are variable and the second pass alone did not improve the median. Neither workload achieves the 100 ms batch budget; no FPS claim. Packed contact and separation are reusable phase-local computational batches, not authoritative storage.


## Packed steering candidates (v0.97.89)

Same Linux container, Godot 4.7.2, seed 827 and benchmark options as the preceding section. Sequential headless runs; shared-container timing variance remains. Full economy regression and original battle replay hashes at 50/100 ticks match.

| Scenario | Ships | Speed | Batches | p50 ms | p95 ms | Other movement p50 ms | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| swarm | 2,000 | 1x | 40 | 470.074 | 526.333 | 311.504 | 40/40 |
| dispersed | 1,000 | 5x | 20 | 938.362 | 1029.791 | 379.314 | 20/20 |

Swarm keeps 2,000 hulls and dispersed ends with 977, matching prior samples. Swarm median is 4.9% below v0.97.88 and 27.6% below v0.97.86; dispersed median is 3.9% higher than v0.97.88 despite a lower p95. No graphical FPS claim; both workloads miss the deadline. Packed steering slots are a derived snapshot, not authoritative state.


## Grouped vision coverage (v0.97.90)

Local Linux Godot 4.7.2, supplied v0.97.86 checkout plus the isolated vision patch. Compare original row-span kernel and grouped kernel in the same process, 15 alternating runs, seed 827, 2,000 randomly sampled source coordinates with 1000/1500 world-unit radii, duplicate cells collapsed. The dense case samples integer cells from [-30,30] on both axes, sparse [-200,200]. Exact mask equality verified.

| Workload | Unique cells | Coverage cells | Before median ms | After median ms |
| --- | ---: | ---: | ---: | ---: |
| Dense source union | 1537 | 8767 | 22.194 | 6.940 |
| Sparse source union | 1990 | 177979 | 57.657 | 54.267 |
| Stationary 2,000-fighter full vision (grouped uncached vs cached) | — | — | 9.931 | 6.040 |

The cache sample uses generated Grid map, two empires, 2,000 same-owner fighters sampled in a 4800×4800 world-unit square, advancing elapsed 0.1 per call. Structures remain live. The isolated patch passes focused coverage/diplomacy/removal/alias parity, full economy, worker and solo regression on the supplied older checkout; exact integrated main, ENet and graphics not rerun. No FPS or full-simulation throughput claim.


## Indexed Voronoi region queries (v0.97.91)

Godot 4.7.2 Linux, supplied v0.97.86 checkout with isolated vision/region patches, seed 827, eight-player generated maps. Each layout compares the indexed path with the original linear query on identical uniformly sampled positions, bin boundaries ±0.001 and adjacent site midpoints. All 85,276 queries match. One sequential timing of each workload; exact original site order/tie handling retained.

| Layout | Sites | Queries | Linear ms | Indexed ms | Mean candidates/bin |
| --- | ---: | ---: | ---: | ---: | ---: |
| Grid | 315 | 21286 | 420.472 | 36.573 | 14.04 |
| Radial | 288 | 21154 | 392.908 | 43.047 | 18.16 |
| Hex Grid | 368 | 21567 | 499.767 | 40.163 | 15.49 |
| Scramble | 298 | 21269 | 391.068 | 42.995 | 18.29 |

Grid index construction median of five runs 14.035 ms (whole geometry including index 266.592 ms in one separate run). Complete territory_influence on 2,000 synthetic fighters uniformly distributed across the Grid map, eight owners, fresh region cache each call, 15 alternating reference/indexed samples: median 44.022→9.723 ms; exact influence equality. These are not whole-simulation or graphical frame timings. Focused region/territory tests and worker regression pass on isolated local checkout. Main integration, ENet and graphical acceptance remain open.


## Retained private authority hull index (v0.97.93)

Local Godot 4.7.2 Linux; supplied v0.97.86 checkout with isolated retained-index and selective service query patch. Reproduce with `godot --headless --path . --script res://tests/retained_index_probe.gd`. 2,000 synthetic same-owner fighter dictionaries, eight requested hull IDs in scrambled order, 15 samples of 100 calls each; median per-call microseconds on same process, alternating unscoped and retained paths. Both paths include the same equality assertions; retained index construction is outside reuse measurements. Both service cases use the same hull-only structure-skip optimization. This is an isolated kernel/query comparison, not a whole-engine performance result.

| Query | Defensive scan/rebuild (µs) | Retained/indexed (µs) |
| --- | ---: | ---: |
| Stable-ID index preparation | 583.31 | 0.54 |
| Ownership validation, eight selected hulls | 200.40 | 12.66 |
| Service references, eight requested hulls | 385.41 | 18.90 |

The private scope built its roster index once in the probe. Focused lifecycle tests check launch/removal, live references, owner changes, mixed hull/structure target order, deadline restoration/expiry and scope teardown. Seed 827 400-hull battle replay with/without `--retained-hull-scope` matches complete state hashes at tick 50 (261 survivors, 2283687648) and tick 100 (198 survivors, 2608373067). Worker reference parity and 2-peer threaded ENet checks pass; existing ObjectDB exit warnings remain. Latest-main integration and combined fleet deadlines/FPS not measured. OPT-2 remains open: no canonical packed hot fields or stable dense slot compaction yet.


## Peaceful combat phase elimination (v0.97.94)

Godot 4.7.2 Linux, same supplied v0.97.86 checkout on Xeon Platinum 8573C (5 exposed logical CPUs) plus the existing v0.97.87 demand-driven combat-threat gate on both sides, with the isolated v0.97.94 patch on the second side. Affected combat source regions of v0.97.93 main were verified identical to the local pre-patch regions, and the resulting patch and added regression body match locally tested text. This does not establish whole-current-main runtime parity. Same seed 827, eight players, sequential reference then optimized samples, no concurrent benchmark/test runs. `tests/fleet_benchmark.gd` and `tools/profile_simulation.py` now accept opt-in `peaceful_mixed`: distinct neutral empires, dispersed fighters and roughly 10% miners/freighters distributed across the eight owners, fog disabled as for other fixtures. Default benchmark scenarios unchanged.

| Scenario | Ships | Speed | Batches | Path | Total p50 ms | Total p95 ms | Combat/repair p50 ms | Combat/repair p95 ms |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| swarm | 2000 | 1x | 20 | reference | 564.553 | 658.267 | 83.817 | 95.866 |
| swarm | 2000 | 1x | 20 | peaceful path | 545.184 | 784.261 | 50.259 | 88.718 |
| peaceful_mixed | 1000 | 5x | 12 | reference | 1072.342 | 1674.710 | 294.073 | 322.073 |
| peaceful_mixed | 1000 | 5x | 12 | peaceful path | 975.013 | 1822.525 | 197.310 | 400.960 |
| battle | 1000 | 1x | 12 | reference | 216.879 | 343.055 | 72.040 | 138.282 |
| battle | 1000 | 1x | 12 | patched fallback | 218.099 | 633.273 | 75.484 | 257.715 |

All samples retained the initial ship count, all batches missed 100 ms. Peaceful median combat/repair fell 40% (33.558 ms per 1x batch) and 33% (96.763 ms per 5x batch) respectively, while total medians fell 3.4% and 9.1%. Active battle total median rose 0.6%; tail times are worse in all three whole-batch samples. Small sample count and shared-container variation limit inference; do not claim improved tails, graphics or general speedup. Repeat same-machine integrated workloads for acceptance. Focused regressions verify exact serialized hull/structure state and threat snapshots with bilateral neutrality, legacy teams, cloaking, war declaration, previous target, pirates, explicit orders, hostile structures, retreat/move-only and mixed civilian readers. Full economy and actual worker, solo and 50/100-tick AI/battle reference replays pass on isolated checkout. Two-peer threaded ENet host and client returned PASS/exit 0; the host reported two ObjectDB instances leaked at exit. Native dependencies unavailable; full current-main integration remains open.


## Shared empty-rock halos and accepted sweep reuse (v0.97.95)

Godot 4.7.2 Linux, AMD EPYC 9V74 (5 reported logical CPUs; container CPU quota 4), supplied v0.97.86 checkout at 72d96f4 plus isolated patch. Verified exact affected source regions against v0.97.94 main before and after applying the patch. All comparisons use the same local checkout and seed 827, eight players, original fleet harness, sequential baseline and patched runs; no concurrent tests during performance runs. This is not a combined v0.97.95 main benchmark.

| Scenario | Ships | Speed | Batches | Path | Total p50 ms | Total p95 ms | Other movement p50 ms | Other movement p95 ms | Misses |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| swarm | 2000 | 1x | 16 | reference | 419.844 | 465.501 | 285.646 | — | 16/16 |
| swarm | 2000 | 1x | 16 | patched | 388.262 | 454.520 | 257.396 | 314.650 | 16/16 |
| swarm | 2000 | 1x | 20 | reference | 470.303 | 526.129 | 310.239 | 371.332 | 20/20 |
| swarm | 2000 | 1x | 20 | patched | 431.067 | 474.280 | 288.024 | 341.891 | 20/20 |
| dispersed | 1000 | 5x | 12 | reference | 677.266 | 715.400 | 220.144 | 255.058 | 12/12 |
| dispersed | 1000 | 5x | 12 | patched | 683.307 | 780.090 | 221.827 | 248.653 | 12/12 |

Swarm retains all 2,000 hulls, dispersed ends at 991 in both paths. Swarm total median improves 7.5% and 8.3% in two short sequential runs; repeat movement median improves 7.2%. Dispersed total median worsens 0.9%, p95 worsens; no universal improvement claim. All miss the 100 ms budget; no graphical measurements. Focused 600-case exact crowded navigation comparisons across cell boundaries/budgets plus cached-route and obstacle insertion/depletion parity pass. Full economy regression exits 0 with no script/assertion errors; seeded battle checkpoints match original at ticks 50 and 100 (261/198 survivors, hashes 2283687648/2608373067). Authority-worker and solo tests exit 0 and print PASS; solo reports two leaked ObjectDB instances at exit. Real 2-peer threaded smoke host/client exit 0 and print PASS. Current-main integrated validation, native build and performance acceptance remain open.

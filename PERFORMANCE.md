# Fleet performance baseline

Run from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/fleet_benchmark.gd -- --ships=500 --scenario=dispersed --ticks=100
```

Omit --ships or --scenario to run all five sizes (500, 1000, 2500, 5000, 10000) or all four scenarios (dispersed, battle, swarm, logistics). Options: --seed=827, --ticks=100, --speed=1 or --speed=5. Start with small isolated runs; dense cases may be expensive. Save FLEET_BENCH JSON lines and compare identical options/build configuration/hardware. Each sample is a batch of one or five 0.1-year simulation substeps; a deadline miss is a batch above 100 ms. Percentiles use nearest rank. Phase timing is existing simulation instrumentation, not an exhaustive breakdown; the slowest_tick field records the worst batch's index and phase times. Initial population is synthetic, not paid construction; casualties are not replaced and actual hull counts are reported. Static memory may be unavailable in release builds. No rendering, AI, ENet or background workload is measured by this harness.

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

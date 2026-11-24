# Fleet performance baseline

Run from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/fleet_benchmark.gd -- --ships=500 --scenario=dispersed --ticks=100
```

Omit --ships or --scenario to run all five sizes (500, 1000, 2500, 5000, 10000) or all four scenarios (dispersed, battle, swarm, logistics). Options: --seed=827, --ticks=100, --speed=1 or --speed=5. Start with small isolated runs; dense cases may be expensive. Save FLEET_BENCH JSON lines and compare identical options/build configuration/hardware. Each sample is a batch of one or five 0.1-year simulation substeps; a deadline miss is a batch above 100 ms. Percentiles use nearest rank. Phase timing is existing simulation instrumentation, not an exhaustive breakdown. Initial population is synthetic, not paid construction; casualties are not replaced and actual hull counts are reported. Static memory may be unavailable in release builds. No rendering, AI, ENet or background workload is measured by this harness.

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

Broader high-count/workload coverage, threaded ENet and graphical frame-time capture remain unverified. A native C++ source and SCons build recipe exist, but no `godot-cpp/` checkout, SCons, or C++ compiler is available in this environment, so native compilation was not attempted. Phase 1 remains open until representative graphical, mixed AI, production/repair/salvage and real peer tests are available. Record renderer, resolution, zoom, network conditions and hardware with those separate runs. Reference target: 60 FPS p95 and sustained 10 Hz at 1x with 5,000 hulls; do not infer this from headless results alone.

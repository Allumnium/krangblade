# Fleet performance baseline

Run from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/fleet_benchmark.gd -- --ships=500 --scenario=dispersed --ticks=100
```

Omit --ships or --scenario to run all five sizes (500, 1000, 2500, 5000, 10000) or all four scenarios (dispersed, battle, swarm, logistics). Options: --seed=827, --ticks=100, --speed=1 or --speed=5. Start with small isolated runs; dense cases may be expensive. Save FLEET_BENCH JSON lines and compare identical options/build configuration/hardware. Each sample is a batch of one or five 0.1-year simulation substeps; a deadline miss is a batch above 100 ms. Percentiles use nearest rank. Phase timing is existing simulation instrumentation, not an exhaustive breakdown. Initial population is synthetic, not paid construction; casualties are not replaced and actual hull counts are reported. Static memory may be unavailable in release builds. No rendering, AI, ENet or background workload is measured by this harness.

Baseline results: not yet measured. Phase 1 remains open until representative graphical, mixed AI, production/repair/salvage and real peer tests are available. Record renderer, resolution, zoom, network conditions and hardware with those separate runs. Reference target: 60 FPS p95 and sustained 10 Hz at 1x with 5,000 hulls; do not infer this from headless results alone.

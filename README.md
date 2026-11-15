# Warbound — planetary strategy RTS

Godot 4.7.2, GDScript, Compatibility renderer. Empire is the first of three intended playable races. Only Empire is implemented. ENet multiplayer uses UDP 24567 (LAN/Tailscale); no Steam dependency.

## Development sandbox

Run the project and select **SINGLE PLAYER**, or host/join a multiplayer lobby. Every new match receives a host-generated seed for a connected, irregular 17-planet graph with fixed routes. The planet count remains a prototype setting. Left-click a planet to inspect it without changing ownership. Build a **colony ship** at an owned planet's shipyard, select a reachable neutral planet, pick an idle colony ship, and click **SEND COLONY SHIP**. It follows friendly routes with a final leg to the neutral world; on arrival it is consumed to establish ownership. If another ship settles the destination first, the losing ship returns to its launch planet. No direct claim or hostile conquest is available. Right-drag or middle-drag on the map to pan, scroll to zoom at the pointer, and use RESET VIEW to fit the galaxy again. Cargo ships are directional markers; gold indicates loaded cargo, purple indicates colony ships, and docked fleets are counted. Each planet has a player owner and allies share surplus resources; only the owner can change its settings.

Select your home planet to queue a logistics ship. Each Empire player starts with one level-one shipyard. Queue extra shipyards, upgrades, and extraction upgrades in the planetary inspector. Select a queue item to cancel and refund it. Shipyards independently work on eligible ship jobs, release blocked jobs, and cannot construct ships while an upgrade is queued. Progress is proportional to materials allocated and construction work performed.

## Resources and logistics

The six universal resources are Metals, Plastics, Textiles, Organics, Tech, and Crystals. Metals, Plastics and Crystals have mixed planetary deposit availability, while Organics and Crystals have planetary bonus data. Each planet has one production level per resource. Only deposit extraction production is active; Tech, Textiles and Organics acquisition and advanced component recipes remain deliberately unspecified.

Inventories are planetary. Each resource has adjustable minimum import and maximum export targets, shared for own and allied traffic. Generic cargo ships carry mixed resources, choose a short reachable delivery greedily, travel physically along friendly fixed routes and collect surplus on arrival (no reservations or owner priority). Ships may have to reassess a delivery or wait while loaded if demand disappears. They never move goods through hostile or unclaimed planets. Ship production is currently queued at the home world.

All rates, costs, sizes, durations, starting inventory, bonus distributions and map count are **development-only values**, not finalized balance. They can be changed in scripts/economy_rules.gd and scripts/planet_map.gd. No other resource recipes are assumed.

## Architecture and validation

- scripts/planet_map.gd: seeded map, fixed edges and weighted pathfinding.
- scripts/economy_rules.gd: pure planetary ownership, resource production, thresholds, refundable construction, shipyard scheduling and physical cargo simulation.
- scripts/game_session.gd: shared offline/host-authoritative simulation and multiplayer snapshots, lobby/chat and synchronized load barrier.
- scripts/match.gd: planet map, cargo ship visualization and planetary inspector.
- tests/economy_rules_test.gd: map connectivity, resource and ownership rules, construction, shipyard scheduling and cargo logistics.
- tests/solo_smoke.gd: solo starts without ENet and resets cleanly.
- Existing lobby and two-/eight-player ENet regression tests remain in CI.

No military combat, AI opponents, advanced recipes, other races, manual trade-route overrides, final colonization balance, save games or Steam integration yet. Simulation runs at 10 Hz; full state snapshots publish at 5 Hz plus immediate command updates. Ship markers interpolate each render frame.

# Warbound — planetary strategy RTS

Godot 4.7.2, GDScript, Compatibility renderer. Empire is the first of three intended playable races. Only Empire is implemented. ENet multiplayer uses UDP 24567 (LAN/Tailscale); no Steam dependency.

## Development sandbox

Run the project and select **SINGLE PLAYER**, or host/join a multiplayer lobby. Every new match receives a host-generated seed for a connected, irregular 32-planet graph with fixed routes. The planet count remains a prototype setting. Left-click a planet to inspect it without changing ownership. Build a **colony ship** at an owned planet's shipyard, select a reachable neutral planet, pick an idle colony ship, and click **SEND COLONY SHIP**. It follows friendly routes with a final leg to the neutral world; on arrival it is consumed to establish ownership. If another ship settles the destination first, the losing ship returns to its launch planet. No direct claim or hostile conquest is available. Right-drag or middle-drag on the map to pan, scroll to zoom at the pointer, and use RESET VIEW to fit the galaxy again. Cargo ships are directional markers; gold indicates loaded cargo, purple indicates colony ships, and docked fleets are counted. Each planet has a player owner and allies share surplus resources; only the owner can change its settings.

Select your home planet to queue a logistics ship. Each Empire player starts with one level-one shipyard. Queue extra shipyards, upgrades, and extraction upgrades in the planetary inspector. Select a queue item to cancel and refund it. Shipyards independently work on eligible ship jobs, release blocked jobs, and cannot construct ships while an upgrade is queued. Progress is proportional to materials allocated and construction work performed.

## Resources and logistics

The six universal resources are Metals, Plastics, Textiles, Organics, Tech, and Crystals. Metals, Plastics and Crystals have mixed planetary deposit availability, while Organics and Crystals have planetary bonus data. Each planet has one production level per resource. Deposit extraction and provisional Organics production are active; Tech, Textiles and advanced component recipes remain deliberately unspecified.

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

## Presentation

Menu, lobby and match share the Godot Theme in `scripts/ui_theme.gd`. Six original SVG resource icons identify stock, levels, resource selection and construction material costs. The inspector groups activities into separate panels and displays the selected construction job's progress and material allocation. `assets/ui/starfield.gdshader` animates distant star layers independently of the simulation; the galaxy uses shaded planet discs, team-colored rings, a selection pulse, softly lit connections and ship engine trails. These are presentation-only and do not alter simulation or network rules.

## Population (prototype)

Population is stored per planet in people (fractional simulation values). Home worlds start with 10,000 people and new colonies with 1,000, with level-one Organics production. Farming potential (8 Organics/year per level, modified by planetary bonuses and a deterministic ±5% 100-year cycle) determines the equilibrium at 12,500 people per Organics/year, or 100,000 at baseline level one. Actual farming output scales with the square root of population/capacity up to full farming potential; residents consume 1 Organics/year per 12,500 people from local inventory. The critically damped response uses exact per-tick integration with response frequency 0.065/year and an exponential positive growth ceiling of log(2)/30 per year. Growth is blocked during food shortages and slows near equilibrium. Stored/imported Organics can feed residents but do not permanently increase the farming equilibrium. Active non-Organics output scales with population (10,000 = 1x). Organics upgrades follow normal construction rules. Colony starting size, farming support and output scale are provisional. The shared elapsed simulation clock starts at Year 1, advancing by one year per second.

## Galaxy controls and empire totals

WASD pans the galaxy in addition to right/middle mouse drag. Clicking empty map space deselects the planet and hides the inspector, expanding the map; selecting a planet reopens it. The persistent top bar shows all six resource totals (owned planetary inventories plus cargo aboard owned ships), total planetary population, completed craft and owned worlds. Hover resource totals for stock/cargo breakdowns, and craft for logistics/colony counts. Allied holdings and materials already allocated to construction are excluded. Keyboard panning is disabled while editing text or using a dropdown.

## Clustered galaxies and planetary upgrades

The worlds are arranged into four seeded, irregular clusters with sparse connecting routes. Homeworld indices are interleaved between clusters; final start fairness is not balanced. The inspector adds an Upgrades tab with individual cards for the six existing resource production systems, showing current level, next cost/duration, upgrade status and cancellation. Tech/Textiles remain inactive pending design. The names and effects of named upgrade lines are proposals only. A basic fighter hull (90 Metals, 36 work units, size 1) can be queued in Shipyards; it remains at its construction planet and is counted separately from logistics and colony ships. No combat, military movement orders or weapon statistics yet. Idle craft visually orbit their current planet; orbit does not change the simulation location. The camera projection remains constant when the inspector opens or closes, revealing or clipping the right side rather than recentering.

## Resource worlds and asteroid mining

The map contains 32 planets in four clusters with distance-weighted loops, plus up to ten asteroid fields that block potential shortcut routes without disconnecting the protected route backbone. Natural deposits weight the planet's color (silver Metals, orange Plastics, purple Crystals; green for Organics suitability). Planet size reflects aggregate natural richness (0.86–1.18x); ownership is shown by an independent ring. An independent advanced manufacturing environment bonus (1.0–1.6x) is visible but not applied until advanced recipes are designed. Mining ships (180 Metals, 60 work, size 1) automatically travel through friendly routes to a reachable owned service planet, fly a dedicated field spur, mine Metals/Crystals into a 60-unit hold, and return to unload. Each field supports a shared extraction ceiling of 400 times its richness per resource/year, versus a 200 per-resource/year planetary Metals/Crystals ceiling; actual delivered throughput depends on fleet size and transit time. No other resources, depletion or ownership of asteroid fields are assumed. All values are provisional.

## Streamlined match HUD

Planet overview and active shipyard progress bars are on the left; Economy, Trade, Shipyards and Upgrades tabs are on the right. Both hide on deselection without changing camera projection. Orbit counts and the persistent map legend are removed; idle craft face their direction of motion. Each resource total includes a signed net change per year, calculated from the authority's preceding five years of owned planetary stock and ship cargo (elapsed time during the first five years). Construction, consumption, mining and cross-owner transfers affect the rate; moving resources between owned planets and ships does not. Only calculated rates are synchronized, not sample histories.

## Distance and ship selection

Generated maps preserve their seeded cluster and obstacle geometry, then scale all world coordinates so the longest direct planetary link takes 100 years at the baseline ship speed (95 world units/year). Multi-leg journeys may exceed 100 years. The map fits its generated bounds and supports cursor-centered zoom up to 16x. Left-click a visible ship in transit or orbit to inspect its identity, owner, location/status, remaining route travel time and cargo where relevant. The right panel displays your empire's logistics, mining or colony fleet counts and cargo (where applicable). Military is a heading only pending design. Click a planet to restore its tabs, or blank space to close both panels. Ship selection uses the same visual poses as drawing and clears automatically if the ship is consumed.

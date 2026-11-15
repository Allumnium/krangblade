# Warbound — star-system strategy RTS

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

The map contains 32 planets in four clusters with sparse distance-weighted chains and occasional junctions, plus up to ten asteroid fields that block potential shortcut routes without disconnecting the protected route backbone. Natural deposits weight the planet's color (silver Metals, orange Plastics, purple Crystals; green for Organics suitability). Planet size reflects aggregate natural richness (0.86–1.18x); ownership is shown by an independent ring. An independent advanced manufacturing environment bonus (1.0–1.6x) is visible but not applied until advanced recipes are designed. Mining ships (180 Metals, 60 work, size 1) automatically travel through friendly routes to a reachable owned service planet, fly a dedicated field spur, mine Metals/Crystals into a 60-unit hold, and return to unload. Each field supports a shared extraction ceiling of 400 times its richness per resource/year, versus a 200 per-resource/year planetary Metals/Crystals ceiling; actual delivered throughput depends on fleet size and transit time. No other resources, depletion or ownership of asteroid fields are assumed. All values are provisional.

## Streamlined match HUD

Planet overview and active shipyard progress bars are on the left; Economy, Trade, Shipyards and Upgrades tabs are on the right. Both hide on deselection without changing camera projection. Orbit counts and the persistent map legend are removed; idle craft face their direction of motion. Each resource total includes a signed net change per year, calculated from the authority's preceding five years of owned planetary stock and ship cargo (elapsed time during the first five years). Construction, consumption, mining and cross-owner transfers affect the rate; moving resources between owned planets and ships does not. Only calculated rates are synchronized, not sample histories.

## Distance and ship selection

Generated maps preserve their seeded cluster and obstacle geometry, then scale all world coordinates so the longest direct planetary link takes 100 years at the baseline ship speed (95 world units/year). Multi-leg journeys may exceed 100 years. The map fits its generated bounds and supports cursor-centered zoom up to 16x. Left-click a visible ship in transit or orbit to inspect its identity, owner, location/status, remaining route travel time and cargo where relevant. The right panel displays your empire's logistics, mining or colony fleet counts and cargo (where applicable). Military is a heading only pending design. Click a planet to restore its tabs, or blank space to close both panels. Ship selection uses the same visual poses as drawing and clears automatically if the ship is consumed.

## Sparse route topology

The connected 32-world galaxy has 31 backbone routes and at most one optional local shortcut (35% chance, when a suitable unobstructed edge exists). A planet has at most three links, with at most six three-way junctions across the map. Local trees prefer short connections and extensions rather than branching; each starting slot has a neutral neighbor even in an eight-player match. Three intercluster bridges remain. Fully connected low-degree graphs necessarily have many degree-two worlds. The longest direct route still takes 100 years.

## Player-scaled galaxies and discovery

Each participant (including configured offline AI slots) receives a six-world starting cluster. Three clusters per participant; other clusters have normally sampled sizes centered on six (standard deviation 1.5, bounded 3–9). Sparse routes and the 100-year longest direct link are preserved. Single-player setup allows empty or AI slots and arbitrary teams; AI strategy is not yet implemented. Team-shared local surveys reveal the owned planet and its immediate neighbors, plus asteroid fields anchored at that owned planet. Unexplored planets and fields appear as question marks, with no inspector or resource/ownership details. This is presentation fog, not network secrecy: clients still receive the authoritative snapshot. Select discovered fields for approximate mineral composition and per-player enabled/Metals/Crystals checkboxes (all enabled by default). Mining ships obey those policies, and finish their return before selecting another enabled field. No new exploration ship or combat behavior assumed.

## Compact HUD and finite asteroid chunks

The single-row match HUD retains menu/reset, six resource totals and their rolling rates, population and year. Each existing planetary shipyard has a persistent activity row even when idle. Asteroid fields have irregular seeded outlines, variable sizes, and finite individually positioned and colored chunks of Metals or Crystals. Ships target specific permitted chunks and mine their remaining stock, bounded by the ship hold and the shared field extraction ceiling. Empty chunks disappear; partially mined chunks shrink. Miners return even with a partial hold if the target depletes or is disabled, and select a new target afterward. Field composition is calculated from remaining ore. Fields retain their conservative obstacle envelope and the original route graph after depletion; mineral amounts and field scale are provisional. No regeneration.

## Construction queue and mining duration

Each planet has five construction slots total including ongoing jobs. Shipyard upgrade orders wait in the shared queue for their specific yard and use fixed-duration upgrade work; they do not interrupt an active ship build. Future yards appear as construction progress rows until completed, when they become regular yard rows. Per-type Auto toggles replenish one queued hull of that type when a slot is available; switching off leaves the already queued order. Canceling an auto-produced order while Auto is enabled permits it to be queued again. Mining ships spend at least five years on site before returning, even if their hold fills or the selected chunk runs out earlier; trips canceled before reaching the chunk can return early. Multiplayer snapshots use compressed state on a dedicated reliable channel to reduce large-map traffic and separate lobby transitions.

## Star systems

Every graph node is a single star system for ownership, population, resources, logistics, construction and upgrades. Named systems replace planet terminology in the UI. At a distance the map shows a luminous star and team ring; close zoom reveals 2–6 animated decorative planets. Number is loosely driven by initial natural richness; planet hues sample local Metals, Plastics, Crystals and Organics suitability. A separate seeded visual RNG ensures stable layouts without changing economy generation. Visual planets are not separately claimable, selectable or simulated, and clicking within the system selects the system. The legacy internal `planets` key and map script names are retained to avoid unnecessary protocol churn. Shipyard cards in the left panel show individual levels, activity and an upgrade button for that specific yard; orders still share the five-slot queue. The right panel has build commands and no yard dropdown.

## Match menu and upgrade economy

The top bar has no reset button. Menu opens a modal with Resume and an explicit exit action appropriate to the match (main menu, return to lobby, or leave match); simulation continues while open. Every queued order has its own cancel/refund button, progress and allocated/required cost. All allocated resources are refunded on cancellation; continuous orders can be recreated if Auto remains enabled. Upgrade costs scale quadratically by target level: planetary production 150 × level² Metals, shipyard upgrades 180 × level² Metals. Construction durations and progressive allocation are unchanged. Costs are provisional; no unapproved advanced-material dependencies are added.

## Percentage trade thresholds

The Trade tab uses a single range slider per selected resource with import-below and export-above handles. Changes commit on release and are validated by the host. The 0–100% range refers to a fixed provisional 1,000-unit reserve reference, not a storage limit: the default 10%/20% preserves the previous 100/200-unit thresholds. Inventory may exceed 100%; any stock above the chosen export threshold remains eligible for trade. The population display no longer includes carrying capacity or a saturation bar; population and Organics simulation are unchanged.

## Production overview and repeat controls

The left system inspector shows current levels and gross annual production for all six resources. Only non-default natural production modifiers are listed, combining deposit abundance with resource bonus; 0% indicates no extraction deposit. Advanced manufacturing is identified as a future modifier and omitted at 100%. Repeat icon buttons toggle continuous ship production, system production upgrades and existing shipyard upgrades. Each enabled order maintains at most one corresponding queued job, with round-robin refill and the shared five-item queue. Disabled or unavailable targets are rejected by the authority. Turning repeat off leaves existing orders intact.

The Trade tab now displays all six resource range sliders together instead of a resource dropdown. Each slider has independent thresholds, a resource-colored live stock fill, and inventory numbers. Existing percentage semantics and host validation are unchanged.

## Cargo layout and exploration default

Cargo inspectors use non-wrapping numeric columns and bounded scrolling, with large fleet totals compacted. Fog of war is disabled in the authoritative match state by default: all systems, routes, fields and ships are visible, and fields can be configured by any participant. Existing ownership, allied path restrictions and mining reachability are unchanged. Discovery still tracks exploration, and the `fog_of_war` match-state flag can be enabled for future game setup options; no settings control yet.

## Versioning

The main menu displays the game version directly from `project.godot` (`application/config/version`). Starting at 0.1.0, every subsequent commit must increment MAJOR.MINOR.PATCH: patch for fixes and small changes, minor for new features, major for breaking milestones. Reset lower components when bumping a higher component. The validation workflow checks numeric ordering for every first-parent commit since the version was introduced (and verifies the current value on manual runs). Update `config/version` in the same commit; do not use a separate bump commit. Squash merges retain the branch's final version. CI reports failure if a subsequent commit omits a bump. The multiplayer regression host waits for all tested guests to finish and disconnect rather than exiting after an arbitrary delay.

Version 0.1.2: compact non-wrapping system production rows, 64× max zoom and distinctive procedurally shaded planet textures. Surface appearances remain cosmetic, seeded, and cached locally. No moons are simulated.

Version 0.1.3: consolidate system stock, production level and annual output into six compact left-panel rows. Population shows current count only. Reserve Economy for future manufacturing (empty until implemented). Trade stock values use non-wrapping right-aligned text with compact formatting and exact tooltips. No simulation changes.

Version 0.1.4: seed-stable unique sci-fi system names, predominantly specialized asteroid fields (50% single-resource, 40% strongly biased, 10% mixed by chunk count), themed match dialog, and build-card counts instead of the separate queue panel. No five-order cap; the underlying scheduler still allocates materials and work. Cancel one order via the cross on a build card (newest first), or via its upgrade/construction card; any matching repeat flag is cleared on the authority. Other already queued orders remain. Upgrades remain limited to one pending order per target.

## Project working instructions

Read [AGENTS.md](AGENTS.md) before contributing or starting a new coding session. It records standing workflow, terminology, UI, and validation conventions; later explicit decisions supersede older notes.

Version 0.1.6: maximum three completed or pending shipyards per system, enforced by the host and reflected in the build button. Halve base production (8 to 4 per level), farm output and food demand (preserves population capacity), planetary metal/crystal ceiling (200 to 100), asteroid field ceiling (400 to 200 times richness), and miner extraction speed (12 to 6 times richness). Starting inventory, deposits, cargo capacity, travel speed and construction costs remain unchanged. Provisional balance tuning.

Version 0.2.0: unowned systems have contextual right-panel actions, rather than owner-only tabs. Neutral outposts are free player-specific declarations, reachable from home through allied owned systems and other declared outposts. Colonization clears declarations at that system; breaking a connection can leave disconnected objectives dormant. Frontiers are outermost declared objectives along outward shortest-hop routes. Fighters either patrol from home along randomly chosen outward branches and return, or station at a selected frontier. Equal branch alternatives use uniform random choice. Fleet-type allocation is host-authoritative; frontier percentages sum to 100 via proportional integer redistribution, hull counts use largest remainder. Changes take effect after the current leg/route finishes, with a saved return path for disconnected objectives. Selecting an owned fighter enables a toggleable combat lens marking outpost and frontier names. No combat, conquest, economic outpost benefits, or logistics overlay metrics yet.

Version 0.2.2: repeat hull orders join the tail of the shared construction schedule and take turns without overtaking an earlier repeat hull waiting for materials. Multiple shipyards may work consecutive turns in parallel. Manual orders and independent/targeted upgrades retain their existing eligibility rules; canceling an order still stops its repeat flag.

Version 0.2.3: explicit shared repeat cycles guarantee round-robin hull start order even across shipyards with different speeds. A new cycle may start when all previous turns have been assigned and a shipyard becomes free, without waiting for every prior hull to finish. Separate infrastructure upgrades do not advance the hull cycle.

Version 0.2.4: resource-colored HUD tiles fill in proportion to local system inventory summed across the empire, against 1,000 units per resource per owned system (provisional display reference, not a storage cap). Zero capacity has no fill. Outposts can be declared on any discovered neutral system; disconnected nodes are dormant and visibly marked until connected. Top-center military/logistics toggles are mutually exclusive and independent of selection. Military labels outposts/frontiers; logistics displays local resource stock bars and zoomed icon/quantity grids. No changes to production, storage rules or combat.

Version 0.3.0: replaces outposts, patrols and frontier controls with direct force distribution over every discovered star system and asteroid field. Military lens has an interactive percentage slider over each POI. Defaults to 100% home, redistributes others proportionally on edit; when a sole remote destination is reduced the remainder returns home. Ship quotas use largest remainder. Nearest available hull/POI pairs are assigned by remaining routed distance on fleet or allocation changes. Fighters traverse existing lanes regardless of ownership and field approach legs; reversing uses remaining edge distance with no teleportation. No combat damage yet. Logistics lens unchanged.

# Warbound — star-system strategy RTS

Godot 4.7.2, GDScript, Compatibility renderer. Empire is the first of three intended playable races. Only Empire is implemented. ENet multiplayer uses UDP 24567 (LAN/Tailscale); no Steam dependency.

## Source ownership map

Current layout (v0.91.5; update when responsibility moves). Use the named functions as search anchors rather than line numbers. This is the development map, not a description of planned gameplay.

| File | Owns / where to look |
| --- | --- |
| `project.godot`, `scenes/main.tscn`, `scenes/match.tscn` | Application config/version, GameSession autoload and scene entry points. |
| `scripts/economy_rules.gd` | Authoritative simulation and canonical dictionaries: `create`, `step`; resource/population rules, recipes and queues (`building_cost`, `_work_station_queue`, `_work_planet`); cargo/mining and service (`_work_ship`, `_work_miner`, `_choose_delivery`); navigation (`_manual_travel`, `patrol_node` for free-space exact orders; `_military_paths` compatibility adapter for direct fleet deployments; `_path`, `_mining_path` for legacy civilian routes); commands and orders; diplomacy (`diplomatic_relation`, `diplomacy_*`); combat and repair (`_combat`, `_prepare_withdrawals`); AI (`_ai_turn`, `_ai_diplomacy_turn`); objectives/rewards (`_update_objectives`, `_assign_category_objectives`). |
| `scripts/game_session.gd` | Persistent lobby and match lifecycle, authority and ENet. `request_*` → `_rpc_*`/authority dispatch → simulation rules; `_economy_tick`, `_encode_replica`, `_rpc_economy` and motion roster handle timing and transport. Keep RPC endpoints on this persistent node. |
| `scripts/match.gd` | Client match controller; `_build_ui` orchestrates named map, header, dialog, deck, inspector and Trade builders; `_refresh`, command cards/inspectors, input and selection, camera/projection, rendering (`_draw_map`, ship/station draw helpers), fog/territory, tactical alert presentation (`_sync_tactical_alerts` delegates to tracker), Empire/diplomacy and conquest UI orchestration. Never the owner of simulation mutations. |
| `scripts/ui_text.gd` | Shared display naming, numeric formatting, weapon/ship summaries and read-only economy building previews; used by match and Codex. |
| `scripts/command_card_ui.gd` | Shared command-card grids, reserved slots, button faces, upgrade badges, hints and a single anchored instant command-information panel; owns per-match command icon cache. Match retains card-specific actions, layout decisions, hotkey registrations and selection. |
| `scripts/camera_view.gd` | Client camera state, zoom limits/steps, pan, world/screen projection and selection framing math. Match supplies playfield geometry and selection targets; retains input routing. |
| `scripts/system_geometry.gd` | Pure deterministic body generation, orbital position and system radius queries; economy_rules retains facade and balance constants. |
| `scripts/sector_geometry.gd` | Immutable bounded Voronoi cells, shared borders, region lookup and exact segment permission tests. Economy owns cached geometry for hidden navigation and influence. |
| `scripts/territory_view.gd` | Cached building-only radial ownership fields, GPU smooth territory contours, matching minimap samples, last-observed infrastructure and separate legacy friendly warning destinations. Match supplies camera geometry, fog binding and player colors. |
| `scripts/fog_of_war.gd` | Per-client live/explored vision cells, revision checks, mask texture and map fog rendering. Match supplies player, motion revision, camera geometry and territory shader bindings; minimap shares the mask. |
| `scripts/hull_art.gd` | Authored hull geometry, cargo bay positions, hull/portrait/shield SVG generation and per-match texture caches; map drawing and selection consume the same geometry. |
| `scripts/command_hotkeys.gd` | Command registration, key scope/conflicts, persisted override loading, hotkey badges and dispatch; match_settings owns editor dialog and settings save. |
| `scripts/match_settings.gd` | Local config persistence, audio/camera preferences and hotkey editor; match supplies widget factories, viewport, music and registry, retains menu lifecycle and input. |
| `scripts/construction_queue_view.gd` | Construction queue flow layout, tile reconciliation, progress/blocker styling and job names; match supplies row caches, icons and cancellation callback. |
| `scripts/trade_range.gd` | Two-handle trade threshold control, stock display, drag/commit signal; controller supplies policy and dispatches authority requests. |
| `scripts/cost_button.gd` | CostButton widget: recipe/shortfall state and compact graphical information-panel content; no native custom tooltip. Match supplies costs, crew icon and hotkey hints. |
| `scripts/tactical_alerts.gd` | Client-only alert detection, lifetime/cooldown, previous durability/positions and sequence tracking; `sync`/`reset`. Match controller owns visibility/projection callbacks, friendly sector inputs, drawing and click-to-camera behavior. |
| `scripts/planet_map.gd` | Deterministic map generation (`generate`), layouts, graph edges, `path`, `route_length`. Simulation-specific route policy currently lives in economy_rules. |
| `scripts/main.gd`, `scripts/lobby_rules.gd` | Menu/lobby/setup presentation; shared lobby roster, ready, color and start rules respectively. |
| `scripts/ui_theme.gd`, `scripts/space_background.gd`, `assets/ui/starfield.gdshader` | Reusable theme, icons, UI surfaces and backdrop. |
| `scripts/codex.gd`, `scripts/match_sfx.gd` | Concise player guide derived from rules where possible; client-only audio synthesis, spatial gain and cue limits. |
| `scripts/match_audio_tracker.gd` | Per-match snapshot audio history, construction and completion cue detection, objective cue coalescing, combat/service sound edges. Match supplies local player, spatial context, visibility callback and mixer; no gameplay mutations. |
| `scripts/match_developer_tools.gd` | Local Perf overlay, sampling history, local slash command dispatch, developer mode and speed buttons embedded in shared chat. Match supplies session and widget factories, retains modal/input routing and deck geometry. Session validates speed changes and owns replicated metrics. |
| `scripts/match_notice_ui.gd` | Local chat/notification history, scroll panel, deduplication, fade and warning hit rectangles. Match supplies map/minimap geometry, player and alert inputs, camera jump callback and routes chat/keyboard. |
| `scripts/match_conquest_ui.gd` | Objective headers and counters, refresh/upgrade controls, collapsible lifetime CP scoreboard, upgrade dialog, card signature and pulse. Match supplies overlay, layout and player/color/icon queries, retains overlay draw order. Simulation and session own goals, rewards and authoritative requests. |
| `scripts/match_empire_ui.gd` | Local Empire window, fleet sliders and counts, diplomacy rows and war confirmation. Match supplies player/color/portrait/label queries, routes input and determines attack intent; GameSession validates all diplomacy and fleet commands. |
| `scripts/match_resource_hud.gd` | Resource/year/population/credit header, storage strips, resource delta formatting and local/global hover details. Match supplies selection widgets and snapshot/player/system-name queries; uses the same delta helpers for the inspector. No authority mutations. |
| `scripts/ship_motion_view.gd` | Client interpolation samples, acceleration-derived thrust, heading smoothing and shared per-frame world pose cache. Match supplies session, visibility and projection, drives cache invalidation and draws hulls/minimap/effects. No authority or transport mutations. |
| `scripts/world_render_batches.gd` | Per-match GPU MultiMesh nodes, instance queues, shaders, texture/extent caches, buffer packing and capacity growth for hulls, beams, projectiles, exhaust, cargo, health and selection rings. Match supplies projected geometry and preserves reset and flush order. |
| `scripts/celestial_view.gd` | Per-match system body and spacing cache, planet fades, predicted orbital clock, star/body textures, orbit/PDS art and asteroid mesh generation/lifetime. Match supplies projection and draw context; retains visibility, picking, system draw order and production delivery choreography. |
| `scripts/world_effects.gd` | Per-match destruction event history, seeded hull fragments/sparks, laser and blaster drawing, cargo transfer animation history. Match supplies projection, public visual queries, target/bay resolution, timing and GPU submission context; authority state and draw order unchanged. |
| `scripts/planet_traffic_view.gd` | Visual-only planetary production and upgrade-delivery cargo pods; shared read-only production source/rate queries. Match supplies projection, station radius, job icons and draw order. |
| `scripts/structure_view.gd` | Station hub, storage bays, job icons/progress, drydock/shipyard art, construction and colony conversion animation; shared bay point geometry for cargo/production effects. Match supplies selection, projection, scale, health drawing and visibility; no new authoritative state. |
| `scripts/order_view.gd` | Client dashed order routes, shared group intent, target rings, numbered queued command chains above fog, hull ghosts and drag formation previews. Match supplies projection, geometry and selection queries, owns formation order generation and dispatch; simulation rules remain authoritative. |
| `scripts/minimap_view.gd` | Minimap coordinate conversion, pointer drag tracking, entity/field/salvage hit hints and drawing of presence, fog, ships and camera bounds. Match owns widget layout, modal gates, command dispatch and camera updates; shares existing fog, territory and motion caches. |
| `scripts/logistics_view.gd` | Logistics lens toggle, station resource/population overlays and shipment aggregation/arrows. Match supplies widget factories, projection, shared celestial geometry and player queries; existing simulation routing and visibility predicates unchanged. |
| `scripts/control_group_manager.gd` | Local control group storage, membership pruning, additive assignment and button presentation. Match retains selection application and recall timing/layout. |
| `scripts/selection_inspector.gd` | Selected entity portrait, health/shield labels, weapon readouts and multi-ship tile grid/cache; shared tile style for building groups. Match retains selection/focus, detailed entity panels and authority commands; supplies existing hull and health queries. |
| `scripts/match_session.gd` | Small roster holder; not configured as the current autoload. Check remaining references before changing/removing it. |
| `tests/economy_rules_test.gd`, `tests/lobby_rules_test.gd` | Rule regressions, seeded maps and semantic fixtures. |
| `tests/solo_smoke.gd`, `tests/network_smoke.gd` | Real match lifecycle, authority, state replication and ENet peers. |
| `tests/fleet_benchmark.gd`, `tests/contested_benchmark.gd`, `PERFORMANCE.md` | Fleet-scale and contested simulation measurement. |
| `tools/check_gdscript.py` | Discover and parse every tracked `.gd` file; run locally after `godot --headless --path . --import` using `python3 tools/check_gdscript.py` (optional `--godot /path/to/godot`). |
| `.github/workflows/godot-validation.yml` | Version/indentation, import/metadata, parse, core and peer checks; currently manual dispatch only. |

### Intended dependency direction

- Commands: main / match UI → GameSession → validated simulation dispatch.
- Snapshots: GameSession → main / match UI (read-only).
- Rule queries: main / match UI → simulation (read-only costs, eligibility, relationships).
- Simulation → map / domain rules.

Do not make the simulation depend on UI or network transport. UI and AI must not reimplement authoritative eligibility or costs. Replicas and visual caches are derived; canonical gameplay state is mutated only by host/solo authority. Keep simulation step ordering, seeded randomness and cache lifetimes explicit.

### Where to add a feature

Search the existing owner and callers first. For a new gameplay command, extend the authoritative rule, session request/validation, and UI dispatch, then add focused rule/peer coverage and update Codex. For a change to a recipe or relationship, modify its canonical rule and reuse it in UI/AI. For a visual-only change, keep it within the client. The [refactoring backlog](TODO.md#code-organization-and-maintainability) records proposed module boundaries; files listed there do not exist until extracted.

## In-game reference

Open the question-mark button beside Menu to browse the searchable Warbound Codex, including population and food graphs, resource logistics, construction, combat, expansion and controls. All figures are illustrative or derived from current game constants; the guide does not pause the simulation.

## Current economy — v0.45.3

Base population doubling time is 60 simulation years, including orbital recovery. Terrestrial positive growth is multiplied by clamp(local Organics stock / 200 t, 0, 1), independent of warehouse level or trade thresholds, in addition to existing habitation, food availability and damped capacity constraints. Orbital habitats remain self-sufficient and exempt from the stock modifier. Show food growth penalty on population hover; preserve existing crew and construction costs.


Three standard resources (Metals, Organics, Crystals), plus reserved raw antimatter and population. Remove Plastics/Textiles and Tech; ordinary hulls use Metals and Organics, foundational storage/housing uses Metals, advanced PDS/additional shipyards/Laser Matrix use Crystals. Crystal production starts locked and is unlockable at a planetary deposit with a Metal-funded Crystal Incubator; asteroid extraction, physical transport, salvage, trade thresholds, local stock, population, and authority remain. Metal Refinery costs Organics; Farms cost Metals. No new antimatter recipes. Values provisional.

Earlier gameplay notes below are historical where superseded by the current economy.

## Gameplay notes — v0.19.0

Select owned fighters or colony ships by clicking or dragging a box; Shift-drag adds and Shift-click toggles. Ctrl+1–9 stores a control group, 1–9 recalls it, and Shift+number adds it. Right-click a discovered system or asteroid field to order fighter movement along the lanes; selected ships show their routes. H or Hold position stops selected fighters in place, including mid-lane, while retaining weapon fire and emergency repair withdrawal. Fighters automatically engage nearby hostiles and repair when safe, and direct occupation can capture hostile systems after their defenses are destroyed. Right-click a neutral system to send one eligible selected colony ship. Middle-drag pans; scroll zooms. Miners are autonomous by default: select them like fighters, right-click a discovered permitted field or individual rock to assign it, or right-click a system to restore automatic mining. They deliver cargo before returning to their assigned field; depleted assignments fall back to autonomous mining. Freighters remain autonomous. All material costs are paid from local stock before a construction or upgrade order is accepted; cancellations refund prepaid materials, and crew allocation and construction work remain gradual. Repeat and maintain orders wait for full local funding. Policy cards, regional allocation, warmup and the separate Upgrades tab are removed. Repeatable Economy buildings expand output, can bootstrap Crystal production, never cost their own output, and use fixed local recipes. The Economy tab also contains PDS, habitation and warehouse development. Nonfood construction reserves cover the next warehouse tier; a stronger early habitation penalty protects recovery. Colony hulls embark 40,000 settlers, reserving at least 500 residents for their origin shipyard. Plastics/Textiles/Tech baseline output doubles, freighters carry 100 t across ten 10 t bays and miners carry 10 t (v0.53.3), and hull Organics costs fall by two-thirds. Earlier version notes below describe historical behavior, not current controls.

## Development sandbox (historical)

Run the project and select **SINGLE PLAYER**, or host/join a multiplayer lobby. Every new match receives a host-generated seed for a connected, irregular 32-planet graph with fixed routes. The planet count remains a prototype setting. Left-click a planet to inspect it without changing ownership. Build a **colony ship** at an owned planet's shipyard, select a reachable neutral planet, pick an idle colony ship, and click **SEND COLONY SHIP**. It follows friendly routes with a final leg to the neutral world; on arrival it is consumed to establish ownership. If another ship settles the destination first, the losing ship returns to its launch planet. No direct claim or hostile conquest is available. Right-drag or middle-drag on the map to pan, scroll to zoom at the pointer, and use RESET VIEW to fit the galaxy again. Cargo ships are directional markers; gold indicates loaded cargo, purple indicates colony ships, and docked fleets are counted. Each planet has a player owner and allies share surplus resources; only the owner can change its settings.

Select your home planet to queue a logistics ship. Each Empire player starts with one level-one shipyard. Queue extra shipyards, upgrades, and extraction upgrades in the planetary inspector. Select a queue item to cancel and refund it. Shipyards independently work on eligible ship jobs, release blocked jobs, and cannot construct ships while an upgrade is queued. Progress is proportional to materials allocated and construction work performed.

## Resources and logistics

The universal resources are Metals, Organics and Crystals. Metals and Crystals have planetary deposit availability, while Organics and Crystals have planetary bonus data. Each system has local production levels and inventory. Raw antimatter remains separate and has no construction recipe.

Inventories are planetary. Each resource has adjustable minimum import and maximum export targets, shared for own and allied traffic. Generic cargo ships carry mixed resources, choose a short reachable delivery greedily, travel physically along friendly fixed routes and collect surplus on arrival (no reservations or owner priority). Ships may have to reassess a delivery or wait while loaded if demand disappears. They never move goods through hostile or unclaimed planets. Ship production is currently queued at the home world.

All rates, costs, sizes, durations, starting inventory, bonus distributions and map count are **development-only values**, not finalized balance. They can be changed in scripts/economy_rules.gd and scripts/planet_map.gd. No other resource recipes are assumed.

## Architecture and validation

Automated validation targets gameplay rules, authority, parsing, startup and session lifecycle, not widget layout or appearance. UI changes are verified through manual playtesting. The detailed map-view smoke test was retired in v0.16.20.

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

Population is stored per planet in people (fractional simulation values). Home worlds start with 10,000 people and new colonies with 1,000, with level-one Organics production. Farming potential (8 Organics/year per level, modified by planetary bonuses and a deterministic ±5% 100-year cycle) determines the equilibrium at 12,500 people per Organics/year, or 100,000 at baseline level one. Actual farming output scales with the square root of population/capacity up to full farming potential; residents consume 1 Organics/year per 12,500 people from local inventory. The critically damped response uses exact per-tick integration with response frequency 0.065/year and an exponential positive growth ceiling of log(2)/30 per year. Growth is blocked during food shortages and slows near equilibrium. Stored/imported Organics can feed residents but do not permanently increase the farming equilibrium. Active non-Organics output scales with population (10,000 = 1x). Organics upgrades follow normal construction rules. Colony starting size, farming support and output scale are provisional. The shared displayed calendar starts at 2850 A.D., advancing by one year per simulation second.

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

The single-row match HUD retains menu/reset, six resource totals and theoretical annual net rates, population and year. Each existing planetary shipyard has a persistent activity row even when idle. Asteroid fields have irregular seeded outlines, variable sizes, and finite individually positioned and colored chunks of Metals or Crystals. Ships target specific permitted chunks and mine their remaining stock, bounded by the ship hold and the shared field extraction ceiling. Empty chunks disappear; partially mined chunks shrink. Miners return even with a partial hold if the target depletes or is disabled, and select a new target afterward. Field composition is calculated from remaining ore. Fields retain their conservative obstacle envelope and the original route graph after depletion; mineral amounts and field scale are provisional. No regeneration.

## Construction queue and mining duration

Each planet has five construction slots total including ongoing jobs. Shipyard upgrade orders wait in the shared queue for their specific yard and use fixed-duration upgrade work; they do not interrupt an active ship build. Future yards appear as construction progress rows until completed, when they become regular yard rows. Per-type Auto toggles replenish one queued hull of that type when a slot is available; switching off leaves the already queued order. Canceling an auto-produced order while Auto is enabled permits it to be queued again. Mining ships spend at least five years on site before returning, even if their hold fills or the selected chunk runs out earlier; trips canceled before reaching the chunk can return early. Multiplayer snapshots use compressed state on a dedicated reliable channel to reduce large-map traffic and separate lobby transitions.

## Star systems

Every graph node is a single star system for ownership, population, resources, logistics, construction and upgrades. Named systems replace planet terminology in the UI. At a distance the map shows a luminous star and team ring; close zoom reveals 2–6 animated decorative planets. Number is loosely driven by initial natural richness; planet hues sample local Metals, Plastics, Crystals and Organics suitability. A separate seeded visual RNG ensures stable layouts without changing economy generation. Visual planets are not separately claimable, selectable or simulated, and clicking within the system selects the system. The legacy internal `planets` key and map script names are retained to avoid unnecessary protocol churn. Shipyard cards in the left panel show individual levels, activity and an upgrade button for that specific yard; orders still share the five-slot queue. The right panel has build commands and no yard dropdown.

## Match menu and upgrade economy

The top bar has no reset button. Menu opens a modal with Resume and an explicit exit action appropriate to the match (main menu, return to lobby, or leave match); simulation continues while open. Every queued order has its own cancel/refund button, progress and allocated/required cost. All allocated resources are refunded on cancellation; continuous orders can be recreated if Auto remains enabled. Upgrade costs scale quadratically by target level: planetary production 150 × level² Metals, shipyard upgrades 180 × level² Metals. Construction durations and progressive allocation are unchanged. Costs are provisional; no unapproved advanced-material dependencies are added.

## Percentage trade thresholds

The Trade tab uses a single range slider per selected resource with import-below and export-above handles. Changes commit on release and are validated by the host. The 0–100% range refers to actual local warehouse capacity. The default is to import below 50% and export above 80% (1,000 t and 1,600 t at base storage). Explicit AI trade settings and player overrides remain possible. The population display no longer includes carrying capacity or a saturation bar; population and Organics simulation are unchanged.

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

Version 0.3.1: ENet smoke test host waits for an authoritative completion acknowledgment from every independently verified peer before returning to the lobby, instead of a fixed match-duration timer. No gameplay changes.

Version 0.4.0: AI players issue real construction, trade, resource and colonization orders every four game years; prioritize reachable neutral worlds, local production, logistics, mining, and fighters. Fighters seek hostile fleets then hostile systems through existing POI allocation. All ships have 100 HP; fighters use 18-damage lasers every game year at 180 world-unit range, pause movement during engagements, and resolve simultaneous damage without friendly fire. No resource cheats, hostile-system conquest, retreat command or territorial shading yet. AI and combat numbers are provisional.

Version 0.4.1: early AI build priorities explicitly save for their next objective, establish colony/fighter/logistics/mining hulls before secondary investment, and choose reachable colony destinations via one weighted traversal. Every living ship in replicated state has a rendered pose, irrespective of ownership, discovery, idle/travel/mining/combat state. Team-colored hull outlines retain class and cargo colors. Added generated-map early AI production and all-ship rendering regressions.

Version 0.4.2: always-visible subtle team territory overlay using bounded Voronoi-like nearest-POI regions, merged same-team masks, rounded soft borders and very faint fill. Owners and stationary fighters establish visual control; hostile fighter presence or active combat removes affected sectors. No gameplay ownership change. Cache the spatial lookup and regenerate masks only when claims change. Orbit rings and system/home circles appear only for the selected system; travel lanes use a thin low-opacity stroke. Decorative bodies remain visible at close zoom.

Version 0.4.3: ship hulls, engine effects and cosmetic offsets scale in world space. Orbit and route offsets and headings blend continuously across state transitions; thrust is suppressed at wide zoom. Simulation rules unchanged.

Version 0.89.22: debug-build-only pause, 1×, 2× and 5× controls in the shared chat panel after `/devmode` (v0.89.64) (supersedes the v0.5.0 HUD placement). Only solo or the host changes the speed; guest requests are rejected at authority; debug-console controls show the authoritative selection. Each match starts at 1×. Pause stops simulation while preserving UI and command handling. Faster speeds execute multiple fixed 0.1-year steps per timer tick, with unchanged real-time snapshot cadence. Decorative orbital movement follows game speed; ship interpolation may briefly settle on pause. Solo and real two-/eight-peer regressions exercise speed controls, authority and replication.

Version 0.6.0: authoritative ship world positions, headings and navigation targets are replicated. Lane travel, reversals and mining approach/return advance through a bounded movement integrator; route changes do not relocate ships. Combat uses the same positions that clients interpolate and draw, regardless of route or POI metadata. Fighter station spacing is physical; other idle ships park rather than using independent cosmetic orbits. Existing lane restrictions, ship speed, combat range, mining and delivery rules are retained. No collision avoidance, acceleration or free-flight routing yet. Added position, speed-bound, reversal, combat-distance and replicated render-target regressions.

Version 0.7.0: colony ships can colonize any discovered neutral system via existing shortest lanes, passing through neutral or hostile systems without claiming them; AI uses the same permissions. Replace channel-packed territory shader masks with direct, visible team-colored RGBA fill and outlines (14% fill, 76% rim). Idle ships also navigate to distinct physical parking positions; service jobs dock before transfer. Added distant colony and actual territory pixel checks.

Version 0.7.1: parallel CI validation. Core tests and the four existing ENet scenarios run independently; the aggregate `validate` job succeeds only when all pass. Superseded workflow runs on the same ref are cancelled. No gameplay or regression-coverage changes.

Version 0.8.0: analytic circular territory influences with rounded smooth unions, consistent median-spacing radius, smaller field influences, neutral exclusions and crisp screen-space antialiasing at any zoom. Site data is cached by claims; no low-resolution spatial raster. AI fighters rally at home and launch together in waves of at least three, reserving reinforcements until the next wave. Existing lane navigation and human allocation unchanged. Added territory data and AI rally/launch/reserve/regroup regressions.


## v0.11.0 — Population-based industry (prototype)
Home systems begin at level one in the five non-Crystal resources; no initial Crystal production and stock 1,650 Metals, 360 Plastics, 240 Textiles, 300 Organics and 240 Tech. All hulls consume those five resources progressively; a mixed twelve-ship fleet fits within starting inventory. Textiles and Tech yield 0.5 units per year per level per 10k population, Plastics has the same baseline with natural abundance as upside, while Metals and Crystals retain deposit-based extraction. Organics retains food and population feedback. New colonies receive baseline industrial levels but no free stocks. Resource upgrades require 1k population at level one, then 10k per prior level, except Tech needs 200k for level two and an additional 200k per level thereafter. Economy buildings are instant permanent local purchases, one of each, improving resource output by 25% (farm potential for Organics); mineral ceilings still apply. AI construction funding checks all resources. No complex manufacturing recipes or upkeep yet. All values are provisional.


v0.11.1: 2,000-unit storage per resource; warehouse upgrades raise capacity to 5,000, 12,000 and 30,000. Non-Crystal population demand is linear (Metals 0.1, Plastics/Textiles/Tech 0.25, Organics 0.4 per 10k population per game year). Growth is capped; cargo remains onboard if storage is full. Refunds are preserved even if temporarily above capacity. Crystal deposits remain naturally generated, with no initial production. Numbers provisional.

Industrial labor ceiling (v0.11.3): production of Plastics, Textiles and Tech scales with population until 100k residents per local production level; demand continues scaling linearly, allowing equilibrium below storage capacity.


v0.12.2: Shipyards is the default first tab; all three shipyard slots and construction live in the left overview. All hull material costs triple with unchanged starting inventory. Second shipyard costs 2,000 Metals, 500 Plastics, 500 Textiles, 200 Organics, 100 Tech, 100 Crystals. Third costs 3× that; first retains the 480-Metals recipe. Slot numbering is reserved at enqueue and completion is sequential.


v0.12.3: Production and individual shipyard upgrades use exponential costs, 200 × 3^(level−1) and 240 × 3^(level−1) Metals respectively. Warehouse upgrades cost 500/1,500/4,500 Metals plus proportional Plastics (80/240/720) and Tech (40/120/360). One-time economy buildings cost three times their previous prices; they are still independent and purchasable only once per system. Construction durations, population gates, starting inventory, hull and new shipyard recipes are unchanged.


v0.12.4: Inline compact Build buttons and icon costs replace the shared shipyard build control. Only the next vacant slot offers construction. Pending shipyards can progress concurrently but activate in slot order. Cancelling an earlier order fully refunds that order, promotes later orders at their existing completion percentage and refunds their excess allocation at the cheaper slot cost.


v0.12.6: Collapsible ship, production, factory, warehouse and shipyard upgrade details, icon recipes and unmet requirements. Population is a gradual hull construction cost (fighter 10, logistics 20, miner 30, colony 1,000), refunded on cancellation. Completed colony ships deliver their settlers to the new system; no crew upkeep or demobilization. Population cannot be spent below one resident.


v0.12.7: Amber resource-blocked progress, inline resource modifiers, wider system overview and owner badge. Lobby players pick unique colors from eight swatches; host validates all requests. Map control and hull outlines follow player colors independently of team rules.


v0.13.0: Five starter hulls per player (three miners, two fighters). PDS construction in Upgrades, one per visible seeded planet, one pending per system. First recipe: 540 Metals, 120 Plastics, 60 Textiles, 60 Organics, 60 Tech; subsequent recipes 3× each. 36 years construction, 36 damage/shot at fighter range and cadence. System-centered authoritative range, planetary metallic frame and beam visuals. No separate PDS destruction mechanic yet.


v0.13.3: Compact inline actions, shared population icon, shipyard staffing (500/5k/20k), neutral asteroid access with owned-depot delivery.


v0.13.8: Solo roster defaults to four, unique selectable colors, add/remove AI, dynamic teams, bottom-left Start and top-right Back. Resource quantities use metric tons and expandable cards reset on tab exit.


v0.13.9: Multiple nearby system approaches to asteroid fields, physical arrival-only cargo delivery, live per-system resource hover with last-step actual production/consumption/construction/dock transfers; cargo and stored quantities separated. Population indicator no longer wraps. Access distance heuristic provisional.

Version 0.20.1: selected-system resource rows show theoretical production less civilian demand per year, color-coded green/red/white. Local hover distinguishes this projection from actual latest-step production, consumption, delivery and spending. This is display-only; economy rules are unchanged.

Version 0.20.2: top-bar resource deltas now sum theoretical production minus full civilian demand across owned systems using the same sign colors. Holdings and storage strips remain actual values. Hover distinguishes theoretical net from recent actual flows, including irregular mining deliveries and construction spending.

Version 0.20.3: construction and upgrade recipes and nominal build times are always visible on collapsed cards. Ship estimates use the fastest operational eligible shipyard (level-one baseline when none is operational); actual queue and staffing delays are excluded. Immediate habitation and warehouse purchases show Instant.

Version 0.20.4: remove unused runtime rolling-rate sampling and validate civilian path topology once per simulation substep. The Perf overlay reports the largest measured simulation stage; hover the Perf button for all stages. These timings are totals across the latest speed-scaled callback, not frame time or averaged FPS. No simulation timestep, economy rules, ship movement rules, or snapshot cadence changed.

Version 0.20.6: construction cards show all icon costs (including crew) in a single compact row; build/upgrade durations appear inside the action buttons beside an analog clock icon. Exact material tonnage is retained in tooltips. Construction rules and duration estimates are unchanged.

Version 0.21.0: select a zoomed-in star system, then left-click an orbiting planet to inspect its name (system name + Roman orbital number), ownership and defense. The left panel offers a timed Build PDS button, prepaid recipe, progress and cancellation; a completed defense displays its HP. Explicit slot orders use the existing host-validated operation request, allowing any undefended planet with its existing slot-indexed recipe. One pending defense per system; no separate planetary economy. Click the star or Back to system to return.

Version 0.21.1: the star-system Economy defense card offers a named planet selector with PDS status, HP, upfront costs, time, progress and cancellation. Selecting orbital planets on the map is optional; every planet upgrade/action must also be accessible at star-system level. No gameplay changes.

Version 0.21.2: expanded Economy cards report live numeric before/after effects for one completion. Production previews use current population and modifiers, actual production formulas and theoretical net after civilian demand (not warehouse-limited changes). Industrial worker limits, food capacity, extraction limits, warehouse capacity, habitation penalty/capacity and PDS HP/damage/range are explicit. No balance changes.

Version 0.21.3: ship card titles show living origin-system hull counts directly after the ship name, using (3), (3 / 5), or (3 / ∞) for no target, finite maintenance, or continuous production. Pending orders are counted separately on the Build button. No gameplay changes.

Version 0.22.0: choose Radial (default), Grid or Scramble in solo setup or host multiplayer lobby. Radial distributes starts around outer spokes with central neutral deposits, Grid arranges clusters on a lattice, and Scramble places irregular separated clusters with dispersed starts. Existing sparse lane constraints, seed determinism and travel-time scaling remain. Special deposits are reserved before ordinary fields, randomized in nonradial layouts, and never directly accessible from a home system; minimum edge clearance is 700 generator units before shared distance normalization. Host layout changes reset guest readiness and replicate with the match seed. Opening balance on new layouts needs playtesting.

Version 0.22.1: Radial uses closed outer and inner cluster rings joined by inward spokes, surrounding a central antimatter region. Minimum three sectors (nine clusters) for small player counts ensures actual cycles. Solo and multiplayer setup draw the exact seeded galaxy, including travel lanes, starting colors and fields. Reroll explicitly changes the seed; starting a match preserves the displayed seed and selected layout. Grid and Scramble are unchanged.

Version 0.22.2: Hex Grid is a fourth map preset, with six-sided honeycomb cycles, staggered rows and seeded dispersed homes. It uses the same map preview, protected noncentral antimatter and maximum three lanes per system. A full honeycomb patch can round the cluster count up to preserve complete cells, including small rosters. Radial remains default.

Version 0.23.0: unified solo/multiplayer setup uses shared roster rows and a large dedicated seeded map preview (minimum 340×320). Multiplayer adds chat and readiness, host-editable seed, and a LAN hosted-game browser. Discovery uses UDP 24568 broadcast and probes the explicitly entered IPv4 address; gameplay remains UDP 24567. Same-version open lobbies appear with host name, player count, map layout and Join; entries expire when no longer available. Direct IP remains usable across Tailscale/internet; an internet-wide directory is not implemented. Allow UDP 24568 on the host firewall for discovery, if needed.

Version 0.23.1: Hex Grid is a true individual-system honeycomb, including compact six-system rings and standalone vertices. All layouts target about 80% clustered and 20% standalone systems, with rounding and safe placement constraints. Radial/Grid/Scramble add neutral waypoints on existing inter-cluster lanes; Hex keeps short local routes using the original macro reference length. Existing protected antimatter and exact seeded previews remain.

Version 0.23.2: all generated star and asteroid nodes share a hard three-lane maximum. Asteroid access uses nearest eligible available ports and is stored in the seeded map, including for mining, military paths and preview. Hex Grid features separated small hex clusters connected by nearest permitted inter-block bridges across open space; the 80/20 mix remains. Some ordinary fields may be omitted when no nearby port is available.

Version 0.24.0: half of generated star systems (rounded to a whole system) have no planets. Capture neutral empty systems with fighters using the existing occupation duration. Their Economy tab offers repeatable Orbital Eco-Housing: +5,000 self-sustaining residents per instant purchase (180 Metals, 80 Plastics, 40 Textiles, 40 Tech); zero civilian consumption, no natural growth or habitation limit, normal crew expenditure. Planetary agriculture, mineral extraction and defenses require planets. Industry, storage, shipyards, asteroid mining and trade remain available. All starts remain planetary; the preview identifies planetless systems with hollow markers.

Version 0.24.1: each completed shipyard and purchased Orbital Eco-Housing module contributes 5,000 self-sustaining resident capacity and +0.2 t/yr Organics. Eco residents are included in system/empire population and crew/labor; grow independently toward installed housing capacity at a 60-year doubling rate. Starting systems have 10,000 terrestrial plus 5,000 shipyard residents. Shipyard level upgrades add no housing; destruction removes capacity and a proportional share of residents. Planetary demand and habitation penalties exclude eco residents. Balance remains provisional.

Version 0.24.2: smaller varied maps, at most eight systems per roster member; irregular spacing across all layouts, small separated hex rings and compact radial rings. Star counts exclude asteroid fields. Reduced hull rendering scale without changing movement/combat. Planetary defenses automatically occupy the first free planet, always using the same 540 Metals/120 Plastics/60 Textiles/60 Organics/60 Tech recipe and existing battle stats.

Version 0.24.3: refined fighter, mining and colony hulls with distinct silhouettes, shaded structural panels, cockpits, emitters, habitat modules and engines. Fine detail renders at useful zoom levels only. The logistics freighter and its cargo display are unchanged.

Version 0.24.4: combat destruction produces colored hull-panel particles and tumbling detached outline segments. Clients consume the same bounded combat event history without exploding ships that settle colonies. Fighter fire originates at the nose and mining beams at both arm tips. Visual only; logistics hull art and combat economics are unchanged.

Version 0.24.5: detailed open-berth shipyard art and selectable completed shipyards. The inspector displays ownership, HP, level, staffing, work progress, numeric upgrade effects, costs and existing upgrade/cancel actions. Existing system cards remain available. Combat and mining beams now use the source player color. Visual only; simulation and authority commands are unchanged.

Version 0.24.6: zoom well past the old maximum to inspect the detailed hulls (fighter length up to roughly 60% of viewport width). Selecting one or more ships automatically follows their interpolated center, including control-group recall. WASD or middle-mouse panning releases tracking without clearing the selection; reselect to resume. Scroll zoom stays centered on the tracked fleet; when free-panning, scroll anchors to the cursor. No simulation or networking changes.

Version 0.24.7: territory requires local residents or a completed shipyard (not ship crew or military presence); empty claims and fields no longer generate territory shading. Waiting loaded miners can fly locally until a depot becomes available and must dock before unloading. Hull structure and panels use owner colors, including breakup effects; freight cargo retains resource colors. Defended planets render even without system selection, with a PDS overview cue at distant zoom.

Version 0.24.8: radial ring and spoke endpoints use shortest available connections rather than reserving the third port artificially, then recheck earlier assignments for shorter feasible links. Connected rings and the three-lane cap remain. Empty stranded miners retry evacuation even with no cargo; PDS planet highlights are restricted to the selected system.

Version 0.24.9: solo regression selects an adjacent planetary system rather than assuming the lowest-index neighbor can be colonized; gameplay unchanged from v0.24.8.

Version 0.25.0: right-click empty space inside a selected ship's current sector to fly there and hold. Alt-right-click forces precise local positioning near POIs; normal system/field clicks retain lane and specialized orders. All owned hulls can be selected; H toggles hold/release. Civilian work and cargo are preserved while holding, and emergency fighter withdrawal retains the saved hold objective. Authority validates location, ownership and sector; selected ships display their destination marker.

Version 0.25.1: local positioning becomes available on physically entering a destination sector along a lane, even before reaching its center. No shortcuts through unrelated sectors.

Version 0.25.2: Grid uses a finer square lattice with regular local cells and Hex Grid uses compact regular hexagons in staggered rows. Both add short neighboring-block connections where ports permit, yielding alternate routes instead of a tree of isolated clusters. Standalone waypoints bisect the connecting lanes. Preserve eight stars per player, the three-lane POI cap, protected antimatter, and opening pacing. Radial and Scramble are unchanged.

Version 0.25.3: Box selection, Shift-add/toggle and control-group recall include ships of every empire. Mixed fleet summaries count all selected ships and their cargo, and camera tracking follows the whole selection. Commands and hold/release affect only owned selected ships; foreign-only selections are inspectable but read-only. The calendar starts at 2850 A.D. with the year at the far left and Menu at the far right of the HUD; elapsed simulation time and pacing are unchanged.

Version 0.26.0: Destroyed ships drop all carried goods and independently roll a 75% chance for each build material to recover 0–20% of its original recipe. Debris drifts in space, persists until collected, and is shown in resource colors. Select owned ships and right-click debris in their sector (or within tractor range on a lane) to claim and collect it. Tractors work at 12 t/year within 90 world units, share finite cargo space across resources, and leave any excess behind. Ships sweep nearby unclaimed debris until full or finished, then physically deliver to an owned warehouse with space; U manually unloads cargo. Capacities: fighters 10 t, colony ships 20 t, logistics 30 t, miners 60 t. All hulls display proportional, resource-colored cargo bays and cargo totals.

Version 0.27.0: Right-click a hostile ship with selected owned fighters to focus attack. Fighters follow its last reachable lane destination, close locally when they share a sector, prioritize it when in weapon range, and resume normal attack-move when it is lost. Right-click a system or asteroid field remains attack-move, including automatic engagement and destruction of hostile defenses. Shift-right-click a POI orders each selected owned fighter to repeatedly patrol between its current lane origin and that POI. Movement, hold, salvage or unloading cancels tactical orders; emergency repair temporarily supersedes them. Selected orders display attack markers or patrol endpoints. AI uses actual lane distance to choose objectives and responders and excludes withdrawing fighters from combat-ready reserve calculations. No diplomacy or policy orders.

Reproduce contested economy/combat benchmarks with `godot --headless --path . --script res://tests/contested_benchmark.gd`. These run seeded opposing AI matches for up to 900 simulation years with a coarse 1-year tick, reporting first expansion, first destruction, losses, peak fleets, ownership, stocks and victory. Use `-- --fine --duel-only` for the first radial duel at the real 0.1-year fixed step (omit `--duel-only` to test all three maps). Manual interaction and timing balance still require playtesting.

Version 0.27.1: Shipyards at subpixel overview scale use a compact owner-colored marker and construction/morph fills render only when their projected polygons can be triangulated. No simulation changes.

Version 0.28.0: Each drifting salvage pile independently expires after 90–120 simulation seconds (at 1×; pause stops decay). Any hull with free cargo automatically beams nearby resources into its hold when safe, including while traveling or holding position. Idle hulls can make a short sector-local approach. Combat, hostile targeting and repair supersede collection. Manual right-click salvage remains available and delivers to an owned warehouse; passive salvage stays aboard until normal delivery or U (unload). Hover debris to see its remaining simulation-time lifetime.

Version 0.28.1: The in-match side inspectors are replaced by a full-width bottom command console. The left area shows the selection, population and local resources; shipyard activity occupies the center on wider windows (folds into the overview below 1200 logical pixels); the right area holds contextual commands and Shipyards/Economy/Trade tabs with responsive card grids. Fleet cargo uses compact grids and time/logistics controls share the console toolbar. The map viewport uses the full width above the console, retaining its center across selection changes; local resource breakdowns open upward. All gameplay rules and controls are unchanged.

Version 0.28.2: The console uses a denser scoped theme, shorter buttons, tighter resource and recipe rows, and a three-column Trade grid when space permits. It reserves about 32% of window height (normally 195–285 logical pixels). An always-visible minimap at the far left shows the galaxy, lanes, asteroid fields, empire colors, live hulls, selection and the current main-map camera rectangle. Left-click or drag to center the camera at that position without changing selection, zoom or issuing orders. Narrow layouts retain independent scrolling and fold shipyard activity into the overview.

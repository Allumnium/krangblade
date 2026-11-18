# Warbound — development TODO

Living roadmap. Build a playable, low-micro galactic RTS with conventional direct military control and autonomous physical logistics. Policies and regional card assignments are intentionally removed. Prioritize a working RTS, then promissory notes, then a complete match loop. Target 10–30 minute matches at 1×, subject to playtesting.

Review AGENTS.md before work. This is a prioritized backlog, not blanket approval to invent mechanics. Numerical balance remains provisional. Earlier implementation history and the superseded policy roadmap are preserved in git (v0.17.36 and earlier).

## 1 — Basic RTS (current priority)

- [x] Host-authoritative solo/multiplayer, flexible teams, up to eight players, lobby chat, selectable empire colors, seeded maps and AI slots.
- [x] Physical navigation, construction, local trade thresholds, finite extraction, autonomous miners/freighters, repeat and maintain orders.
- [x] Starting three miners, two fighters, one planetary defense per home; physical cargo bays, repair and combat, destructible shipyards and planetary defenses.
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
- [ ] Playtest v0.36.3 both-button formation placement for armed Move, Attack and Patrol, including Shift queueing, Escape, click fallback, and unarmed selection.
- [ ] Playtest v0.36.4 formation arrival into normal wandering/work, progressive wheel zoom at overview and close range, and shared icon-only cargo display for empty and loaded single ships.
- [ ] Playtest v0.36.5 control-group strip, Ctrl+0–9 assignments, recalls and compatible Shift additions; verify foreign/dead removal, structure slot invalidation, cargo footer and station Economy construction/cancellation at narrow UI scales.
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
- [ ] Verify match lifecycle, hostile civilian rerouting, territory/capture interruption, elimination and conquest result; profile fleet-heavy matches and 10× speed. Run eight-peer stress validation before major releases.
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
- [ ] Profile late-game 8-player and fleet-heavy 10× matches using the v0.20.4 simulation-phase diagnostics; compare 1×, 5× and 10×. Remove redundant work first, then investigate trade matching, miner search, repair safety, discovery scans and frame-budgeted fixed steps. Preserve host authority, gameplay and network behavior. Benchmark path caching, territory rendering, snapshot efficiency, resource hover and large-map performance.
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

- [x] Expire drifting salvage independently after 90–120 simulation seconds; opportunistically collect with any hull when safe and with cargo room, retaining manual claims/orders (v0.28.0).
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

- [ ] v0.32.0: Playtest rally attack-move during lane and local travel, repair/resume, exact rally arrival and civilian behavior. Verify double-click selection of ships/shipyards/PDS by visible type, foreign read-only groups, grouped shipyard actions, F framing, and slot invalidation when structures are lost or completed.

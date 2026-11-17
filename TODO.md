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

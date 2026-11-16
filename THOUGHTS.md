# Warbound — active thoughts

A running log of potential issues, UX improvements and gameplay ideas noticed during development. These are observations and proposals, not approved tasks. Use stable identifiers; label verified issues versus hypotheses, and keep entries concise. Update or deduplicate existing entries. Once an idea is resolved, move the full entry into THOUGHTS_ARCHIVE.md with its outcome and evidence. Approved work belongs in TODO.md.

## Active observations (v0.8.0)

### T-001 — Long routes may conflict with short matches
- **Type:** Gameplay/pacing hypothesis.
- **Observation:** The prototype's longest direct lane takes 100 game years at baseline speed; multileg journeys may consume a substantial portion of a 10–30 minute match at 1×.
- **Consider:** Measure time to first meaningful contact and reinforcement before changing speeds or map geometry. See TODO phase 7.

### T-002 — Make autonomous decisions legible
- **Type:** UX proposal.
- **Observation:** Policies and autonomous fleets may leave players unsure why an operation stalls or diverts.
- **Consider:** Compact fleet state indicators and tooltips for rallying, travel, retreat, repair, and supply/resource bottlenecks. Avoid extra panel text. See TODO phases 1–2.

### T-003 — Retreat and formation feedback loops
- **Type:** Technical/gameplay risk, not a verified bug.
- **Observation:** Future moving combat and retreat behaviors could produce repeated disengagement/re-engagement or formation reshuffling.
- **Consider:** Stable membership/slot assignment and distinct withdrawal/rejoin conditions, with speed-bound and replicated-position tests. See TODO phase 1.

### T-004 — Early antimatter monopoly
- **Type:** Balance hypothesis.
- **Observation:** Concentrated antimatter deposits could give the first arrival an irreversible advantage if other economic strategies cannot contest production.
- **Consider:** Test whether processing investment, raids and later opportunities provide counterplay. Do not pick a solution before the victory loop is defined. See TODO phase 4.

### T-005 — Treaty loopholes
- **Type:** Design/authority risk.
- **Observation:** A Wildcard slot or legacy military commands could bypass a restricted offensive policy.
- **Consider:** Authority-level restrictions on behavior across every slot and command path, including clear treatment of ongoing operations. See TODO phase 6.

### T-006 — Operation identity and retargeting
- **Type:** Technical/design risk.
- **Observation:** v0.10.0 preserves operation IDs on retargeting if an old group disappears and its members transfer to a new objective; splits and merges retain exact surviving groups first. Stable formation slots across these changes still need design and validation.
- **Consider:** Test complex splits/merges and membership churn before committing to formation-slot geometry. See TODO phase 1.

### T-007 — Small allocations can stall attacks
- **Type:** Gameplay/UX hypothesis.
- **Observation:** A hostile-system allocation below three hulls now rallies rather than trickling into battle; splitting a small fleet across several hostile objectives can stall all of them.
- **Consider:** Show requested versus deployed hull counts and rally status; review cohort size and priority arbitration during policy design. See TODO phases 1–2.

### T-008 — Orbiting combat and concentrated fleets
- **Type:** Gameplay/visual hypothesis.
- **Observation:** v0.10.1 uses a common orbit direction and a provisional preferred separation of 60% of laser range; dense fleets may overlap or repeatedly lose contacts when chasing fast targets.
- **Consider:** Inspect real battles before adding separation, target persistence or a turn-rate model; integrate stable formation slots with combat maneuvers without sacrificing speed bounds.

### T-011 — Population and industrial bottlenecks
- **Type:** Gameplay/balance hypothesis.
- **Observation:** Multi-resource ship costs make local Plastics, Textiles, Organics and Tech stock actual constraints. Baseline industrial outputs and population gates may make new colonies slow to develop, while Organics also supports residents. The first Tech upgrade requires 200k population and construction costs remain provisional.
- **Consider:** Measure time to replenish twelve mixed hulls, evaluate trade throughput and whether AI needs more deliberate industrial investment. Preserve local logistics; do not silently grant free resources to colonies.
### T-009 — Pursuit speed and disengagement
- **Type:** Gameplay/balance hypothesis.
- **Observation:** Fighters and civilian hulls currently share the same maximum flight speed. A straight-line chase can maintain contact but cannot reliably catch a ship already pulling away. The three-year cap limits detours; targets still in range at expiry cannot immediately restart the same chase.
- **Consider:** Playtest escapes and interception before altering relative ship speeds or introducing retreat-specific movement; inspect pursuit and re-engagement near fleet objectives.

### T-012 — Full warehouses and construction refunds
- **Type:** Gameplay/UX balancing risk.
- **Observation:** Production and deliveries respect storage space; miners wait with undelivered cargo. Full refunds may temporarily place stock above capacity to avoid resource loss. No positive growth occurs in that state.
- **Consider:** Playtest warehouse prices and cargo bottlenecks; consider reserved refund capacity or a separate overflow mechanism if temporary refund overflow proves confusing.
- Integration note: v0.11.2 restored the pursuit duration constant omitted in the v0.11.1 economy integration. CI caught the parse failure.
### T-013 — Industrial labor ceiling
- **Type:** Balance hypothesis.
- **Observation:** Installed industrial capacity now supports 100k productive residents per level, while linear demand continues increasing. At level one, Tech/Textiles output reaches 5 units/year and demand catches up at 200k population (before economic bonuses).
- **Consider:** Playtest whether industry upgrades are timely and accessible, particularly for AI and colonies. Adjust provisional rates if stockouts routinely stall construction.

### T-014 — Snapshot pressure during lobby return
- **Type:** Verified eight-peer lobby-return timeouts; queue pressure is a hypothesis.
- **Observation:** Full reliable snapshots were broadcast after each order, including bursts from seven guests. v0.11.4 batches remote state at the fixed cadence and allows one unacknowledged snapshot per guest. Local authority UI remains immediate. Test guests explicitly leave after the lobby scene loads; headless peers are capped at 60 FPS to avoid CPU starvation on shared runners.
- **Consider:** Validate under eight real peers and future internet latency; inspect bandwidth and queue age on large fleets.

- v0.11.5 uses the Node-level rpc_id method to obtain send errors; the callable RPC shorthand returns void in Godot 4.7.2 (caught by CI).

### T-015 — Formation pacing and visual density
- **Type:** Prototype limitation.
- **Observation:** v0.12.0 assigns stable disk slots and steers each hull toward offset waypoints; shared lane pace and explicit cohesive travel anchors are not yet implemented. Route metadata advances at offset waypoints. Large groups compress spacing to stay within rally radius.
- **Consider:** Verify visual fleet silhouettes and actual cohesion on long routes and after combat; introduce shared pace only after measuring lagging/rejoining hull behavior. See TODO phase 1.

### T-016 — Withdrawal balance and safety
- **Type:** Provisional design / playtesting risk.
- **Observation:** Individual withdrawal at 46 HP and free repair at 10 HP/year at a safe owned shipyard. Hostile fighters within two laser ranges prevent repair. No new withdrawal without a safe reachable site. Retreating fighters remain vulnerable and can be pursued.
- **Consider:** Evaluate whether retreat reliably saves ships with equal opponent speed, and whether repair costs or fleet-wide withdrawal are needed. Verify recovered human and AI deployment in real battles.

### T-017 — More expensive hulls and shipyards
- **Type:** Balance hypothesis.
- **Observation:** Triple hull costs with unchanged home stocks reduce the opening budget to about four mixed hulls. Second and third shipyards require Crystals; third costs 6k Metals, requiring sustained construction draws or larger storage. First shipyard retains its inexpensive colony-entry recipe.
- **Consider:** Assess AI expansion and recovery, early player choices, and resource replenishment before changing starting inventory. v0.12.3 adds 3× per-level upgrade pricing; the higher repeat tiers can exceed warehouse inventory but gradual construction remains possible. Instant warehouse purchases fit their previous-tier capacity. One-time building prices triple independently, so purchase order does not affect them.

### T-018 — Concurrent shipyard construction
- **Type:** Gameplay/UX hypothesis.
- **Observation:** v0.12.4 permits concurrent infrastructure construction; a later shipyard can reach full progress before an earlier one and waits for the preceding slot to complete. Cancelling an earlier slot retains the later job’s percentage at the cheaper recipe and refunds the difference.
- **Consider:** Verify the waiting-at-100% case is legible; consider a concise status if it confuses players during resource shortages. Review concurrent infrastructure work during pacing tests.

- v0.12.5 fixes a duplicate local variable name in the new regression fixture, caught by the mandatory parse check.

### T-019 — Crew and demographic pacing
- **Type:** Balance hypothesis.
- **Observation:** Ship construction consumes local population proportionally (fighter 10, logistics 20, miner 30, colony 1,000). Cancelled construction returns allocated population. A colony hull delivers its settlers. At least one resident remains to avoid irreversible zero-population growth.
- **Consider:** Measure expansion and repeated ship construction on small colonies. Crew values are provisional; no crew upkeep, transfer or automatic demobilization has been added.

### T-020 — Empire color readability and blocked construction
- **Type:** UX hypothesis.
- **Observation:** Empire colors are assigned independently of teams. The fixed eight-color palette prevents duplicates; allied territories can now have distinct color boundaries while combat still uses teams. Amber progress signals material or population starvation, including zero-progress hull orders.
- **Consider:** Playtest palette distinguishability and constrained layout at eight peers. If all eight colors are occupied, free-color changes are unavailable until another color becomes free; no swap mechanism yet. The v0.12.6 UI fixture failed after prior purchases and colony construction; v0.12.7 explicitly funds the later fighter scenario rather than weakening its assertions.

- v0.12.8 corrects the idle-progress typed array initialization and updates ENet territory checks to compare replicated owner palette indices instead of team numbers. These validation issues were caught in the v0.12.7 run.

### T-021 — Planetary defense strength and starting fleet pacing
- **Type:** Balance and visual hypothesis.
- **Observation:** All players start with three miners and two fighters without reducing stocks or resident population. PDS installations each fire 36 damage once per year at basic fighter range; each successive planetary installation costs three times the preceding recipe. Build one at a time per system. The shared authoritative system waypoint is the range origin; at close zoom the beam originates at the corresponding decorative planet.
- **Consider:** Playtest attack waves against multiple defenses. PDS installations are not independently targetable or destructible yet; decide that along with conquest design. Check starter miners' resource throughput and PDS pacing.

- v0.13.1 corrects a duplicate fixture variable found during static review of the PDS test.

- v0.13.2 corrects the starter fleet test's shadowed home index, caught by Godot parsing.

### T-022 — Starter mining and shipyard staffing
- **Type:** Verified code restriction; balance hypothesis.
- **Observation:** Mining required owned field anchors, so starter miners could idle on generated maps. Neutral/friendly access and owned depot delivery added; slots require 500/5k/20k residents to operate.
- **Consider:** Playtest mining throughput, full warehouses, and colony staffing. Values provisional.

- v0.13.4 adds offline construction feedback and waiting-miner status, preserves disabled cancel controls even for empty shipyard slots, and avoids redundant per-chunk route calculations. Existing routes are not revalidated on territorial change; revisit once conquest is implemented. Fixed an outdated UI label assertion.

- v0.13.5: Both eight-peer runs timed out after entering the match; all other v0.13.4 checks passed. Cache neutral mining routes within each tick and limit idle search retries to twice/year. Added host-side progress diagnostics to identify any remaining verification stall without reducing assertions or changing timeouts. Performance cause is a hypothesis, not yet confirmed.

- v0.13.6: Eight-peer test still timed out. Replace dense mining route searches with sparse adjacency and cached single-source shortest-path trees; add time-control gate diagnostics. No assertion or timeout reductions.

### T-023 — Setup and resource display
- **Observation:** Solo defaults to four empires; eight occupied colors leave no free selection. Mass labels preserve numerical balance. v0.13.6 passed all checks including eight peers; sparse mining routing resolved the timeout.
- **Consider:** Review small-window layout and color swap UX.

### T-024 — Local flow visibility and shared mining access
- **Observation:** Empire total includes ship cargo; actual stock remains local until docking. Native tooltip text can remain cached while hovering. Custom persistent resource panel reports last-step actual flows per owned system rather than averaging. Nearby field connections are based on existing anchor distance and radius.
- **Consider:** Check hover scroll/layout with many colonies, delivery-rate spikes (annualized from one tick), and access distance after large map scaling. One-time instant purchases are not continuous flows. Visual layout needs playtesting.

- v0.13.10: corrected the tooltip construction-category formatter and early UI regression fixture reference during static review; v0.13.8 passed all mandatory checks.

- v0.13.11: the hover regression caught compact inventory rounding hiding a 1 t change. Exact quantities in the detailed hover now show two decimal places in tons; field inventory labels also use tons. v0.13.10 passed all multiplayer checks and the economy suite.

### T-025 — Maintain target input
- Finite targets are provisionally capped at 9,999. Validate snapshot-safe editing and unlimited-to-finite drag behavior; cancellation stops automatic replacement to prevent immediate requeue.

- v0.14.1 adds local hover detail and latest-step demographic and crew rates; verify constrained layouts and infinity dragging under snapshot latency.

- v0.14.2: fix maintain row wrapping by enforcing single-line labels and compact input dimensions; verify actual window rendering.

### T-026 — Large match performance
- Cached static military graph and lazy destination-indexed Dijkstra trees retain existing tie breaking without transmitting caches. Sparse graph makes this a practical alternative to Floyd–Warshall; profile before prewarming every destination. Civilian paths still require ownership-sensitive invalidation.

- v0.14.4 adds asteroid off-screen culling and logistics capacity bars. Dense overlapping traffic indicators and shader spatial caching remain candidates for visual profiling.

- v0.14.5 caches immutable asteroid unit polygons by position and seed; depletion still scales the same polygon each frame. Ship snapshot synchronization now occurs on economy changes rather than repeated pose queries. Actual frame-time savings require profiling.

- v0.14.5 failed both normal ENet scenarios: render targets lagged the live host state between publications. v0.14.6 restores pose-time synchronization (no weakened checks), retains asteroid geometry caching, and adds ownership-sensitive persistent logistics route caching. Mining depot decisions remain tick-local.

- v0.14.7 caches a conservative occupancy tile mask when claims change. Empty tiles skip the per-site shader loop; occupied tiles retain the same full-resolution continuous distance calculations. Dense territories may limit savings; GPU profiler and visual comparison outstanding.

- v0.14.8: user reports five players at 5× without noticeable lag in basic gameplay. Added 10× stress control and persistent mining path trees; no change to simulation resolution. Snapshot static-data separation remains outstanding.

- v0.14.9 fixes outdated four-button assertion caught by normal ENet 10× tests; allows repeat upgrades before population gates and filters finite ship limit input to digits. Verify pasted text and drag interaction visually.

- v0.14.10 updates stale Tech repeat UI assertion and limits civilian stock access by import target. This is a per-step access ceiling, not a permanent reserved stock floor; evaluate sustained shortages and whether a stronger reserve is needed.

- v0.15.0: provisional habitation starting capacity 10M × system size factor, three doubling upgrades with tripling recipes. Food equilibrium remains separate. Check pacing and visual density of perimeter indicators.

- v0.15.1 moves cancellation beside active progress, including shipyard assignments; verify visual layout and matching job refunds.

- v0.15.2 removes current construction eligibility from finite target validation. Existing queue scheduling still enforces eligibility; test unavailable shipyards and non-home logistics targets.

- v0.15.3 replaces absent procedural deposits with low-yield deposits and bounds site production modifiers. Explicitly unbuilt production and asteroid depletion remain unchanged.

- v0.15.4 adds local optional Perf overlay with FPS, host simulation/encoding timing, compressed snapshot size and payload throughput. Throughput excludes protocol overhead; no extra replication. Actual benchmarks outstanding.

- v0.15.5 adds sorted stock-share segments to each resource storage strip; tiny shares may be subpixel, and names are hidden when they do not fit. The numeric holdings/rates and live hover remain intact.

- v0.15.6 adapts header height regression to the two-row HUD and adds population distribution without revealing capacity. Visual validation remains outstanding.

- v0.16.0 uses 30 work per economy building, tripling successive recipes, one pending per resource. Warehouse and habitation retain their distinct upgrade rules. Trade switches require multiplayer and UI regression verification.

- v0.16.1 corrects perimeter carets to align with actual planned approach/departure lanes. Dense multi-resource routes need visual spacing checks.

- v0.16.2 introduces orbital construction frame visuals and replicated health values. Orbit is presentation-only in this prototype; damage, destruction and physical launch integration remain outstanding.

- v0.16.3 simplifies single-system HUD strips, equalizes population tile sizing and clarifies the overpopulation penalty label. Visual verification remains outstanding.

- v0.16.4 adds physical miner stand-off and deterministic local particle visuals with fixed per-hull limits. GPU/CPU cost and appearance still require fleet-heavy playtesting.

- v0.16.5 includes the first shipyard price and work in the colony hull. The conversion is immediately operational subject to existing population staffing; visual morph lasts three game years. Full combat integration remains outstanding.

- v0.16.6 adds font-measured abbreviated system labels in resource and population strips; verify small-segment readability visually.

- v0.16.7 adds Q/E owned-system camera focus. Uses a provisional 27% viewport radius for framing; verify at varied window sizes.

- v0.16.8 enables persistent discovered-system labels at 65% opacity when unselected. Check wide-zoom readability and label overlap visually.

- v0.16.9 implements hostile fighter attacks on shipyards, destruction and physical launches. Provisional 95-unit orbit, stationary targets lower priority than ships, no refund for destroyed work. Validate combat, compacted slots, and visual performance.

- v0.16.10 fixes missing optional chunk radius in synthetic mining fixtures and tests the stand-off distance instead of exact asteroid-center arrival. Extraction and delivery assertions remain intact.

- v0.16.12 derives the solo colony construction test window from recipe work and shipyard speed, checks the conversion, and exits promptly on failed assertions.

- v0.16.14 fixes HUD clearing with an empty state and updates map-view smoke assertions for bidirectional handle pushing and timed repeatable building cancellation. Earlier assertions expected superseded instant purchases and clamped handles.

- v0.16.15 updates the map-view colony fixture for the revised recipe and makes its assertions fail promptly. Existing assertions remain mandatory.

- v0.16.16 makes shipyard progress bars continuous rather than quantized and checks both authoritative and displayed work fractions across cancellation/compaction. CI required.

- v0.16.17 uses window content scale for compact UI (also affects map rendering); verify camera and modal sizing at all scales. Music bus is ready for future assets; existing upgrade effect uses SFX. Future shipyard rows hidden while existing concurrent orders remain supported by authority.

- v0.16.18 explicitly publishes the authoritative state before comparing shipyard work fractions in the map smoke test; retains the equality and cancellation checks and adds mismatch diagnostics. v0.16.17 passed all ENet scenarios but failed this assertion; root cause not yet verified.

- v0.16.19 extracts named map smoke scenarios with per-scenario failure messages and pass logs. Shared state and order are preserved to avoid changing test semantics; fully independent fixtures remain a follow-up. CI required.

- v0.16.20: User explicitly retired presentation-specific automated UI tests. Deleted the monolithic map smoke script and its UID after v0.16.19 introduced an out-of-scope mouse variable; retain parsing, startup, simulation, solo and ENet checks. Visual/map interaction coverage is manual; review direct rules coverage when adding gameplay features. No UI behavior changed in this commit.

- v0.16.21 extracts shared cohort dispatch while preserving distinct objective selection and wave completion rules. Existing simulation fixtures exercise both paths; visual playtesting and unified persistent lifecycle remain outstanding.

- v0.16.23 adds guarded documentation-only PR validation via skip-ci-docs. Main pushes still run full validation; the workflow change itself is not eligible for the shortcut.

- v0.16.24 fixes wrapping in match audio settings by using non-wrapping labels, minimum column widths and compact vertically centered controls. Manual verification at all UI scales remains outstanding.

- v0.16.25 introduces a right-hand solo setup settings panel with optional integer map seed (random by default), aligned roster columns and bottom-right Start Match. Verify constrained widths manually; existing solo and multiplayer tests remain mandatory.

- v0.16.26 exposes operation lifecycle membership for future policy feedback; no UI changes. Validation pending.

- v0.16.27: scope-select multiplayer matrix for presentation-only PRs; cache imported assets while retaining imports and metadata checks. Main pushes remain full coverage until safe identical-tree validation reuse is implemented. Measure actual CI savings before further changes.

- v0.16.28 replaces routine eight-peer ENet with three peers while retaining the eight-peer scenario on manual workflow dispatch. This reduces concurrent peer load but does not prove eight-player scalability on every PR.

- v0.16.29 fixes AI operation fragmentation when a member temporarily changes destination. Wave completion and regroup policy are unchanged; test covers retreat snapshot identity. Validation pending.

- v0.16.30 retains AI attack operation identity across successive cohorts without changing wave size or strategy. Regression exercises completion, return and relaunch. Formation slot continuity across an entirely empty wave is not guaranteed.

- v0.16.31 moves shared construction progress into the action row; economy repeat uses existing escalating building recipes and stops capped instant upgrades at level 3. Visual verification remains outstanding.

- v0.16.32 doubles the housing growth penalty at a given population below the new 5-million baseline ceiling. Food and demographic momentum remain independent; no hard population deletion or production penalty introduced.

- v0.16.33 increases crew costs using existing proportional construction deductions and refunds. Starting granted fleets and 10k home population unchanged; colony expansion now requires substantial demographic growth. Adjusted construction fixtures to supply people; food and early AI pacing need playtesting.

- v0.16.34 differentiates basic hull crew costs; logistics ships now consume 20% of initial home population if built before growth. Playtest early trade viability.

- v0.16.35 anchors system names to the drawn star radius instead of the full orbital extent. Check overlap with orbiting bodies and ships during manual zoom testing.

- v0.16.36: PR #79 failed economy repeat rotation with larger crews and timed out normal ENet checks. Fund population/materials in construction-specific fixtures; avoid AI saving indefinitely for a colony ship when food capacity cannot support it. Fix economy automatic building enqueue kind. Keep all assertions. Record agreed policy design in TODO before implementation.

# Warbound — development TODO

Living roadmap. The game is a low-micro, policy-driven multiplayer galactic RTS: players govern empires rather than command individual ships. Preserve existing local economic controls, physical logistics and star-system gameplay. Target typical matches of 10–30 minutes at 1× (larger matches may be longer).

Review AGENTS.md before work. This is a prioritized design/development backlog, not authorization to implement every idea without agreement. Exact numerical values and unresolved mechanics require design review. Update checkboxes as work is merged and validated; distinguish partial prototypes from complete work.

## Current foundation (v0.8.0)
- [x] Host-authoritative solo/multiplayer, flexible teams, up to eight players, lobby chat and AI slots.
- [x] Physical ship navigation and cargo logistics, local import/export thresholds, mining, shipyards and repeat construction.
- [x] Basic fighters, automatic proximity combat, direct POI allocation and initial AI-only attack waves.
- [x] Visible territory overlay, time controls and mandatory parallel regression checks.

## Priority — Economy foundation
- [x] Verify bounded snapshot replication and eight-peer lobby return (v0.11.5, PR #51; all mandatory checks passed).
- [x] Validate initial multi-resource ship recipes (v0.11.5).
- [x] Validate v0.12.2 higher hull prices (3×), escalating shipyard slot prices, three always-visible slots and default Shipyards tab. Starting inventory unchanged, supporting roughly four mixed hulls; revisit opening balance.
- [x] Validate v0.12.3 exponential upgrade prices: 3× per level for resource production, shipyard upgrades and warehouse logistics; 3× prior price for one-time buildings. Keep population gates and build durations unchanged.
- [x] Validate v0.12.4 compact per-slot Build controls, sequential slot availability, concurrent construction and stack cancellation with proportional repricing and refunds.
- [x] Validate v0.12.6 collapsed ship and upgrade cards, icon recipes, unmet requirements, proportional population costs and refunds, and colony settler transfer.
- [x] Validate v0.12.7 blocked progress styles, inline production modifiers and exclusive selectable empire colors in lobby and match.
- [x] Validate baseline population-scaled production, local population gates for production upgrades (first Tech upgrade at 200k), and one-time Economy buildings with resource-specific percentage bonuses.
- [x] Validate v0.13.3 inline actions, shared population icon, staffed shipyards and neutral-anchor mining delivery.
- [ ] Validate v0.13.8 solo roster and navigation, metric tons, population layout and per-tab accordion.
- [ ] Validate v0.13.9 multi-system asteroid access, arrival-only cargo availability, live resource flow hover and population label layout.
- [ ] Playtest costs, output, trade, AI expansion, population pacing and building choices before choosing final balance.
- [x] Validate per-resource storage ceilings, three warehouse upgrades, linear consumption by population (all except Crystals), and zero starting Crystal production.
- v0.11.5 validated and merged via PR #51. Prototype includes finite population-serving industrial capacity (Plastics, Textiles, Tech) so linear demand can catch up even below the storage ceiling; implements the above via existing authority commands and local inventories; Headless validation passed; visual playtesting and longer AI sustainability evaluation remain.

## Phase 1 — Autonomous military foundation
- [ ] First integration step: consolidate human and AI operation dispatch and lifecycle while keeping current POI allocations, rally rules and retreat behavior. Keep existing regressions and add shared-operation coverage before policy work.
- [x] Validate v0.13.0 starting fleets (3 miners, 2 fighters per empire) and planet-limited PDS construction, refunds, combat, replication and overlays. Visual playtesting and balance outstanding.
- [ ] Rework military control into persistent fleet/operation groups shared by human and AI empires.
  - Initial v0.9.0 prototype: shared authoritative operation IDs, member lists, objectives and movement/engagement flags derived from existing routing. v0.9.0 validation passed (PR #47). v0.10.0 prototype moves human routing into operation dispatch and preserves identity on group retargeting; AI still uses its existing wave controller. Full unified command model remains outstanding.
- [ ] Automatically assemble sufficiently strong waves, rally reinforcements, coordinate departure and regroup survivors; extend the existing AI-only rally prototype.
  - v0.10.0 prototype: hostile-owned system allocations rally in groups of three at home, with additional cohorts and lone-survivor regrouping. Neutral and friendly assignments remain immediate; unified AI/human operation lifecycle and playtesting remain outstanding.
- [ ] Generate formations of varying sizes based on fleet size and ship composition. Assign stable relative positions; smoothly re-form as membership changes without teleportation.
  - v0.12.0 prototype: operation-level persistent disk slots, lane-relative waypoint offsets and stationary regrouping, shared by human and AI fighters. Combat/pursuit still override navigation. v0.12.0 passed all checks (PR #52). v0.12.1 adds same-operation, same-directed-lane synchronized pacing and waypoint arrival; mixed hull roles, cross-leg cohesion and visual playtesting remain outstanding.
- [ ] Allow combat ships to continue physically flying and maneuvering during combat; use authoritative world positions for range and movement, keep lane travel intact.
  - v0.10.1 prototype: fighters temporarily leave their lane to circle live opponents at a preferred engagement distance, then resume queued waypoints from the actual combat position. v0.10.3 pursuit and live render synchronization validated in PR #49. Formation integration and visual playtesting remain outstanding.
- [ ] Have damaged ships automatically fall back; design safe withdrawal destinations, repair/recovery and rejoining. Decide individual versus fleet retreat triggers and prevent oscillation.
  - v0.12.1 prototype: individual fighter withdrawal at 46 HP or less to nearest reachable safe owned shipyard, no firing during retreat, physical docking, free repair at 10 HP/year, full health before rejoining normal orders. Safety radius is two laser ranges; no safe site means no new retreat. Fleet-wide retreat, costs and balance remain open.
- [ ] Establish clear fleet state feedback and regression coverage for assembly, combat movement, withdrawal, reinforcement, speed bounds and replicated positions.

## Phase 2 — Empire policies and regional commands
- [ ] Define a shared, host-authoritative policy model with four initial slots: Offense, Defense, Economy, Technology; a fifth Wildcard slot starts locked.
- [ ] Define policies as unique per-empire cards, optional slots, warmup only (invasion 20 seconds at 1x), no cooldown; clear flags on replacement. Hidden until technology unlock; population/system eligibility. Economy policies can modify production/consumption, not duplicate existing automation.
- [ ] Prototype regional attack/invasion and defense objectives selected on the galaxy map (systems or groups of systems). Bottom-edge partially exposed cards, Change modal with drag-to-slot, contextual right inspector and colored map flags. Reject owned/allied offense targets. Normalize military policy sliders proportionally; split each policy share equally among valid flags.
- [ ] Connect policies to fleet assembly, deployment, reinforcement and defense. Reconsider direct POI fighter sliders; preserve existing behavior until a replacement is agreed and functional.
- [ ] Allow the unlocked Wildcard to host an additional policy, including a second military objective. Define eligible policy types and conflict handling.
- [ ] Let AI empires select policies using the same automation and restrictions as human players.
- [ ] Preserve local resource import/export controls, mining preferences, ship production, upgrades, inventories and shipyard management; decide which optional economic behaviors policies should automate.
- [ ] Provide minimal policy UI, operation status and meaningful explanations of stalled/blocked actions (prefer tooltips and concise indicators).

## Phase 3 — Territorial warfare
- [ ] Design and implement hostile system conquest; distinguish visual military control from actual ownership.
- [ ] Decide capture requirements, resistance, ownership transfer, infrastructure/inventory handling and interruption/recovery rules.
- [ ] Evaluate simple supply/repair infrastructure, vulnerable logistics and economic raiding; avoid introducing detailed fuel/ammunition simulation without agreement.

## Phase 4 — Antimatter and match objectives
- [ ] Specify antimatter geography, extraction, transport, local storage and processing; consider scarce contested deposits near the galactic center.
  - v0.17.33 prototype: finite antimatter in the innermost existing asteroid fields, opt-in extraction by existing miners, physical delivery to owned storage. Raw stock/cargo is separate from the six normal economy resources. Processing infrastructure and victory scoring remain undecided.
- [ ] Define victory condition (stockpiled processed antimatter, cumulative production or sustained rate are options), team scoring and end-of-match handling.
- [ ] Prototype the smallest functioning antimatter economy and victory loop. Decide whether and how antimatter is consumed for military technology.
- [ ] Test opportunities for comebacks and alternative industrial/territorial strategies; decide if later extraction opportunities are helpful.

## Phase 5 — Technology, economy and Wildcard
- [ ] Activity-driven independent research branches (military, logistics, industry, extraction, habitation, exploration, communications); points accrue without policies, technology cards multiply relevant gains. Improved communications unlocks Wildcard. Exact rates and thresholds provisional.
- [ ] Define Economy and Technology policy choices and their concrete effects. Consider optional star-system specialization and automated development without removing existing local controls.
- [ ] Design missing manufacturing recipes and distinct combat ship roles only as needed by the core loop.

## Phase 6 — Diplomacy
- [ ] Prototype bilateral offers exchanging resources for temporary, binding restrictions on specific policy choices.
- [ ] Decide payment/transfer semantics, duration, expiration, active-operation handling, eligibility, and UI.
- [ ] Enforce restrictions at the authority across all slots including Wildcard; prevent bypass via alternative commands and invalid restrictions that eliminate required policy options.
- [ ] Clarify defensive rights and treaty effects on ongoing fleets; defer breakable treaties and multilateral agreements unless approved.

## Phase 7 — Match pacing and polish
- [ ] Playtest the full loop at 1× for 1v1, four-player and larger team matches. Balance travel, economy, construction, conflict, negotiation, and antimatter timing toward typical 10–30 minute matches.
- [ ] Assess strategic variety, meaningful decisions per minute, runaway leaders, comeback options and AI competence.
- [ ] Audit policy readability, map targeting, formation visuals, economy feedback, constrained-window layout and multiplayer behavior.
- [ ] Keep existing two-/three-peer ENet, disconnect, simulation, parsing and startup regressions mandatory; validate UI manually and real internet behavior separately.

## Deferred / not yet agreed
- Formal galactic votes, complex treaties, elaborate tech trees, additional playable races, ship customization and campaigns.
- Exact policies, capture and retreat rules, formation geometry, cooldowns, antimatter victory threshold, and supply mechanics remain open.
- Steam integration remains a future goal; preserve direct-IP multiplayer.

See [THOUGHTS.md](THOUGHTS.md) for observations and suggestions that have not yet been resolved.

- [ ] Validate finite origin-system ship maintain targets, unlimited repeat and replacement scheduling (v0.14.0).

- [ ] Validate local population growth and live local resource breakdowns (v0.14.1).

- [ ] Profile large matches; cache military graph and shortest-path trees locally (v0.14.3); consider all-pairs prewarming, civilian routing and GPU territory optimization after benchmarking.

- [ ] Validate logistics lens capacity bars and cargo direction indicators at wide and close zoom (v0.14.4).

- [ ] Benchmark conservative territory tile rejection and visually compare boundaries at all zoom levels (v0.14.7).

- [ ] Validate 10× time controls and persistent mining route trees (v0.14.8); benchmark five-, six- and eight-player stress matches.

- [ ] Validate pre-arming repeat upgrades and numeric-only ship limits (v0.14.9).

- [ ] Validate civilian stock access caps for all consumed resources (v0.14.10).

- [ ] Validate freighter compartments, perimeter indicators and habitation technology (v0.15.0).

- [ ] Validate contextual construction cancellation rows (v0.15.1).

- [ ] Validate maintain targets persist when production is unavailable (v0.15.2).

- [ ] Validate production modifier bounds and extraction balance (v0.15.3).

- [ ] Validate optional performance overlay (v0.15.4) and record sustained fleet-heavy 10× measurements before deeper snapshot optimization.

- [ ] Visually validate segmented global resource strips at constrained widths (v0.15.5).

- [ ] Validate population segments, live growth breakdown and modifier-only habitation descriptions (v0.15.6).

- [ ] Validate timed repeatable economy buildings and independent trade switches (v0.16.0).

- [ ] Integrate orbital shipyard combat targeting, destruction and docking; validate assembly visuals (v0.16.2 prototype).

- [ ] Validate miner stand-off, extraction beams and thrust particles; profile hundreds of visible hulls (v0.16.4).

- [ ] Validate colony-to-shipyard conversion, revised recipe and orbital morph (v0.16.5).

- [ ] Validate shipyard combat/destruction and launch positions, compact trade toggles and latest HUD changes (v0.16.9).

- [ ] Validate v0.16.17 local UI scaling, saved audio settings, economy card consistency, neutral trade sliders and sequential shipyard row visibility.

- [ ] Manually validate map interactions, economy panels, shipyard visibility and settings; detailed automated UI assertions retired by explicit project decision in v0.16.20. Maintain gameplay coverage through authoritative rules and session tests.

- v0.16.21: shared authoritative cohort dispatch for human and AI rally, reinforcement and routing; existing AI exclusive-wave and human multi-cohort behavior retained. Full operation ownership and policy integration remain outstanding; validation pending.

- [ ] Manually verify compact menu settings rows and non-wrapping Music/SFX labels at every supported UI scale (v0.16.24).

- [ ] Manually verify two-column solo setup, roster scrolling with eight players, and optional seeded galaxy (v0.16.25).

- v0.16.26: operation snapshots track deployed, rallying, recovering and in-transit membership; persistent AI wave ownership remains outstanding. Validation pending.

- [ ] Measure CI runtime after scoped multiplayer matrix and import cache (v0.16.27). Evaluate safe reuse of validated identical merge trees separately.

- [ ] Run eight-peer stress validation manually before major releases; routine extended CI uses three peers (v0.16.28).

- v0.16.29: AI wave objectives and reserve rally anchors are independent of movement destinations; verify stable operation identity during withdrawal. Full persistent ownership across wave completion remains outstanding.

- v0.16.30: persistent AI attack operation ID survives regrouping and subsequent launches; reserve group remains separate. Validation pending. Unified command model and policy integration remain outstanding.

- [ ] Verify v0.16.31 construction card sizing, inline progress and economy automation, including multiplayer command validation and manual UI inspection.

- v0.16.32: baseline housing growth ceiling reduced to 5 million at normal system size; retain size scaling and doubling per habitation upgrade. Playtest demographic pacing.

- v0.16.33: basic hulls cost 500 people each; colony hulls transfer 100,000 settlers. Review opening growth and colony viability with unchanged starting population and food supply.

- v0.16.34: logistics crews 2,000, mining crews 750, fighters 500, colony settlers 100,000; assess early economic and AI pacing.

- [ ] Raiding: small fighter cargo inventory, recover hostile cargo and deliver to owned systems. Escort: bounded civilian convoy waiting and fighter escort. Expansion: automatic neutral settlement without flags. Public policy/warmup visibility for warning; future diplomacy uses unique card instances.

- v0.17.0 policy foundation: replicated optional slots, unique card IDs, locked wildcard, warmup timestamps, validated friendly/hostile targets and normalized weight command. UI, actual fleet dispatch, research and economy effects remain separate follow-ups.

- v0.17.1: prototype bottom card strip, modal card selection and drag to matching modal slot, contextual right panel, warmup countdown, army slider and map flag interaction. Manual verification and actual military dispatch pending.

- v0.17.2: human Invasion/Guard objectives feed existing fleet allocation and cohort dispatcher; weights normalize on equip/remove, invalid targets are cleared each tick. AI migration and distinct policy operations remain outstanding.

- v0.17.3: first economy effects and automatic idle colony dispatch. Existing local build controls supply colony ships. Research, additional modifiers and balancing pending.

- v0.17.4: compact visible slot headers, actual-slot drag/drop, compact in-scene card picker, exclusive right inspector and separated time controls. Defer deeper technology progression per user direction. Manual visual/drag validation pending.

## Policy brush-zone replacement (approved; implementation in progress)
- [x] Initial pre-commit left-paint/right-erase brush editing and graph-connected A/B/C zone labeling (v0.17.8; visual validation pending).
- [x] Initial per-zone editable military allocation sliders, read-only sliders for other committed military policies, and individually unchecked-by-default void toggles (v0.17.8; validation pending).
- [x] Initial atomic zone commitment with draft preservation, same-card replacement, warmup reset and locked inspector (v0.17.8; validation pending).
- [ ] Preserve unallocated fleet reserves (totals may be below 100%), enforce cross-policy limits, reconcile overriding policy lifecycle, and migrate AI fleet orders to the same policy system.
- [ ] Validate multiplayer RPCs, authority, connectivity, splitting/merging zones, replacement, resource allocation and manual map UX.
- v0.17.7 branch groundwork: authoritative atomic zone commitment, stored zone weights and void selections, fleet policy weight aggregation. UI and full allocation/validation behavior are not complete.

- v0.17.9: zone draft brush, graph-connected component list, per-zone sliders, per-policy void checkboxes, host RPC and home reserve fallback pushed to draft PR #83. Remaining: correct stable allocation preservation across merge/split, paint geometry/visuals, AI migration, tests and CI.

- v0.17.14: Fix painting mode visual feedback, persistent brush marks, stroke interpolation, panel hiding, and eligible-target feedback. Manual visual validation still required.

- v0.17.15: Replace stacked brush circles with shader-rendered union and derive disconnected zones from overlapping painted geometry rather than star-lane links; initial allocation defaults to 100% and sliders update labels. Pending visual verification.

- v0.17.16: World-space policy brush shader projection now uses the map's inverse projection on every zoom change; validate zoom anchoring visually.

- v0.17.24: Human painted-zone commitments and eligible AI system invasions use the shared fleet allocation/cohort dispatcher. Authoritative maximum five zones, locked committed weights, explicit voids remove only the chosen policy on acceptance, warmup holds forces at home, and unused allocation remains reserve. Add fleet counts to the existing inspector and actual zone RPC coverage to the ENet tests. Legacy AI pursuit of hostile ships outside eligible systems is retained; AI defensive policy selection and manual gameplay/visual validation remain outstanding. Multiplayer AI empire IDs are positive and outside the ENet ID space; bots remain ready when teams change.

- v0.17.25: Fix stale zone label indices during erasure by caching world-space label positions, hiding labels while erasing, and finalizing drags released outside the map. Manually verify erasing the last zone, drawing again, and clearing one of multiple zones.

- v0.17.26: Replace brush stamps with freehand world-space lasso selecting discovered system and asteroid-field centers, each represented by a selection circle and exact apportioned percentage on card hover or inspection. Up to five independent zones; right-lasso removes POIs, including entire zones; existing zone members retain their allocation when drawing additional zones. Both military cards accept all enclosed POIs, including friendly staging and neutral objectives; combat remains hostile-only. Explicit human invasion groups smaller than three deploy after warmup instead of stalling indefinitely. Validate manual mouse interactions and fleet travel, plus small-group/field authority and ENet regression coverage.

- v0.17.27: Clarify that both Invasion and Guard accept empty/neutral objectives. Add full simulation arrival, holding, and territory regression for both policies at an unowned system and asteroid field; no automatic colonization or conquest.

- v0.17.28: Remove legacy direct troop slider lens and its input handlers; retain logistics and policy controls. Idle same-owner, same-kind ships share local moving formations of up to three, with authoritative bounded movement and existing task/combat/withdrawal priorities. Legacy allocation rules/RPC retained for compatibility; manual visual validation outstanding.

- v0.17.29: AI chooses Invasion and Guard through the shared policy commitment path. Provisional home reserve and local hostile-fighter threat weighting, stable objectives/warmup on reallocation, neutral/field enemy objectives, actual shared fleet dispatch. Legacy wave helpers remain for prior regression fixtures; AI invasion rally minimum stays three. Playtest defense response, expansion and attack balance before conquest.

- v0.17.30 conquest prototype: active positive-allocation Invasion, physically stationed fighters, destroyed shipyards, no opposing non-withdrawing fighters in weapon range, 20 uninterrupted game years. Capture transfers system population, stock and completed civilian infrastructure, refunds queued work locally, clears PDS and automation, removes former home designation. Strongest occupying empire wins allied ties by stable ID. Map shows capture progress. Provisional rules for playtesting, not final balance. Future work: civilian rerouting during territorial change, PDS destruction, last-system elimination and victory.

- v0.17.31: Planetary defenses have provisional 100 HP, can be destroyed by fighter fire with simultaneous damage, and block conquest until cleared. Captured-system trade/mining routes are rerouted to reachable friendly destinations without teleportation or cargo loss; off-lane miners return to their physical anchor before evacuation. Fighters whose repair destination is lost resume orders when no safe replacement exists. Colony ships retain existing all-territory routing. Elimination and victory rules remain separate design work.

- v0.17.32: Evaluate elimination and last-team conquest victory on authority; colony ships preserve recovery opportunity when neutral systems remain, including AI in exile. Replicate eliminated roster and immutable outcome, freeze simulation, allow spectator snapshots/return, block further gameplay commands. Single-team sandbox exempt. Provisional elimination and result modal pending visual validation; antimatter victory still undefined.

- v0.17.33: Prototype central antimatter deposits, opt-in autonomous mining, physical cargo and local raw stock, and transfer of stored material on conquest. Processing, technology use, AI objectives and victory scoring are not implemented yet.

- v0.17.34: Standardize Godot scripts and shaders on tab indentation, add EditorConfig and a mandatory CI indentation gate. No gameplay changes.

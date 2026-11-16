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
- [ ] Define policies as behavioral instructions with specific targets where relevant, rather than passive stat bonuses. Design policy changes, cooldowns and validation.
- [ ] Prototype regional attack/invasion and defense objectives selected on the galaxy map (systems or groups of systems). Decide target selection UX, priority arbitration and allocation of scarce forces.
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
- [ ] Define victory condition (stockpiled processed antimatter, cumulative production or sustained rate are options), team scoring and end-of-match handling.
- [ ] Prototype the smallest functioning antimatter economy and victory loop. Decide whether and how antimatter is consumed for military technology.
- [ ] Test opportunities for comebacks and alternative industrial/territorial strategies; decide if later extraction opportunities are helpful.

## Phase 5 — Technology, economy and Wildcard
- [ ] Design meaningful research and technology progression, including improved communications research that unlocks the Wildcard policy slot.
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
- [ ] Keep existing two-/eight-peer ENet, disconnect, simulation and UI regressions mandatory; validate real visual/internet behavior separately.

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

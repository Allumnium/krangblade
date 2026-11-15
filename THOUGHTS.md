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

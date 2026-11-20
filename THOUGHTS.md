# Warbound — active thoughts

- v0.64.32: Separation and contact correction reject distant pairs before square roots; contact accumulators use packed vectors and touched flags with original first-touch order. No intentional cadence or movement changes; floating-point boundary parity and dense-swarm benchmark pending. Dense coincident pairs remain quadratic.

- v0.64.31: Active laser hull acquisition reuses valid in-range targets between staggered refreshes. A closer enemy may wait until the next refresh; explicit attack, guard and pursuit bypass reuse. Damage accounting unchanged. Runtime and dense-battle benchmark pending.

- v0.64.30: Idle combat acquisition retries at staggered 0.2-year intervals. Active engagements and explicit attacks bypass the timer; missile acquisition and damage/cooldown accounting unchanged. New contacts may wait one or two simulation steps. Runtime and benchmark pending.

- v0.64.29: Throttle only unsuccessful automatic Harvester repair searches; successful searches and explicit orders remain per-step. New damage may wait up to half a simulation year for idle repair acquisition. Runtime and benchmark pending.

- v0.64.28: Existing logistics retry periods now use five stable hull-ID phase slots. First retries may occur sooner within the original period; initial and reset searches remain immediate. Active movement and transfer unchanged. Runtime and synchronized-spike measurements pending.

- v0.64.27: Sector pursuit reuses ordered bounding blocks per team and sector within the combat snapshot. Existing guards, range and chase transitions are unchanged; worst-case overlapping blocks remain expensive. Runtime and benchmark pending.

- v0.64.26: Missile search uses cached ordered bounding blocks, retaining structure targets, positive-team hostility and focus-fire filters. Worst-case overlapping blocks remain expensive; runtime and benchmark pending.

- v0.64.25: Laser hull acquisition prunes contiguous 16-candidate blocks by bounding box while preserving original traversal and approximate ties. Benefit depends on spatial coherence of fleet order; worst-case overlap remains quadratic. Test parity and benchmark before wider adoption.

- v0.64.24: Shared hostile candidate buckets skip allied hulls in repeated laser, missile, defense and pursuit scans. Exact weapon checks and ordering retained. Dense opposing fleets still require nearest-target acceleration; runtime pending.

- v0.64.23: Automatic Harvester repairs query nearby damaged target buckets rather than all damaged entities. Preserve snapshot coordinates, actual PDS repair positions, tie order and live damage checks. Runtime and dense repair benchmark pending.

- v0.64.22: Withdrawal planning reuses owner/site safety results within each pass, avoiding repeated full-fleet hostile scans for wounded hulls. Live movement-time checks retained; runtime and mass-retreat profile pending.

- v0.64.21: User refocused scalability on simulation architecture. Miner handoffs query nearby same-owner freighter buckets rather than all owned freighters. Original order preserved by sorting local candidates; exact range and safety unchanged. Runtime and dense-hub benchmark pending.

- v0.64.20: User profiler highlights salvage center safety and 61 debugger errors (details unavailable). Cache center membership and local two-hop reachability; retain live eligibility checks. Profile before pursuing further changes; investigate debugger errors separately.

- v0.64.19: Combat and salvage grids share ordered bucket insertion, but retain separate snapshots and cell widths because their sampling phases differ. Idle pursuit now skips friendly-only sectors entirely. Dense enemy sectors still require exact nearest search; benchmark pending. No gameplay changes.

- v0.64.18: Local territory refresh caches unchanged hull position-to-region results by stable ID and graph identity; rebuild live totals, ownership, visibility and spillover every refresh. Moving hulls still resolve exactly. Full incremental aggregation and benchmark pending.

- v0.64.17: Asteroid field batching preserves unique silhouettes using cached triangulation and combined colored triangle meshes rather than per-rock textures. Mesh rebuilt on redraw; thin edges approximate old antialiasing. Benchmark CPU upload and visual quality before claiming improvement. No gameplay changes.

- v0.64.16: Health rectangles and procedural dashed selection rings use shared GPU batches. Full-health suppression and selection semantics unchanged; ring shader uses projected model scale, with GL compatibility and layering requiring visual validation. No Codex rule changes.

- v0.64.15: Territory shader inner sector clipping now reads static near-neighbor rows rather than rescanning all sites per pixel. Conservative cutoff and original order retained; floating-point boundary parity, deep zoom and shader runtime pending. Outer site/lane scans and influence recomputation remain.

- v0.64.14: Destruction sparks and detached outlines now share existing combat instance batches, with per-primitive viewport rejection. CPU retains drift/spin calculations. Visual layering and mass-destruction performance pending verification.

- v0.64.13: Cargo fill/background and halo batches preserve fractional fills, with detailed cargo hulls instanced except science. Reuse world interpolation within a frame/revision and reproject after camera movement; isolate mutable draw poses. GPU motion interpolation deferred until shared transforms can preserve picking, beams and cargo alignment. Runtime/visual/benchmark pending.

- v0.64.12: Combat effect geometry submitted as two GPU quad batches; exact existing times and endpoints retained, offscreen bounds rejected. Beam edges simplified, layering and GL buffer/shader behavior require runtime review. No simulation or Codex rule changes.

- v0.64.11: GPU canvas shader replaces per-hull exhaust polygons and CPU spark loops with one MultiMesh batch; retain acceleration-driven thrust, pause and zoom gating. Detailed cargo-free hulls now batch too. Exhaust visual approximation and layer ordering require manual review; GL shader compilation/runtime and performance unverified. No simulation changes.

- v0.64.10: Distant hulls use texture-grouped GPU instancing rather than separate canvas draw commands. Batches are children of the map canvas, so hulls may overlay some existing map effects/selection rectangle; verify visual layering and correct if necessary. Detailed cargo and science overlays retain existing path. No compute shaders or renderer switch. Runtime and draw-call measurements pending.

- v0.64.9: Reuse salvage sector-center threat results per team within the existing frozen threat snapshot. Ownership and discovery are deliberately not memoized (colony conversion can occur during movement). Arbitrary wreck/ship positions remain exact; benchmark and runtime pending.

- v0.64.8: User 5× profile reports unusually high idle predicate self-time. Introduce derived activity enum and reuse idle/engaged decisions in separation; no duplicated authoritative state or wire changes. Verify timing independently, avoid caching across job/combat mutations. Target 5× scaling as well as 1×; runtime measurements pending.

- v0.64.7: Camera follows arithmetic mean of surviving selected ship poses rather than bounds midpoint; an isolated ship has 1/N influence. Extremely distant stragglers can still shift the mean; monitor before considering robust trimming. No zoom change.

- v0.64.6: Combat already uses weapon-range cells but move-only ships redundantly scan every ship in their sector for hostile presence; compact sector/team presence removes that hot O(N²) path in crowded sectors. Remaining nearest-hostile whole-sector pursuit can still be quadratic under dense battles; profile before altering tactical priorities. Runtime and peer tests pending.

- v0.64.5: Static sector AABB grid avoids scanning all sectors for point membership and influence core lookup. Exact rounded containment, preferred-node and discovery filters remain; highway lookup unchanged. Compare grid and linear fixtures, measure profiler and headless workloads. Runtime pending.

- v0.64.4: Avoid rebuilding field topology signatures for the same map object; retain structural comparison for replacement snapshots. Same-object topology is assumed immutable during a match; future topology edits need explicit invalidation. Cache squared neighbor lengths and reject points outside the sector disk before radial clipping. Exact formula retained; runtime and profiler comparison pending.

- v0.64.3: User profiler Self view highlights sector_limit, combat and field-position reconstruction. Prioritize static sector/field geometry caching; compare identical workloads. Missing upgrade badge metadata was read before initialization; guard access explicitly. Runtime verification pending.

- v0.64.2: Mixed fleet command focus is client-local and cycles owned hull types without dropping selection. Commands including contextual movement apply to the active type; inspect usability and Tab focus handling in play.

- v0.64.1: Synthetic fleet stress harness reports timing distributions, deadline misses, phase costs and live hull counts. Dense battle casualties change workload over time; compare counts and identical seed/options. No measured baseline yet; graphical and ENet workloads remain separate.

- v0.63.1: Screenshot showed dangling/disconnected corridor lines. Previous union rim was masked by independent core/near-lane tests; replacement draws shared fill/rim contours for individual assigned regions. Additional lane overlap checks may increase GPU cost in corridor pixels; measure and carry into cached territory geometry roadmap. In-game appearance unverified.

- v0.63.0: Spillover uses uncapped direct totals (500 contributes 25 at 5%), never received influence. Check color readability at hubs with many strong neighbors; connected region adjacency does not jump over highway sections.

- v0.62.3: Fixed four-row shipyard deck uses blank slots for locked classes; mixed-level selections retain applicable upgrade buttons after unlocked ships. Check hotkeys and refresh on upgrade completion.

- v0.62.2: Long highways split into equal influence sections using center-to-center length (conservative cap; exposed sections can be shorter near sector cores). The cached layout leaves navigation untouched; verify seams and fog filtering visually.

- v0.62.0: Raw influence is normalized above 50; opposing player colors may blend toward gray even at full intensity. Check contested readability and performance on large fleets. Derived from snapshots; static geometry textures remain cached.

- v0.61.3: Formation ghosts reuse replicated order data without new state or per-hull route drawing. Check overlapping queued destinations and dense fleet readability.

- v0.61.2: Corridor junction smoothing is visual-only and slightly rounds the silhouette near intersections. Check whether the subtle visual margin affects edge clicks; minimap retains compact topology markers.

- v0.61.1: Removing star-hit exceptions makes overlapping objects selectable based on their actual art. Check dense layouts and minimap overlap at overview scale.

- v0.61.0: Lane outlines now follow real connections. Check corridor width/overlap at busy junctions and field access; route anchors remain metadata, not a physical midpoint boundary.

- v0.60.1: Scouts now join military fleets and pursue targets; observe whether their higher speed causes separation from attack waves.

- v0.60.0: Extended gap outlines evaluate nearest POI boundaries across the map; benchmark shader cost. Retreat is now opt-in even for armed Harvesters and AI; observe combat survival.

- v0.59.1: Higher HP with unchanged damage/repair rates lengthens engagements and repairs, especially station assaults. Neutral territory outlines expand shader coverage; profile large maps.

- v0.59.0: Fighter sustained damage falls from 18 to ~5.33 HP/s at 1×; watch combat pacing, AI waves and station assault balance. Blaster projectiles are cosmetic tracers of authoritative immediate damage, avoiding per-projectile replication.

- v0.58.10: Larger capital art preserves existing physical avoidance and combat ranges; observe visual overlap and consider size-aware formation spacing separately if needed.

- v0.58.9: AI capital investments favor home yards; monitor crystal imports and early defense pacing. Remote salvage uses safe two-hop waypoints and a sparse cell search; profile large wreck fields and watch for detours through gap space.

- v0.58.8: Explicit holds are immovable obstacles rather than repelling each other; verify close formation and post-repair return. Resource planet palettes retain subtle variation without masking dominant color.

- v0.58.7: Colony dispatch uses route distance and excludes held/busy ships; queued Hold/Stop act at their turn and later queued orders can supersede them. Inspect discoverability and queue display in playtests.

- v0.58.6: Exhaust derives from local motion revisions rather than adding replication fields; tune acceleration dead zone, fade and plume length in visual playtests, particularly for arrival corrections and guest packet loss.

- v0.58.5: Consolidated station shipyard controls use grouped selection and automatic free-port allocation. Check readability and group behavior as yards complete or are destroyed.

- v0.58.4: Idle repaired hulls remain stationary while beams operate; wander is deferred until all repairs resolve. Check crowded repair formations and balance with doubled throughput; passive regeneration unchanged.

- v0.58.3: Precise off-sector moves retain a routing anchor, not sector membership. Check gap combat, subsequent autonomous work, hold and repair detours during playtesting.

- v0.58.2: Harvesters with both modes enabled search a wider sector-local salvage radius; monitor travel time versus asteroid throughput and contention with freighters. Safety, cargo return and explicit orders retain precedence.

- v0.58.0: Three-year planetary upgrade deliveries use the existing queue and are not independently targetable; inspect pacing, arrival legibility and cancellation salvage position. Station remains free to fabricate the next job.

- v0.57.1: Cached per-kind/color hull textures and early viewport culling reduce draw work; benchmark before changing simulation. Dynamic cargo and effects remain separate.

- v0.57.0: Missile damage is resolved at launch; projectile trail is cosmetic. Playtest 1200 range, 12-second cooldown and capital costs; Destroyer needs upgraded warehouse.

- v0.56.12: Population bar now uses habitation ceiling rather than food equilibrium; food shortage may halt growth before the bar fills.

- v0.57.2: Planetary cargo capsules are quarter-size visual transfers, not combat hulls; check resource-color legibility at distant zoom.

- v0.56.10: Planet details share particle source allocation; absent matching colors use first-body fallback, and matching bodies divide output equally.

- v0.56.8: Separate command hint text from native tooltip_text; keep descendants mouse-transparent to avoid recursive hover popups. Verify in editor.

- v0.56.7: Planetary particle streams represent aggregate production, distributed over matching bodies (fallback first body). Watch raiding balance and visual clutter.

- v0.58.1: Group line is a direct intent indicator, not a navigable path. Individual route legs and queued connectors remain single-selection-only; inspect group line legibility with distant or split fleets.

- v0.56.5: Observe moving freighter handoffs and repeated depot replanning if receiver fills or leaves range.

- v0.56.4: Check yard upgrade icon legibility at tactical zoom, especially with concurrent yard and station jobs.

- v0.56.3: Previous new hull art did not match typed dictionary declaration. Explicit vector shapes and panel layers now present; inspect visual scale and large-hull overlap.

- v0.56.2: Compact star hit radius is bounded in screen pixels; check accessibility at extreme zoom and overlapping field outlines.

- v0.56.1: Verify faster tooltips do not obscure neighboring command cards; check long Roman numerals on repeated economy buildings.

- v0.56.0: Cruiser and Destroyer use stronger single-volley weapons and slower speeds as provisional balance. Assess capital ship pacing and Scout utility.

- v0.55.11: Baseline station defenses make expansions harder to rush; assess four-emitter upgraded station balance during contested matches.

- v0.55.10: Inactivity timer replaces first-load timer; monitor sparse miner arrivals and partial shipments. Manual unload remains available.

- v0.55.8: Twin repair beams represent existing per-hull repair throughput; monitor visual clutter and crowded station standoff. No shared repair capacity added.

- v0.55.7: Class-grouped yard card keeps unavailable hulls and upgrades visible to explain progression; verify captions at reduced UI scales.

- v0.55.6: Station hub shows one icon/bar per active production lane. At mid zoom, multiple concurrent jobs may be small; verify legibility. Stop cancels lane travel without teleporting; check subsequent autonomous routing from between sectors.

- v0.55.5: Cargo handled is pickup plus dropoff, not unique tonnes; farm production tracked separately and antimatter units excluded. Kill credit uses deterministic lethal-shot ordering for simultaneous fire. Larger transfer range may affect crowded docking and logistics throughput.

- v0.55.3: Escort uses existing follow protocol with guard intent; verify tether and pursuit behavior during fast target travel. Passive hull healing may change prolonged low-damage combat; check balance. Active Attack and Attack Move share the existing command button.

- v0.55.1: Recent same-link/resource records use the midpoint bay of transferred quantity; large transfers spanning multiple bays show a representative stream. Bounded 192-link history may omit effects in busy hubs. Profile snapshot overhead.

- v0.55.0: Medium-yard prerequisite may delay AI expansion; verify upgrade funding and colony timing.

- v0.54.3: Local avoidance examines at most 24 hulls per nearby grid cell and steers around the closest forward blocker. Dense swarms and shared endpoints can still overlap; profile at eight players and look for oscillation or traffic congestion. Fast unloading is limited by tick size, cargo and storage space.

- v0.54.2: Berth scoring favors clearance over shortest approach; very crowded stations may not have enough space for all hulls. Check jitter and throughput. Guard is a fighter-only sector defense with a chosen return point; verify edge pursuit and emergency repair behavior.

- v0.54.0: Collect Antimatter uses a dual-purpose icon (left target, right toggle); verify tooltip discoverability and mixed-fleet slot placement. Science holds remain non-unloadable pending antimatter usage design.

- v0.53.7: Passive handoff uses pre-movement positions; very fast opposing ships could cross transfer range between simulation ticks. Monitor logistics throughput and whether staged or moving receivers compete fairly.

- v0.53.6: Freighter 6 t/yr unloading follows its 3 t/yr salvage pickup rate; review throughput with 100 t holds and instantaneous warehouse loading. Sector pursuit can tie up fighters longer than the old three-year chase. Test dense fleet costs and boundary transitions.

- v0.53.5: Mild overlap is intentional; check contact jitter at mining/docking endpoints. Depot-facing staging leaves a 20% handoff margin; monitor miners on dispersed rocks and whether depot selection should account for multiple resources.

- v0.53.4: Local orbit prediction is capped at 0.6 real seconds to prevent drift on stalled snapshots; verify catch-up on lossy connections. Exhaust acceleration is estimated from received positions, so contact corrections and irregular sample timing may affect its intensity.

- v0.53.3: Exact station arrival and contact correction can conflict. Docking radius preserves physical delivery and avoids chasing a shared point; monitor very crowded docks and repeated export/redeposit when demand changes.

- v0.53.2: Larger distant ship markers improve readability but may obscure densely packed fleets; verify map click selection without changing world separation or station art.

- v0.53.1: Construction cancellation salvage is persistent to guarantee 100% recoverability. Monitor debris accumulation and salvage competition near busy yards; later-yard repricing still returns only the price difference directly.

- v0.53.0: Colony ship farming rate provisionally 5 t/yr (20 years per hold); watch food balance and idle fleet logistics. Auto-delivery pauses production while unloading; colonization transfers carried Organics.

- v0.52.0: Science vessels retain a full containment chamber at the Pulsar. Existing finite reservoir preserved; prototype price 900 Metals, 30 Organics, 2,000 crew, 15 years at level one. Review whether unlimited source, different costs or auto-collection controls are desired later.

- v0.51.10: Previous soft steering skipped many occupied endpoints; bounded post-movement spatial correction covers these. Watch crowded dock jitter, extreme-density residual overlaps, contact displacement versus speed budget, and high-speed interpolation.

- v0.51.9: New 10:1 hauling ratio supports on-site collectors. Monitor whether the unchanged five-year minimum mining stay and eight-year partial freight dispatch cause underfilled or inefficient trips with these capacities before retuning.

- v0.51.8: PDS service references previously placed repair at the star. Separate actual repair position from established combat range; use authoritative elapsed for planet rendering so repair aligns on all peers. Check snapshot-driven orbital smoothness and overview markers.

- v0.51.7: Three trade resources no longer need the former tall trade wing. Size it to actual content with a small expansion cap; check 100% checkbox text width, scroll and Return accessibility at minimum viewport.

- v0.51.6: Higher default import/export thresholds retain more local stock and may reduce trade opportunities until warehouses accumulate resources. Monitor early fleet utilization and existing AI-specific trade policies.

- v0.51.5: Loaded freighters should dock while blocked on storage. Check station congestion and retry behavior when all warehouses are full; single-unit order lines should remain readable at different zooms.

- v0.51.4: Shorten mining/salvage delays and eliminate repair cooldown; existing order/arrival timestamps are shared but durations vary by mode. Monitor automatic repair precedence after movement and early civilian job resumption.

- v0.51.3: Starter logistics ship supports the new resource-hauling loop immediately; monitor opening mineral throughput and AI production pacing before changing costs or fleet ratios.

- v0.51.2: Persist follow by hull ID rather than a sampled world point. Monitor spacing of large escort groups and tracking of moving targets through fields/lanes; same-speed ships may require time to catch up if they start well behind. Follow uses ordinary manual navigation and does not force a new movement speed.

- v0.51.1: Use cached soft local resource halos rather than global bloom; watch dense cargo bay readability and overdraw in large debris fields. Move field mining rules from checkbox section to stable bottom command-card row, keeping the existing authority and per-player policy.

- v0.51.0: Logistics idle resource staging turns miners into collectors and freighters into haulers. Existing 30 t logistics capacity is smaller than 60 t miner capacity; tune fleet ratios, 8-year partial dispatch, site selection and safety in play before adjusting capacity or adding more controls. Larger salvage sites use spatial-cell aggregation, so debris straddling a cell boundary can be missed.

- v0.50.3: Explicit Wander enable should skip its remaining cooldown rather than force the player to wait. Preserve other cooldowns and active orders. Four bottom slots suffice per hull; mixed miner/logistics selections require a fifth control just above.

- v0.50.2: Layered star circles looked diagrammatic; bounded shared textures provide granulation and soft coronal detail with inexpensive zoom-gated sparks. Check extreme zoom texture softness and first texture-generation cost. Fixed stale per-frame repair autocast border lookup left by v0.50.0 (manual Repair no longer owns an auto border).

- v0.50.1: At galaxy zoom, ships/structures benefit from up to 4× visual-only enlargement. Keep star selection precedence when orbital centers overlap; monitor fleet clutter and low-zoom detail cost in eight-player games. Station minimum radius remains 5 px to avoid multiplying an existing artificial floor.

- v0.50.0: Expose autonomous ship behavior via independent enabled borders and radial cooldowns rather than hidden wandering. Default modes preserve low-micro play; monitor manual mining completion, cargo retention and mixed selections. No change to defensive combat or emergency withdrawal.

- v0.49.2: Star targets should read as sector objectives rather than individual destination silhouettes. New authority-computed entry point is one world unit inside the incoming boundary; observe overlapping fleets and rounded shared boundaries. Keep free-space formations and explicit contextual actions unchanged.

- v0.49.1: User reported immediate post-move wandering prevents issuing Hold in time. Use a 20-year authoritative arrival deadline, not persistent hold or wall-clock time. Watch overlapping single-point arrivals during the grace period and civilian delay in resuming profitable jobs; explicit orders remain immediate. Verify guest poses/status and AI movement pacing.

- v0.49.0: Screenshot confirms Codex version label wrapping one character per line and stretching Close vertically. Use nonwrapping header labels and a centered compact button. Check actual header and scroll bounds; confirm hotkey editor stays bounded, and local preferences persist without sending network commands.

- v0.48.0: Standard SC2 action keys map to existing Warbound button callbacks, with mnemonic bindings for unmatched production/structure actions. Check badge/icon overlap at minimum slot size, Escape priority and input isolation. F1 idle-worker selection, camera location shortcuts and further control-group variants are not implemented in this pass.

- v0.47.1: Compact command icons previously mixed thin line strokes, raw resource glyphs and ship portraits. Use solid silhouettes, deliberate negative space and secondary semantic accents; distinguish construction facility art from stock icons. Verify readability at minimum slot heights and against disabled/selected states before further stylization.

- v0.47.0: Edge scrolling uses a 12-pixel margin and pauses while mouse buttons are held to avoid inadvertent camera motion during selections, formations and UI drags. Check windowed focus transitions and bottom-console edge behavior in live play.

- v0.46.2: User screenshots showed the Codex extending beyond the screen and passive cells resembling buttons. Replace the content-sized AcceptDialog with a bounded exclusive Window and explicitly anchored layout; use a fixed article viewport and always-visible scrollbar. Verify in-game at 1152×648 and larger, including long population article and short-window navigation. Runtime/visual verification pending.

- v0.46.0: The Codex provides an in-match reference for otherwise hidden economy and control rules. Derive numeric examples directly from shared simulation constants; verify legibility and avoid stale prose when mechanics change. Opening the local guide should never pause a shared match.

- v0.45.3: Slower population and the new fixed food reserve reward local farming and delivered imports, but empty colonies with low farm output may take longer to replenish crews. Monitor colony timing, the existing 40k settler cost, AI expansion, food export settings, dependence on installed orbital populations and whether a 200 t target feels appropriate. Do not rebalance unrelated costs before playtesting.

- v0.45.2: Follow-up to v0.45.1: Return was placed in the shipyard action grid's second row, not at the bottom of the command card like the Build submenu. Move it into a separate bottom-aligned footer beneath the two-row action grid; preserve all action positions and selection-only behavior. Manual interaction verification remains pending.

- v0.45.0: The three-resource economy removes duplicate industrial bottlenecks. Basic hull construction is independent of crystal acquisition, while PDS, additional shipyards and Laser Matrix need Crystals. Removing costs without redistributing them preserves existing metal/crew/time gates but may accelerate production or change AI pacing. Metal Refinery now costs Organics, so food-poor colonies may need imports. Validate balance, exact seeded map differences, local recovery and actual multiplayer before marking complete.

A running log of potential issues, UX improvements and gameplay ideas noticed during development. These are observations and proposals, not approved tasks. Use stable identifiers; label verified issues versus hypotheses, and keep entries concise. Update or deduplicate existing entries. Once an idea is resolved, move the full entry into THOUGHTS_ARCHIVE.md with its outcome and evidence. Approved work belongs in TODO.md.

## Active observations (v0.8.0)

- v0.44.2 / T-014 follow-up: Repeated seeded planetary attributes now share an initial template, with per-snapshot full planet fallback on unexpected changes. Host AI wave scheduling and operation allocator counters are not consumed by guest UI; keep operations, AI roster, movement, and dynamic economy data. Half-float heading components reduce pose records from 24 to 20 bytes without reducing position or ID precision. Added exact planet reconstruction/fallback, compressed-size, heading error and live peer compact receipt checks. Godot runtime and bandwidth measurement pending.

- v0.44.1 / T-014 follow-up: Static map generation is immutable after creation except rock remaining inventory and removal on depletion. Send the authoritative initial template once, then encode ore differences against it (not chained deltas); full live map fallback for changed topology. Skip identical ship poses between periodic 1 Hz refreshes, preserving periodic reliable state and independent motion revisions. Added exact codec round-trip and real-peer compact-state checks. Measure payload/encode cost with dense fleets and late depletion; no gameplay or simulation time changes. Runtime validation pending.

- v0.44.0 / T-014 follow-up: User reports noticeable guest lag; screenshot shows 35 FPS, 25.42 ms simulation, 4.17 ms encoding and 30.2 KiB compressed state. Verified full reliable state was ACK-gated at 5 Hz, with fixed 200 ms render interpolation. Separate small revisioned 10 Hz unreliable pose batches from 2 Hz reliable state plus urgent command updates; retain authority and lifecycle snapshots. Adaptive render blending is an initial mitigation, not a timestamped jitter buffer. Measure real loss/jitter, bandwidth scaling, pause and dense combat before reducing state further; dynamic asteroid inventory is part of map state and cannot be treated as immutable geometry without splitting it.

- v0.43.8: Larger queue tiles improve recognition; small middle panels will need scrolling sooner when multiple rows wrap.

- v0.43.7: Large center panels no longer separate resource names from their figures across the entire panel; keep the compact width readable as stock values grow.

- v0.43.6: Center queue tile blocks within the remaining detail area; check long wrapped queues on small windows and maintain access by scrolling if needed.

- v0.43.5: Removing fighter holds simplifies combat and prevents salvage distraction; check that miners prefer nearby safe debris without monopolizing mining time. Tons are now displayed consistently without changing authoritative resource values; check large stockpile text at small resolutions before any balance rescaling.

- v0.43.4: Sequential station construction prevents buying parallel build time with a large stockpile. Check build-order pacing (including AI), repeat queue ordering and whether twice-range PDS makes nearby approaches overly costly. The shorter Trade wing may require scrolling at smaller resolutions.

- v0.43.3: Planetary defense combat references intentionally retain sector-star simulation positions; movement clicks now use rendered orbital coordinates. Review whether a future shared authoritative orbital model should also move combat/repair range origins to individual bodies. Camera focus now has a world-space source of truth; check apparent centering against the usable viewport (not the central star when a separate shipyard is selected).

- v0.43.2: Population-starved pinned jobs previously occupied active shipyard slots. Releasing them preserves queued investment and lets eligible work proceed; review prolonged colony-ship wait times with continuous cheap-hull production. Single-ship facing preview reuses the existing authority-validated arrival heading; ordinary idle flight may turn again after arrival.

- v0.43.1: Larger ore deposits extend useful mining lifetimes without increasing throughput; crystal scarcity is now a cap on initial tonnage, not on the number of rocks. Watch bootstrap crystal availability and prolonged salvage clutter. The Trade wing extends independently of the console footprint, preserving the existing camera and other HUD panels.

- v0.43.0: Civilian salvage search is conservative around hostile sectors/armed patrols, and idle collectors now finish gathering before normal logistics resumes. Check pickup versus mining/freight priority and crowded neutral lanes; minimap marker hit radius may warrant tuning in dense systems.

- v0.42.2: Removed fractional viewport stretch and saved UI scale, both possible sources of fuzzy tooltips. Pixel-aligned controls/font glyphs and native-size resource textures retain antialiasing without scaling the world camera. Check native-resolution HUD capacity on the smallest supported windows; OS/display compositor scaling remains external to the game.

- v0.42.1: The reported station screenshots place the hub at the center of the reserved map viewport, rather than the entire window; fallback to the rendered station position and preserve projection precision at extreme zoom. Recheck camera feel with the stepped console and tooltip readability near screen edges during play.

- v0.42.0: Removed AI's instant orbital housing bypass and timed previously quick warehouse/habitation jobs. Review construction pacing with limited colony materials; preserve prepaid refunds. Target rings deduplicate shared targets and follow interpolated ship/structure poses; check dense overlapping hulls and planet-detail transitions during play.

- v0.41.0: Stable physical shipyard ports are independent of compact production indices and price tiers; rebuilding a lost numbered port retains existing count-based prices. Station plating and matrix require larger warehouse capacity than the starter 2,000 t; review affordability, construction duration and defense strength during contested play. Old selection references still invalidate on shipyard-count changes for safety.

- v0.39.0: Exact rally convergence combined with persistent Hold Position caused crowding; release nearby hulls into idle formation flight or autonomous work. Check rally points at sector edges and very large fleets, and verify that empty console panels expose both map rendering and map input. Shared multiplayer speed changes are last-authoritative-request wins; assess player coordination during live matches.

- v0.36.3: Armed movement commands use the same gesture handler for either mouse button; the initiating button owns its release to avoid accidental orders during a two-button gesture. Check cancellation when releasing over the console (TODO phase 1).

- v0.36.2: Single-selection portraits reuse hull silhouette and panel geometry. The opening camera uses clipped sector extents rather than a fixed galaxy zoom. Check portrait width and camera framing on dense layouts and high UI scaling (TODO phase 1).

- v0.36.1: Shipyard command placement now preserves fixed spatial muscle memory across widths. Recheck compact caption legibility and command highlight/crosshair feedback in playtests (TODO phase 1).

### T-041 — Curved formation feedback and docking routes
- **Type:** UX/playtest risk.
- **Observation:** v0.36.0 places slots by arc length along the player's stroke; closely overlapping loops can place ships near each other, and station navigation offsets final lane endpoints from stars. Check dense curves and the visible station approach at multiple zooms.
- **Consider:** Review actual input feel before imposing additional spacing or simplifying the player's stroke.

### T-001 — Long routes may conflict with short matches
- **Type:** Gameplay/pacing hypothesis.
- **Observation:** The prototype's longest direct lane takes 100 game years at baseline speed; multileg journeys may consume a substantial portion of a 10–30 minute match at 1×.
- **Consider:** Measure time to first meaningful contact and reinforcement before changing speeds or map geometry. See TODO phase 7.

### T-002 — Make autonomous decisions legible
- **Type:** UX proposal.
- **Observation:** Direct fleet orders and autonomous repairs may leave players unsure why an operation diverts.
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
- **Observation:** Future promissory notes may become unenforceable if direct commands bypass obligations.
- **Consider:** Authority-level restrictions on behavior across every relevant direct command path, including clear treatment of ongoing operations. See TODO phase 6.

### T-006 — Operation identity and retargeting
- **Type:** Technical/design risk.
- **Observation:** v0.10.0 preserves operation IDs on retargeting if an old group disappears and its members transfer to a new objective; splits and merges retain exact surviving groups first. Stable formation slots across these changes still need design and validation.
- **Consider:** Test complex splits/merges and membership churn before committing to formation-slot geometry. See TODO phase 1.

### T-008 — Orbiting combat and concentrated fleets
- **Type:** Gameplay/visual hypothesis.
- **Observation:** v0.10.1 uses a common orbit direction and a provisional preferred separation of 60% of laser range; dense fleets may overlap or repeatedly lose contacts when chasing fast targets.
- **Consider:** Inspect real battles before adding separation, target persistence or a turn-rate model; integrate stable formation slots with combat maneuvers without sacrificing speed bounds.

### T-011 — Population and industrial bottlenecks
- **Type:** Gameplay/balance hypothesis.
- **Observation:** Multi-resource ship costs make local Plastics, Textiles, Organics and Tech stock actual constraints. Baseline industrial outputs and population gates may make new colonies slow to develop, while Organics also supports residents. The former 200k Tech gate has been removed; building costs and reserve-production recovery remain provisional.
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

### T-018 — Shipyard construction order (superseded in v0.43.4)
- **Type:** Gameplay/UX hypothesis.
- **Observation:** v0.12.4 permits concurrent infrastructure construction; a later shipyard can reach full progress before an earlier one and waits for the preceding slot to complete. Cancelling an earlier slot retains the later job’s percentage at the cheaper recipe and refunds the difference.
- **Consider:** Concurrent station construction was removed in v0.43.4. Check retained queue progress and cancellation refunds when later jobs are shifted down a slot.

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
- **Observation:** All players start with three miners, two fighters and (v0.51.3) one logistics ship without reducing stocks or resident population. PDS installations each fire 36 damage once per year at basic fighter range; each successive planetary installation costs three times the preceding recipe. Build one at a time per system. The shared authoritative system waypoint is the range origin; at close zoom the beam originates at the corresponding decorative planet.
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
- v0.62.1: User approved the eight-phase scalability program in TODO.md (5,000 total ships target; 10,000 stretch). Source audit of v0.62.0: combat has spatial cells but dense cells and sector pursuit still scan many candidates per hull; repair, handoff and staging contain broader fleet scans; pose synchronization runs again from _ship_poses; territory shader iterates region geometry per pixel; reliable snapshots still include ship dictionaries and pose stream is 20 bytes at 10 Hz. These are code observations, not measured bottleneck rankings. Establish reproducible baselines first, then execute the prioritized roadmap; existing validation entries remain open.
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

- v0.16.37: three-peer regression timed out while two-peer passed. Record independently observed replicated command conditions across snapshots rather than requiring simultaneous transient queue states; retain final cancellation and shipyard count checks. Log missing condition IDs to isolate remaining failures.

- v0.16.38: all ENet cases passed on v0.16.37; economy assertion at second AI neutral colony hung the process. Fund mature AI expansion test explicitly and prevent secondary colony orders from consuming populations below crew requirements. CI unit scripts fail on script errors and have a 90-second hard bound; no removal of gameplay assertions. Actual opening AI balance remains a playtest concern.

- v0.17.0: initial policy definitions are intentionally inert with respect to fleet dispatch and economic output until the interface and behavior are wired. Warmup uses simulation elapsed time. Validate normalization upon equip/remove and invalidate targets during ownership changes in the integration stage.

- v0.17.1: card strip uses clipped bottom-edge buttons and a modal drop target with click fallback. Verify scaling, keyboard focus, right-panel overlap and drag experience manually. Policy allocation currently remains separate from fleet orders.

- v0.17.2: warming/targetless military policy shares rally at home; manual POI allocation retained when no military card is equipped. Existing allocator rounds target percentages before ship quotas; inspect small fleet rounding and overlapping targets. AI retains legacy orders.

- v0.17.3: provisional +20% manufactured output/farm output and -15% non-food consumption. Expansion dispatches existing colony hulls, does not enqueue duplicate autonomous builds. Verify compact card catalog at high UI scale and expansion under competing claims.

- v0.17.4: screenshot showed clipped titles, overlapping time controls and two simultaneous right panels. Use visible compact headers, opaque contextual inspector replacing regular right panel, and a centered in-scene picker permitting direct slot drops. Verify at all UI scales; no visual tests run locally.

- v0.17.5: core regression on PR #82 encountered a legacy fixture without explicit hull kind during the expansion scan. Skip scanning when no empire has Expansion active and retain the default logistics hull kind. CI preserves up to eight diagnostic lines after script errors before terminating, subject to the existing timeout.

- v0.17.9: zone painting currently assigns system nodes within the brush and computes connected components using map lanes; visual continuous territory geometry and stable allocation inheritance when components merge/split need improvement. Check that repeated editor rebuilds do not interrupt slider interaction, and validate authority rejection of overcommitted allocations in ENet tests. No Godot executable was available in the editing environment; do not merge without CI.

- v0.17.14: User screenshot confirmed policy brush produced no visible paint and Shipyards/Economy tabs remained during draft. Fixed visible world-space brush marks and inspector refresh visibility. Follow-up: fully geographic zone semantics (not merely selected system nodes), connectivity/merge-split allocation persistence and manual UI verification.

- v0.17.15: Geometry is now derived from overlapping brush stamps and targets inside each component. Persisting actual paint masks with committed policies and ensuring map overlays are visually consistent after commit remain follow-up UX tasks. The current GPU mask caps each draft at 128 stamps; consider a texture-backed mask for larger regions.

- v0.17.16: User screenshots revealed policy zone mask drift under zoom. Render shader now compares world-space stamps against inverse-projected pixels, with explicit refresh when zooming. Check under pan and UI scaling too.

- v0.17.26: Reported invasion forces not moving; likely minimum-three cohort rule deadlocked small per-POI allocations even with warmup complete. Explicit human zone orders now rally up to three available assigned ships rather than requiring three regardless of quota. Existing AI and legacy rally rules stay unchanged. Lasso eliminates stamp limit and stale erase indices; manual interaction and actual deployment observations still needed.

- v0.17.28: Idle groups use deterministic local V formations with a shared rotating anchor inside rally range. Membership can change on new orders or casualties; bounded movement rather than teleporting handles reassignment. Check visual cohesion and crowding with large stationed fleets.

- v0.17.29: AI threat heuristic is deliberately simple: nearby hostile fighters trigger a prioritized owned-system guard order, with coarse fleet-size thresholds to preserve attack cohorts. Potential oscillation near the threat radius and distant colonies competing for protection need playtesting. Reweighting a stable objective preserves invasion warmup.

- v0.17.30: Conquest changes local ownership, and civilian routes may already be in flight through newly hostile systems. Prevent hostile loading/unloading immediately; planned-route evacuation and rerouting, last-home recovery, and PDS resistance balance need review. Capture timing/coalition tie-break are provisional.

- v0.17.31: Fixed hostile civilian route endpoints on capture and made PDS destroyable. Evacuation prefers a reachable friendly destination using either end of the current lane; disconnected civilian hulls may remain stranded until territory changes. PDS HP and repair-loss behavior need playtesting. No automatic elimination of surviving ships or colonies; decide win/loss with match objective.

- v0.17.32: Exiled empires can settle neutral systems with colony ships; elimination disbands other hulls when no recovery is possible. A surviving colony ship may prolong a losing position, particularly with obstructed or long routes. Review playtest pacing and result UI before finalizing rules.

- v0.17.33: Reuse innermost existing field geometry for one (1–2 players) or two (3–8 players) finite raw-antimatter deposits. Check seed fairness, depletion and raw storage saturation before balancing processing and victory. Extraction is initially opt-in so existing opening economy is not automatically diverted; AI extraction policy awaits the objective design.

- v0.17.34: Godot's convert-indent-on-save setting was rewriting space-indented scripts into tabs on the user's machine. Standardize on Godot's native tabs and enforce the format with the gate; check that whitespace-normalized script/shader diffs are empty.

- v0.17.35: Wider sector patrols can pull idle fighters beyond the rally and capture radius. Keep pending rally, hostile-system occupation and contested-sector groups compact; defenders physically patrolling the same sector contest conquest. Verify visual patrol paths and response times at different zooms.

- v0.17.36: Fixed-resource bay coloring implied a cargo allocation limit that did not exist. Pack the displayed bays by actual tonnage, including single-resource full loads. A free starting home PDS strengthens early defense without spending stock; validate rush balance before changing combat values.

- v0.19.0: Hold and control groups supplement direct POI orders. Manually verify selection at dense zoom, mixed groups, right-click destinations, hold and mid-flight retargeting. Free-flight and explicit attack targeting are not implemented. The opening benchmark uses allied AIs and coarse one-year ticks: three seeds reached six worlds and 12–15 fighters at year 360, versus three worlds and 3–6 fighters in v0.18.0. Food-equilibrium bottlenecks and premature crew allocation were addressed; actual contested matches, isolated colonies, upper warehouse tiers and recovery after losses require further playtests.

- v0.20.0: Upfront material costs eliminate partly funded construction; repeat/maintain requests wait outside the queue. High-tier exponential shipyard/PDS recipes can exceed maximum warehouse capacity; review progression and cap/recipe choices before changing balance. Verify opening tempo, affordability feedback and material-flow spikes. Mining assignment intentionally respects field resource permissions and five-year mining stay; validate mixed selection, rock hit-testing, retargeting and depletion fallback in play. Explicit hostile-target commands remain a follow-up. No local Godot executable; CI required.

- v0.20.1: Theoretical local resource deltas expose production surplus at full storage and deficits at zero stock, instead of presenting capacity/consumption-limited rates as expected growth. Actual flow detail remains available on hover. Check sign readability, narrow columns and full/empty warehouses manually; small magnitudes rounding to 0.0 use neutral white. No economic behavior change.

- v0.20.2: The global resource HUD uses the sum of owned-system theoretical deltas, matching the local rows rather than rolling holdings changes. One-off purchases and variable external cargo flows are intentionally omitted from the forecast and remain in actual breakdowns; population rates unchanged. Verify top-bar widths and sign colors manually.

- v0.20.3: Collapsed cards now expose the cost and nominal duration before ordering. Actual completion can vary with queue position, assigned yard and crew/population availability. Verify grid height and readability at all UI scales, including the left shipyard stack; no rule changes or local visual verification.

- v0.20.4: User reported ~3 FPS at year 1170 / 10×, screenshot sim 281.20 ms, encode 0 ms. The authority batches ten 0.1-year steps on the main thread per 0.1-second timer callback. Remove unused rolling-resource sampling and reuse checked civilian route topology throughout each substep; route cache invalidation replaces the object so temporary evacuation topology cannot corrupt an existing substep cache. Add local phase diagnostics. Hypotheses: idle freighters scan every source/destination pair per step, miner searches revisit fields/anchors/depots/chunks, retreat repair searches scan many ships, and exploration res surveys all owned planets every step. Measure before changing scheduling or fleet behavior; no local FPS benchmark yet.

- v0.20.5: Put timing details on the Perf button tooltip rather than the mouse-transparent overlay so the map retains normal input.

- v0.20.6: Replaced multi-row recipe grids with a single compact icon/amount row, removing repeated tonnage suffixes in favor of exact tooltips. Button time estimates use a runtime-generated monochrome analog clock. Check title truncation, six-input recipes and narrow inspector scaling visually; no local visual test.

- v0.21.0: Planet selection reuses the visible orbit/body coordinates and existing authoritative defense slot indices. Names are stable system name plus Roman orbital number. Any undefended slot may be selected, retaining slot-indexed pricing and one pending defense per system. Outer slots can be significantly more expensive; review PDS price curve separately. Manual visual verification of small moving bodies, ship overlap and panel scaling remains.

- v0.21.1: System-first design is explicit: individual planet selection is only a convenient redundant shortcut. The existing Economy defense card now offers every named planet, including installed and in-progress defenses, and exposes the same costs, status and actions. Verify switching planets while snapshots arrive and selection retention; no changes to payment, limits or authoritative mechanics. Foreign systems retain their existing read-only/colonization overview; their orbital planet panels remain inspectable.

- v0.21.2: Numeric Economy comparisons derive a one-building preview from a shallow system copy with separately copied building counts; existing formulas handle first production unlocks, additive bonuses, labor and extraction caps. Fixed-current-population projections are not future forecasts; farm variation and population can change before completion. Verify readable detail wrapping, capped and max-tier states, and actual post-completion effects manually. No simulation changes.

- v0.21.3: Move living ship counts into disclosure captions to keep them adjacent to ship names. Avoid / 0 when no maintain target; retain / ∞ for continuous builds. Queue counts belong to the Build button rather than a second ambiguous title number. Verify long titles and multi-digit queued counts at constrained widths; full captions and pending counts available on hover. No local visual verification.

- v0.22.0: Layouts preserve local cluster counts/degree budgets but change cluster geometry and radial outer bridges. Antimatter sites use a bounded deterministic search in central/neutral regions before ordinary fields, with minimum edge clearance and no direct starting access. Scramble uses bounded separated random centers with a jittered lattice fallback. Existing economy fixtures explicitly use Grid topology; new layout tests cover all counts and two seeds per layout. Compare opening mining and colonization, relative starting travel to deposits, and larger match performance before changing balance. Local Godot not available; CI and manual playtesting required.

- v0.22.1: Replaced radial spanning-tree topology with explicit outer/inner cycles and intermediate spokes. Local radial paths reserve bridge ports; junction limit is at least two per sector. Three-sector minimum increases galaxy size for solo/2-player radial; compare longest-link normalization and expansion pace. Central search now uses the open interior, not a central system cluster. Added seed-cached map preview, explicit rerolls and actual match seed replication. Visual legibility and balance require manual verification. Competing preset PR #119 was closed in favor of validated #118; its legacy default conflicted with the requested Radial default.

- v0.22.2: Hex Grid adds an actual honeycomb bridge network, not just shifted square-grid positions. Full even-width patches may have more clusters than 3 per player; smallest patch is eight clusters. Test all player counts, bridge adjacency/cycles, deterministic seed, protected antimatter and real three-peer replication. Compare travel balance and preview legibility; no visual or local Godot validation.

- v0.23.0: User reported missing map previews. Replace parent-driven draw signal with a dedicated Control _draw, shared setup scroll/body and larger preview; root cause not reproduced locally. Refactor shared roster and settings. Host-only seed edits reset readiness. LAN browser uses bounded JSON query/reply on separate UDP port, expiry and explicit direct-address probes; no external service, no subnet scan. Verify real LAN broadcast and firewall/Tailscale behavior manually; CI loopback discovery tests cover reply and subsequent ENet join. Internet-wide listing needs a rendezvous service/Steam.

- v0.23.1: User requested individual-system hex cells and roughly 80/20 clustered/solo sectors. Hex uses six-node rings with some adjacent vertices incorporated to reach 80%; remaining vertices are unclustered. Preserve actual honeycomb bonds and max degree three. Nonhex inserts neutral systems into existing bridge segments, preserving original fields/indices and one longest lane. Adds about 25% to the old nonhex system count; verify late-game performance and economy opening, and whether shortened hex travel is balanced. Automated graph tests check actual adjacency, standalone ratio, connections and protected deposits; visual playtesting required.

- v0.23.2: The former degree check covered only star-star edges; derived asteroid access could exceed three. Persist capped field links and share the budget with stars, prioritizing special deposits then nearest ordinary access. Existing fixture maps without access metadata retain nearest-in-range fallback. Verify ordinary field count/early mining and special accessibility after port competition. Hex blocks now have explicit empty gaps, with one nearest bridge per adjacent block; local rings remain intact. Manual visual and balance verification pending.

- v0.23.3: Multi-access physical delivery fixture now explicitly defines both access lanes, as generated fields do. The former implicit radius could select nearer neutral systems ahead of the test home under the three-lane cap. Keep the same physical delivery and conservation assertions.

- v0.24.0: Planetless sectors are deterministic map metadata rather than separate node types. Homes and one nearby neutral neighbor are protected. Neutral occupation replaces colony settlement for empty systems; existing planetary economy remains unchanged. Orbital housing values provisional; population increases only by paid additions, no upkeep, normal crew costs and industrial outputs. Review imports/AI funding and whether zero upkeep creates excessive late-game industry. Existing full-planet economic scenarios explicitly select a fixture; mixed-map tests cover generation, capture, payment, zero consumption and live peer commands. Visual verification pending.

- v0.24.1: User requested shipyard Eco-Housing, +0.2 t/yr Organics per module and usable regenerating residents. Separate tracked eco pool from total population; existing total remains authoritative for staffing/labor. Crew drawn from eco pool first and refunds restore available habitat slots without duplicating total. Fixed capacity per completed yard, no new housing from upgrades. Planetary farming uses terrestrial residents, while eco surplus is independent. Starting population rises to 15k; verify opening pacing, crew regeneration and destruction/capture. Test coverage isolates old pure-planetary formulas and exercises both housing types. Visual playtesting pending.

- v0.24.2: User requested at most eight stars per player, variable spacing, smaller ships, and automatic equal-price planetary defenses. Compact radial has two rings (solo triangular), hex uses actual six-star cycles, ordinary layouts vary cluster membership and spacing. Exact seeded field access prioritizes reserved special fields then opening ports; test small-map mining and balance. Ship geometry previously directly scaled with projection; reduce world scale and cap screen scale. PDS authority rejects explicit slot targets; planet inspector uses the same system action. Manual visual and balance verification pending.

- v0.24.3: Authored higher-detail procedural hull art with shared local geometry, distinct silhouettes and detail LOD rather than adding image files or increasing rendered size. Retain logistics cargo art and class colors. Manual visual comparison and render performance confirmation remain outstanding.

- v0.24.4: Combat kills publish bounded sequence events (128 retained) in reliable snapshots, avoiding false explosions on successful colonization or elimination cleanup. Each client renders up to 32 short-lived bursts with original hull edge fragments and panel/cargo colors; no gameplay impact. Headless tests cover combat-only event creation; visual tuning and heavy-battle performance remain unverified.

- v0.24.5: Added open-berth gantry art, reused actual hull silhouettes for work-in-progress, selectable completed shipyards and system-parity inspector using existing validated upgrade commands. Selection clears on yard-count changes to avoid stale numbered-slot targets. All laser variants use source empire hue, with brighter core. Local visual verification is outstanding; check overlap priority and legibility at low zoom. No simulation changes.

- v0.24.6: The old 64× map zoom and fixed 1.25× ship-scale cap prevented meaningful inspection of the new hull art. Preserve exact overview sizing and use viewport-relative close-up ceiling, larger hit/cull regions, and frame-local centroid tracking from the same interpolated ship poses as rendering. Manual pan releases follow; selection drag suspends it. No authoritative changes. Check high-zoom camera precision, large territory geometry and viewport clipping in manual playtesting. Prior request for more recognizable Grid/Hex Grid geometry remains separate pending work.

- v0.24.7: Found a loaded-miner waiting state that continuously docks when every depot is full; now allow sector-bounded idle flight and periodic depot reacquisition, preserving physical delivery. Added civilian movement/conservation regression. Territory display no longer derives from fleet presence; captured but undeveloped sectors retain authority ownership without tint. Shade authored panels by empire using their original luminance, preserve cargo hues, and display PDS bodies without selecting system. Actual user-reported broad civilian stall has not been reproduced visually; check all hulls on real matches and storage/route availability. Manual visual verification pending.

- v0.24.8: User reported radial lanes passing closer systems; the zero-junction bridge preference rejected available third ports before considering distance. Select closest eligible bridge endpoints and revisit assigned bridges; retaining the spider-web topology means not every node can literally connect to its three closest systems. Added a targeted regression. Fixed selection highlights leaking to same-slot defended planets in other systems and empty trapped miners abandoning retry state. Manual visual and normal-match verification remains important.

- v0.24.9: CI caught the solo smoke fixture selecting a planetless adjacent system by index after the radial edge ordering changed. Choose a planetary neighbor (still asserting one exists) before issuing the colony order; retain the physical settlement and ownership assertions. The full economy and all ENet cases passed on v0.24.8.

- v0.25.0: Approved free positioning within the current convex sector, not across sectors. Local orders move and then hold all hull classes; civilian routes/jobs remain paused while holding, and fighter withdrawal resumes the saved point via lanes. Existing POI and mining orders keep priority when clicked, Alt-right-click explicitly chooses a local point. H toggles release. Group stacks can overlap at a shared point; review formation spacing and manual input feel before any further design change.

- v0.25.1: A hull entering the next sector on its actual lane can receive a local order before reaching the waypoint center. Fighters update the occupied sector only after a physical containment check; civilians retain their planned route for resuming work and actual docking.

- v0.25.2: Refine Grid and Hex Grid geometry with regular fine cells, midpoint standalone waypoints and neighboring-block loops, with deterministic spare-port allocation and the existing star budget. Compact square cells preserve the shorter internal travel distinct from longer bridges; allied-AI opening tests still reach colonies by year 138 across all three fixture seeds. Added local-edge regularity and cluster-cycle regression checks. Manual visual verification remains pending.

- v0.25.3: Box selection had an ownership filter both when adding and refreshing IDs, and H sent the entire selected list. Unify inspection selection across empires, filter command recipients separately and summarize selected cargo rather than stale empire totals. Foreign selections are read-only; group recall retains surviving foreign hulls too. Calendar origin changes to 2850 A.D. without altering elapsed time or gameplay; year and Menu exchange HUD positions. Manual interaction verification remains pending.

- v0.26.0/v0.28.0: Destruction yields gameplay salvage alongside the bounded visual event log. Cargo drops in full; structural recovery independently rolls 75%/0–20% per material. Debris now expires after independently randomized 90–120 simulation seconds; nearby safe hulls automatically tractor debris into free cargo. Keep transport/hold/combat priority and physical unloading. Playtest whether passive fighters/colony hulls should eventually return salvaged cargo automatically; currently they retain it to avoid abandoning strategic orders. Monitor recovery balance, cargo distribution and UX.

- v0.27.0: Explicit focus targeting and patrol use stable hull IDs and existing military routes, not teleportation or policy assignments. Retreating fighters were previously counted toward AI attack and defensive cohorts; count only ready hulls, choose POI/defenders by actual lane distance. Three opposing-AI 900-year coarse simulations (Radial/Grid duel and four-player Hex Grid) expanded first at years 96/133/183, lost 70/16/36 hulls and reached 91/87/180 peak hulls, respectively; all empires retained operational economies. At the actual 0.1-year timestep the radial duel expanded at 96.4, saw first hull loss at 111.2, and recovered from 93 destruction events to 32 fighters and four systems per side. No conquest winner by year 900; don't artificially force a decisive outcome before defining antimatter victory. Balance and actual UI interaction need human playtesting.

- v0.27.0 validation: three-peer Hex Grid runs exposed degenerate hull/cargo polygons at distant zoom and transient roster/chat RPC errors when multiple guests disconnected simultaneously. Use an owner-colored hull marker only at subpixel projection, cull tiny cargo detail consistently across hulls, and send roster/chat/snapshots only to registered ENet connections that are still connected. Regression still requires independent peer completion and the actual lobby return.

- v0.27.1: Subsequent three-peer run confirmed regular hull/cargo drawing and all independent completion checks but found the same triangulation failure in construction silhouette fills. Apply distant shipyard marker and safe morph/construction fill checks. A transient engine-level ENet send warning may still occur during simultaneous disconnect; the full lobby return passes.

- v0.28.1: User requested a StarCraft-like unified bottom console instead of left/right overlays. Reserve 43% of the available window height (normally 250–360 logical pixels, clamped at small heights), keep independent scroll areas and responsive grids, and use the full-width map above. A local headless sizing probe at 880×505, 1152×648, 1280×720 and 1920×1080 confirmed reserved map/console bounds, the two-column fallback and visible ship-build cards at normal width. Actual visual aesthetics, scrolling, hover and interaction still require manual verification. Consider a user-adjustable console height only after playtesting; no gameplay changes.

- v0.28.2: User requested more compact styling and a minimap. Scope the denser theme to the console, reduce target height to 32% (195–285 logical pixels), keep independent scroll areas and fit common ship-build cards in a two-column grid. The minimap draws sector/field links, known ownership, ships and camera rectangle using the existing projection and snapshots; clicks/drag pan locally without changing orders or selection. Headless sizing probe at four window sizes confirmed camera centering to within floating-point precision and the 1280×720 console shrinking from 310 to 230 logical pixels. Manual visual and large-fleet performance checks remain outstanding.

### T-Console-29 — Raised-wing console density
- **Type:** UX hypothesis.
- **Observation:** v0.29.1 places selection details in a lower center zone and commands on the raised right wing, with a persistent raised minimap on the left.
- **Consider:** Verify legibility and scrolling at 1152×648, ultrawide and increased UI scale; evaluate whether the 20% center recess leaves sufficient selection detail space.

### T-Console-29b — True stepped console outline
- **Type:** UX correction.
- **Observation:** The prior full-width console backdrop concealed the 20% center recess; v0.29.2 draws independent left, center and right panel silhouettes.
- **Consider:** Visually check border joins and map occlusion with and without a selection.

### T-Console-29c — Three-zone console structure
- **Type:** UX stabilization.
- **Observation:** The previous layout nested both content columns under a shared toolbar and left the right commands without independent scrolling. v0.29.4 places the minimap, center, and command wing as peers, gives the center a filling detail viewport, and scrolls the right commands beneath their toolbar.
- **Consider:** Manual visual regression at 1024×576 and larger, plus multiple UI scales.

### T-Sector-29d — Cursor-to-sector targeting
- **Type:** Command UX.
- **Observation:** Right-click commands previously chose the nearest POI center before checking sector containment, potentially snapping to an adjacent sector. v0.29.5 prioritizes the simulation's sector boundary and retains direct POI click fallback.
- **Consider:** A distinct hover outline for command sectors; ownership territory outlines are not equivalent to command-sector boundaries.

### T-29e — Separate occupation from territorial ownership
- **Type:** Gameplay state clarity.
- **Observation:** Conquest could change `owner` for a population-free, yard-free system even though `territory_claims` correctly rendered it unclaimed. v0.29.6 prevents conquest of such systems; colonization is required for lasting territorial control.
- **Consider:** Follow-up audit of `owner` versus `territory_claims` in AI and colonization permissions, especially legacy saves.

### T-29f — Explicit camera follow
- **Type:** Camera UX.
- **Observation:** Unit selection and control-group recall automatically enabled camera follow. v0.29.7 requires F to enable follow for the selected ship or fleet; selection changes and manual camera movement disable it.

### T-29g — Persistent center HUD
- **Type:** UI consistency.
- **Observation:** The center details panel was hidden when selection cleared, exposing the starfield and leaving an instruction label floating in its place. Keep the panel visible and blank instead.

### T-29h — Contested territory colors
- **Type:** Territory feedback.
- **Observation:** Contested territory disappeared when claims were neutralized. The renderer now alternates the colors of players with hostile fighter presence while retaining the simulation's contested-state logic; allies do not trigger color cycling.

### T-29i — Prefer local fighter commands
- **Type:** Command reliability.
- **Observation:** Right-click near a POI could still resolve as a sector move even when the cursor was inside the fighter's current sector. Prioritize local-position orders for fighters physically in the clicked sector before resolving cross-sector moves.

### T-29j — Geometric local orders versus stale lane anchors
- **Type:** Movement correctness.
- **Observation:** Local movement validation depended on `at`, which can lag the fighter's physical position. Successful local orders also overwrote `at`, corrupting subsequent lane routing. Validate physical containment and preserve lane anchor, and avoid redirecting local holds solely because `at` differs.

### T-29k — Fighter near-boundary click tolerance
- **Type:** Movement UX.
- **Observation:** Even with physical-sector validation, a click just beyond the mathematical sector edge fell back to nearest-POI routing. The command handler now uses a 64px proximity guard for selected fighters and clamps local destinations to their current sector boundary.
- **Consider:** Render the actual command sector boundary distinctly from territorial ownership, and add a regression test for near-edge clicks.

### T-29l — Shared sector geometry
- **Type:** Movement and territory consistency.
- **Finding:** Ownership shader used smooth unions and smaller neutral exclusions while the simulation used nearest-POI clipped disks. This allowed visibly claimed points to belong to a different command sector. Render the actual clipped disks using every POI center, prioritize the occupied sector at shared boundaries, and remove the 64px workaround. This intentionally trades merged/blobby territory silhouettes for accurate command boundaries.

### T-29m — Bounded command tabs and territory edges
- **Finding:** A scroll viewport containing a vertically shrinking tab container left only tab headers visible. Make the tab container fill the command wing, with a single scroll per page; put ship build cards before yard activity. Move time controls below the upper-right resource bar and use an inward antialiased territory edge to avoid hard clipped neutral bisectors.

### T-30a — RTS command card and selected-unit tiles
- **Implemented:** Five-column square command card with two-step targeting; cached per-unit ship silhouettes and green/orange/red health tiles in selection area. Existing cargo loading is salvage pickup, not arbitrary resource transfer. Move-only suppresses combat diversions during fighter travel; right-click retains contextual attack-move.
- **Verify:** Small viewport/UI scales, multi-unit selection, command cancellation, and networked commands. Consider distinct stop/resume-idle semantics and general cargo transfer later.

- v0.30.1: Preserve opportunistic salvage for held units as covered by ENet smoke tests; explicit Attack Move cannot issue a salvage-click order. Exercise move-only RPC payloads in the existing network smoke scenario.

### T-30b — Zoom-based planet detail
- User superseded selection-only planet visibility. All discovered systems now fade their bodies in at close range (40–100 logical-pixel projected system radius, 0.22s fade), including PDS frames. Orbital rings remain selected-system-only and fade with planets; PDS indicator stays visible at overview scale. Planet hit testing uses the same opacity and supports unselected systems.

### T-31a — Shipyard command card and rally
- Manual build orders pin to the selected completed shipyard. Preserve system maintenance policies and AI scheduling; show active and pinned jobs in center queue with refund cancellation. Rally uses a discovered system and an exact local point, with normal physical travel. Civilian automation resumes after rally; fighters and colony ships wait. Asteroid-field rally destinations are intentionally deferred because civilian routes use system indices.

### T-31b — Territory corners and production portraits
- Wedge-like outlines are caused by hard circle/bisector intersections, not random ownership corruption. Round intersections inward using the same two tightest radial constraints in simulation and shader; straight shared boundaries remain intentional. Production icons now use the actual hull/panel art, empire tint and readable captions; hover provides full cost, build time and unit stats. Check rendering performance on dense maps; shader now evaluates the rounded radius for claimed pixels.

### T-31c — Soft separation and inspector cleanup
- Remove Back to system buttons and the sector Fleet policy UI; keep existing automatic simulation policies for AI and compatibility. Double shipyard art/hit scale without changing ship dimensions or balance. A spatial-hash separation pass steers nearby hulls apart within the ordinary travel budget, avoids exact docking/mining/repair, and softens attraction to a shared local hold anchor. Radius 45 world units and strength 0.65 are provisional; verify dense-fleet motion and cost.

### T-31d — One-shot local movement
- Local point commands previously reused permanent hold state, preventing autonomous pursuit and nearby salvage approach. Transient local move targets now clear on arrival. Retain explicit hold and existing shipyard rally behavior; avoid separation preventing completion of crowded point orders. Verify civilian service resumption and multiplayer arrival.

### T-31e — Symmetric console wings
- The right wing previously expanded with the center, despite the fixed narrow minimap. Give both side panels the same responsive width (24% each, bounded 180–320 logical pixels), with only the middle expanding. Preserve square tactical slots and reflow production portraits; scroll narrow contextual content rather than allowing it to widen the wing. Verify small window and high UI scale manually.

### T-31f — SC2-inspired console contrast and lens strip
- Use a near-black console interior, relocate Logistics from the center toolbar to a persistent vertical icon strip beside the minimap, and move unit health color from the entire tile to the hull outline. Keep matched minimap/command widths and the original health thresholds. Check dark-background legibility and click/hover behavior in live play.

### T-31g — Focus all selections
- F previously followed only ships at the existing zoom and centered the mean of their positions, potentially leaving distant group members offscreen. Frame the bounding box of interpolated ships, fit static sectors/fields and focus precise rendered planet and orbital shipyard positions. Expand the view when a following fleet spreads; manual zoom-out is respected. Manual camera pan and new selections still release focus. Check close-up readability and fit at narrow windows.

### T-32a — Attack-move rally and visible type selection
- Fighter launch rallies previously suppressed fire and overrode combat maneuvering. Preserve the physical destination while ordinary combat and repair temporarily take precedence. Double-click now groups visible matching ships or selectable completed structures, with a building group list, shared owned shipyard commands and F framing. Validate dense and mixed-empire views; numbered yard identities cannot survive slot compaction, so invalidate affected systems' selected slots.

### T-33a — Order queues and painted lines
- Shift is now a queue modifier; patrol moved entirely to the command card. Authoritative per-unit FIFO is revalidated as orders become active; transient targets may expire before execution. Right-drag distributes orders with matching projected hull origins and common perpendicular facing. Verify very short lines and mixed fleets at sector boundaries; auto salvage and civilian work still take precedence after precise arrival.

### T-34a — Station and movement acceptance
- Station core is the sole ownership anchor; colonization establishes the station and first module. Station destruction resets the sector, drops exactly 20% of stored goods and requires recolonization. Review provisional 1,000 HP, art and physical docking paths; verify move-only clicks do not interrupt movement for combat, while explicit attack-move/rallies do. Module housing remains tied to completed shipyards, not the core itself.

### T-35a — Field transit and precise patrol
- Field access was exclusively star-to-deposit; central radial antimatter fields could not travel directly between each other. Persist field pair lanes, reserve the central corridor, and choose nearby unobstructed pairs within existing three-port limits. Patrol anchors retain exact world positions, and may terminate outside sector circles after lane travel. Verify the visual feedback, combat interruption and travel timing, especially over empty space. Multi-ship selection drops individual details; modifier clicks and icon-only aggregate cargo need manual acceptance.

### T-36a — Movement arrival and camera precision
- Formation slots previously kept an idle-only stationary flag indefinitely. Remove it; preserve exact arrival facing for one simulation tick and then allow ordinary wander, work and pursuit. Wheel zoom now uses reversible steps in log space that diminish toward close-up; verify mouse feel at both ends. Single and multi-ship cargo share the same icon-only row; verify narrow console fit.
- Existing neutral-occupation test asserts a held fighter's exact position beside another moving hull; it fails identically on v0.36.3 and v0.36.4. Investigate the intentional soft-separation/hold interaction separately; do not weaken the assertion as part of this arrival fix.

### T-36b — Control groups and selection footer
- Existing keyboard groups only remembered hull IDs, including foreign selections. Extend saved groups to owned selections of ships, structures, planets and systems, pruning lost members and potentially compacted numbered shipyard slots. Keep selection modes homogeneous as before; click/number recall does not pan. Remove redundant completed-shipyard activity cards without losing new-module construction/refunds by moving only those actions into Economy. Cargo footer remains outside the selection scroll area; review overflow at narrow widths.
- Headless UI scale probe surfaced triangulation warnings from existing field and shipyard artwork during camera resizing; inspect distant-zoom polygons separately if reproducible in play.

### T-37a — Mining lasers and normal selection
- Miners now have weak local self-defense without fighter pursuit or territory roles. Their paired weapon has 2 total damage per year and a 3× asteroid multiplier preserving the prior 6 t/yr extraction constant. Chunk remaining ore is its damageable amount; cargo/field budgets prevent lost resources. Mining pauses while firing at hostile entities and resumes the same work. Review balance around contested fields. Right-click-only placement supersedes v0.36.3 both-button modes; left cancels and selects normally.

### T-38a — Miner service and contextual orders
- Civilian sector clicks previously reset mining assignments rather than creating manual travel. Use star lanes followed by exact positioning; retain cargo/assignment and resume automated jobs only when the manual order completes. Focus fire tracks a specific hull or destructible building, including shipyard slot compaction. Manual cargo transfers respect actual free storage; dropped cargo uses ordinary expiry and avoids immediate automatic reacquisition by the dropper. Default-on miner repair searches nearby damaged allies before ordinary work, 5 HP/yr provisional, with no mining during repair; critical HP takes precedence. Validate cross-sector travel and repair balance in live matches. Star rendering previously blended two screen-space radii and clamped to 720 px; replace with proportional world geometry and progressive 40% translucency at max zoom. Station center hit priority keeps deposit commands usable through overlapping docked ships.

- v0.64.0: Direct tactical point and manual service flight no longer require intermediate sector waypoints; destination discovery/bounds remain. Autonomous economic and sector-target strategic routes retain graph semantics pending separate migration. Check arrival anchors, transit combat, off-region stops and route previews; runtime and peer verification pending.

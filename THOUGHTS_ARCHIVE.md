# Warbound — thoughts archive

### T-33b — Station ownership anchor (resolved 2026-11-17)
- **Original observation:** Conquest could leave claimed systems with no shipyards. Proposed an orbital core, three attached production modules, and 20% stored-resource salvage.
- **Resolution:** Implemented in v0.34.0. Destroying the core neutralizes the sector and requires a new colony ship to establish a station; fighter occupation no longer grants ownership. Physical station docking and independent module loss preserve the distinction between claim and production. Visual acceptance remains in TODO.md.

### T-007 — Small allocations can stall attacks (superseded 2026-11-17)
- **Original observation:** Hostile-system allocations below three hulls rallied instead of deploying; splitting a small fleet could stall every attack.
- **Disposition:** v0.18.0 design replaces policy allocations with direct commands that depart immediately regardless of size. No regional allocation or mandatory human rally remains. Retest direct movement instead.

Completed or otherwise resolved entries moved from THOUGHTS.md. Preserve the original identifier and observation, then record the resolution date, outcome (implemented, rejected, superseded, etc.), and version/PR or relevant evidence. Do not treat rejected or superseded ideas as implemented.



### T-010 — Host visual target between snapshots
- **Type:** Verified regression (PR #49 eight-peer host check).
- **Observation:** Authority advances simulation at 10 Hz while snapshot notifications are 5 Hz. Render target could lag a current authoritative position.
- **Consider:** v0.10.3 synchronizes render destinations when poses are sampled, preserving interpolation; verify mandatory ENet checks before archiving.

- **Resolution (2026-11-15):** Implemented in v0.10.3 / PR #49; authoritative render target sampled with poses. Eight-peer checks passed again in v0.11.5 / PR #51.

### Opening pacing — v0.18.0
- **Observation:** The initial allied-AI economy benchmark took 184–220 years for the first colony; at year 360, each of three seeds had three owned worlds and 3–6 fighters. Queuing a colony too early could drain its origin's workforce. Food and industrial stocks bottlenecked further hulls.
- **Resolution (2026-11-17, v0.19.0):** The first pacing pass reduced colony crew, protected minimum staffing, doubled baseline industry, lowered hull food inputs, expanded freight capacity and prioritized AI logistics and reinforcement after settlement. Regression benchmark: first colony in 135–152 years, six worlds and 12–15 fighters at year 360. Broader match balance remains active in THOUGHTS.md.

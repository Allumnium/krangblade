# Warbound — thoughts archive

### T-007 — Small allocations can stall attacks (superseded 2026-11-17)
- **Original observation:** Hostile-system allocations below three hulls rallied instead of deploying; splitting a small fleet could stall every attack.
- **Disposition:** v0.18.0 design replaces policy allocations with direct commands that depart immediately regardless of size. No regional allocation or mandatory human rally remains. Retest direct movement instead.

Completed or otherwise resolved entries moved from THOUGHTS.md. Preserve the original identifier and observation, then record the resolution date, outcome (implemented, rejected, superseded, etc.), and version/PR or relevant evidence. Do not treat rejected or superseded ideas as implemented.



### T-010 — Host visual target between snapshots
- **Type:** Verified regression (PR #49 eight-peer host check).
- **Observation:** Authority advances simulation at 10 Hz while snapshot notifications are 5 Hz. Render target could lag a current authoritative position.
- **Consider:** v0.10.3 synchronizes render destinations when poses are sampled, preserving interpolation; verify mandatory ENet checks before archiving.

- **Resolution (2026-11-15):** Implemented in v0.10.3 / PR #49; authoritative render target sampled with poses. Eight-peer checks passed again in v0.11.5 / PR #51.

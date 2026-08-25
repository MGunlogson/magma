# Magma cell patterns

Four cell shapes are available. They differ in how easily a tube seals, how much open tube you
get per cell, and how fast the lattice prints.

**Use Rectilinear unless you have a reason not to.** Best combination of print speed and
printability, and the pattern all the guidance in [TUNING.md](TUNING.md) was measured on.

## How they compare

The nozzle has to cover a cell's *circumscribed* circle to seal it, but only the *inscribed*
circle is usable tube. The ratio between them is the first thing that separates the patterns:

| Pattern | Bore / sealed opening | Notes |
|---|---|---|
| **Rectilinear** | 71% | Default. Straight-line toolpath, each wall a single bead |
| Honeycomb | 87% | Roundest opening, so the shallowest seal for a given tube |
| Tri-hex | 87% | Hex hubs with triangular vents between them |
| Triangle | **50%** | Worst of the four — the opening is twice the usable bore, so the nozzle must descend much further to cover it. The slicer warns if you pick it |

A higher percentage means more usable tube per millimetre of descent, which is why honeycomb
and tri-hex look better on paper.

## What testing found

All four print. Rectilinear won on speed and printability, not by disqualifying the others.

Honeycomb sealed poorly on the one plate that tested it. The likely explanation is its
toolpath: each vertical wall is drawn as two beads side by side, since both columns sharing an
edge trace it, so the join between them runs the full height of the tube. The seal model has no
pattern term, so it cannot see that leak path.

That is one result and it predates the current seal model. Treat honeycomb and tri-hex as
**untested against the current geometry** rather than ruled out. If you retest, watch whether
plastic escapes at the wall joins or at the nozzle seal. Joins would confirm the doubled-bead
explanation and put the fix in the toolpath rather than in any setting.

## Implementation notes

Per-pattern design documents, for anyone working on the code:

- [DESIGN-RECTILINEAR.md](DESIGN-RECTILINEAR.md) — square grid, `SquareGeometry`
- [DESIGN-HONEYCOMB.md](DESIGN-HONEYCOMB.md) — pointy-top hexagons, squish compensation
- [DESIGN-TRIHEX.md](DESIGN-TRIHEX.md) — trihexagonal tiling, the vent manifold
- [DESIGN-TUBE-SOLVER.md](DESIGN-TUBE-SOLVER.md) — how cells are paired into U-tubes

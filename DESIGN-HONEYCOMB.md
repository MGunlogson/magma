# Magma Honeycomb Pattern — Design Note (locked)

Fourth Magma infill pattern, after Triangle, Rectilinear, and Tri-hex. This note is
the implementation reference; the design below is settled.

**Terminology:** honeycomb cells are regular **hexagons** that pair into the same
**U-tube** as the triangle and rectilinear patterns — two adjacent cells joined by a
window gap at their shared wall, injected down one and vented up the other. It is the
degenerate 1-leg manifold, exactly like triangle/square; only the cell shape and the
toolpath differ. The hexagon math is identical to the tri-hex **hub** (the hub IS a
hexagon), so the geometry is reused; what differs is hex↔hex pairing instead of
hub↔vent, and the continuous honeycomb sweep toolpath.

## 1. Lattice — regular pointy-top hexagons

- Every cell is a regular **pointy-top hexagon** — a vertical left and right edge plus
  four slanted edges — bordering **6** neighbours. Implemented in `HexLattice`
  (`MagmaHexCell.hpp`).
- Cell size is driven by the tube interior width: the centre-to-centre spacing
  `s = interior_width + line_width`, and the **open** hex edge `e = interior_width/√3`
  (`= (s − lw)·INV_SQRT3`; a regular hexagon's flat-to-flat across the verticals is `e√3`,
  so the open tube's flat-to-flat is exactly `interior_width`). Note `e` is derived from
  the *interior*, not from `s` — deriving it from `s` leaves the open hexagon one bead
  too wide.
- `CellId` carries axial coords `(q, r)` packed as `(a=q, b=r, 0, 0)`; `c` and `kind`
  are unused. Hexes have no parity (`is_up()` is always false).
- Ideal pointy-top centre: `x = s·(q + r/2)`, `y = s·(√3/2)·r` — a row (`r` fixed) steps
  by `s` in X; each row up is offset `s/2` in X and raised `s·√3/2` in Y. (The actual
  transform uses the squish-compensated `m_sx`/`m_row`; see §3.)
- `neighbors()` returns the 6 edge-sharing axial neighbours `(q±1,r)`, `(q,r±1)`,
  `(q+1,r−1)`, `(q−1,r+1)`; `max_neighbors() = 6`.

## 2. Cell geometry — `HexagonGeometry` (`MagmaGeometry` impl)

Walls are single shared beads centred on the edges, so the open interior is the hexagon
inset by `line_width/2` per side → open apothem `a' = (s − lw)/2 = interior/2`.

- `edge_length = e = interior/√3` (the OPEN edge; `HexGeometry::edge_length(spacing)`
  is called with the open flat-to-flat, not with `s`).
- `inset_open_area = 2√3·a'²` (regular-hex area from apothem `a'`).
- `opening_diameter = 2·(s − lw)/√3` — the circumscribed circle of the open hexagon,
  which the nozzle flat must cover when sealing.
- **Seal ratio** (opening / interior) = **2/√3 ≈ 1.155** — the *lowest* of all four
  patterns (vs the square's √2 ≈ 1.41 and the triangle's 2.0), so a hexagon seals the
  most easily: `interior_for_opening = opening·√3/2` turns the largest sealable opening
  into the largest interior that opening allows.
- `inscribed_radius = interior/2`, `neighbor_centroid_distance = s` (hex↔hex;
  flat-to-flat = centre-to-centre).
- `auto_window_height = open_area / open_edge` with `open_edge = e − lw` — the window
  flow cross-section equals the paired hex's open tube cross-section (written area/edge
  to parallel triangle/square).
- `max_neighbors = 6`; a pair is 2 cells. Overlap: see §6.

## 3. Squish compensation — pre-expanded lattice (the honeycomb-specific bit)

The toolpath (§4) draws the **VERTICAL** walls **doubled** (two beads, total width
`2·lw`, centred on the edge → intrudes `lw` into the open) and the **slants single**
(one bead → intrudes `lw/2`). Left uncompensated the open hexagon comes out skewed
(verticals ≠ slants). To make the OPEN tube the original regular hexagon (edge `e`),
`HexLattice` pre-expands the tiling on every affected axis (`lw` = line width):

- horizontal flat-to-flat (X): `m_sx = interior_width + 2·lw` (`= s + lw`) — the doubled
  wall, `lw` each side, added outside the open flat-to-flat.
- top/bottom vertex offset (Y): `m_vtop = e + lw/√3` — the slant inset lifts the apex.
- row pitch (Y): `m_row = 1.5·e + lw/√3` (`= m_vtop + e/2`, preserving the tiling).
- the vertical-edge half-length stays `e/2` (corners at `±e/2` about the centre) → the
  vertical edge length stays `e`.

With all three, the open hexagon's vertical edge and slant edge come out **exactly equal
(= `e`)**: a true regular hexagon. World transform:
`to_world(q,r) = (m_sx·(q + r/2) + ox, m_row·r + oy)`; `cell_corners` uses
`hx = m_sx/2`, `hy = e/2`, with the top/bottom vertices at `±m_vtop`.

## 4. Toolpath — `FillMagmaHoneycomb::_fill_surface_single`

Reuses OrcaSlicer's native **continuous honeycomb sweep** (Orca-style), phased to the
lattice so windows/injection land on the drawn walls. Instead of analytic line families
(triangle/square) it emits **one continuous zigzag per lane PAIR**:

- vertical lanes fall on `x = ox + k·(m_sx/2)`; a lane's two doubled beads sit at
  `±x_off` of the lane (`x_off = min(lw/2, s/5)`).
- the pair `(k, k+1)` oscillates between its two lanes with period `2·row` in Y
  (`row = 1.5·e + lw/√3`), phased at `oy + row·(k−1)`: a vertical (length `e`) on lane
  `k`, a slant up to lane `k+1`'s vertical (whose bottom sits at the hexagon vertex),
  that vertical, a slant back.
- because lane `k` is the right lane of pair `(k−1,k)` and the left lane of pair
  `(k,k+1)`, **every vertical edge is swept by both neighbouring pairs → doubled**; the
  slants are each traced once → single.

**Why doubled (and not a bug):** the honeycomb wall graph has **degree-3** vertices
(three edges meet at each hexagon corner at 120°). An Eulerian path — trace every edge
once with no travel — requires all-but-two vertices to have even degree; degree-3 is odd
everywhere, so no single-pass, no-travel tracing of the honeycomb exists. The native
sweep buys a continuous, low-travel, no-mid-path-retraction path — which is why honeycomb
prints fast — at the price of re-tracing the shared vertical edges. The extra
vertical material is not an error: it is measured into the injection void (§5), and the
open tube is still a regular hexagon by §3.

Anchoring is disabled (zone shells provide the bonding surface); `chain_or_connect_infill`
routes the swept lanes (`no_sort` preserves the merged ordering).

## 5. Window placement & injection volume

**Windows** — for each open U-tube pair (the solver decides which pairs are open on a
given layer), find the two corners shared by `cell_a` and `cell_b`'s corner rings and
build a rectangle oriented along that shared edge (direction `d`, normal `n`):
half-length `hl = len/2` so it spans the **full flat edge**, half-width `hw = x_off + lw`
so it cuts through **both** doubled vertical beads. The rectangle is subtracted from the
swept polylines with `diff_pl`. Unlike triangle/square (which cut per-line-family
intervals), honeycomb subtracts geometric rectangles, because the zigzag is one
continuous path not separable into families. Same pairing / stagger / `window_open_at`
system as the other patterns; windows span the full flat edge of the shared hex side.

**Injection volume** — measured from the real toolpath
(`MagmaTubeMap::measure_volumes`, run after `PrintObject::infill()` when the deposited
paths exist): per layer, `(cell_a ∪ cell_b) ∩ zone` minus the deposited wall footprint
(`polygons_covered_by_width`), × the actual layer height, summed over the run. The
doubled vertical walls are captured **exactly** by that footprint — no per-shape area
estimate, and honeycomb's vertex-overlap subtraction is zero (no crossings; §6).

## 6. Overlap

- Honeycomb's hexagon corners are **degree-3** (three wall ENDS meet at 120°, *not*
  crossings), so there is **no line-crossing double-deposition** like the triangle's
  60° or the square's 90° X-crossings. `vertex_overlap_excess_area` returns **0**, so
  honeycomb's vertex-overlap subtraction from the injection volume is zero.
- That zero is just the general model evaluated for honeycomb. Across all patterns the
  injection volume subtracts the vertex overlap, because crossing lines genuinely deposit
  plastic twice and `polygons_covered_by_width` merges them into a single union — the second
  line's bulge into the void is not captured there and has to be subtracted. Honeycomb has
  no crossings, so it subtracts nothing.
- The doubled VERTICAL walls are a **separate** effect (the no-travel zigzag, §4),
  already captured by the measured wall footprint — not a vertex overlap, and not
  something the volume needs to correct for a second time.

## 7. Solver / injection / preview — UNCHANGED

- The tube solver (greedy warm start + optional CP-SAT) is **pattern-agnostic**: a hex
  with 6 candidate neighbours instead of the triangle's 3 is just more edges; the
  matching, runs, segments, stagger, and CP-SAT model are identical.
- Per-layer presence scan, injection G-code, seal / plunge / crater-iron, the
  spread-heat injection ordering, and the preview tube viz are all shared and unchanged.
- Spiral interlock applies (the hex lattice translates per layer like the others).

## 8. New vs reused

- **NEW:** the hexagonal lattice (`HexLattice`) with its squish-compensated
  `m_sx`/`m_vtop`/`m_row`; the continuous honeycomb sweep toolpath (`FillMagmaHoneycomb`)
  with doubled verticals; the rectangle-subtraction window cuts.
- **REUSED:** the hexagon geometry (identical to the tri-hex hub) via `HexagonGeometry`;
  the measured-volume path (`measure_volumes`); the tube solver (greedy + CP-SAT),
  runs/segments/stagger/height bounds, presence scan, U-tube pairing, injection
  sequence, crater iron, preview viz, and dual-zone outer fill (any pattern may fill the
  outer zone).

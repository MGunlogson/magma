# Magma Rectilinear Pattern — Design Note (locked)

Second Magma infill pattern, after Triangle and before Tri-hex. This note is the
implementation reference; the design below is settled.

**Terminology:** rectilinear (a.k.a. "square") cells pair into the same **U-tube** as
the triangle pattern — two adjacent cells joined by a window gap at their shared wall,
injected down one and vented up the other. It is the degenerate 1-leg manifold, exactly
like triangle; only the cell shape and line families differ.

## 1. Lattice — square grid

- Two perpendicular single-wall line families spaced `cell_spacing` apart, so each cell
  is a square of side = `cell_spacing`. No skew, no parity (unlike the triangle's
  up/down cells).
- `CellId` uses `(a, b)` = integer (column, row); `c` and `kind` are unused (0). Each
  cell is the unit square `[a, a+1] × [b, b+1]` in lattice space.
- World mapping is a plain axis-aligned scale + spiral offset:
  `to_world(lx, ly) = (lx·cs + off_x, ly·cs + off_y)`.
- `RectilinearLattice::neighbors()` returns the **4** edge-sharing neighbors
  (L/R/U/D); `is_up()` is always false; `max_neighbors() = 4`.

## 2. Cell geometry — `SquareGeometry` (`MagmaGeometry` impl)

Walls are single shared beads centred on the grid lines, so the open interior is inset
by `line_width/2` on each of the four sides → **inset (open) square side = `spacing − lw`**.

- `edge_length = spacing` (the line spacing IS the square's side).
- `inset_open_area = (spacing − lw)²`.
- `opening_diameter = (spacing − lw)·√2` — the circumscribed circle of the inset square,
  which the nozzle flat must cover during Z-slam (all four corners).
- **Seal ratio** (opening / interior) = **√2 ≈ 1.41**, vs the triangle's 2.0 — the square
  seals more easily, so a given nozzle flat covers a larger interior
  (`auto_interior_width_from_od = od / √2`).
- `neighbor_centroid_distance = spacing` (orthogonal grid; simpler than the triangle's
  `side/√3`).
- `vertex_overlap_excess_area = lw²` — only **2** line families crossing at 90°, ~1
  crossing per cell (vs the triangle's 3 families at 60° → `3√3·lw²/4`). Less material is
  double-deposited, so the overlap line-width correction is gentler:
  `line_overlap_excess_fraction = lw / (2·spacing)`.
- `window_volume = (spacing − lw)·lw·window_height` — the shared-wall gap.
- `auto_window_height = (spacing − lw) = interior_width` — written as `area/edge` to
  parallel the triangle, so the window flow cross-section equals the tube's open
  cross-section.
- `max_neighbors = 4`, `cells_per_pair = 2`.

## 3. Window placement — `square_window_cuts` (pattern-owned)

For each open U-tube pair (the solver decides which pairs are open on a given layer):

- cells differ in **column** (`a`) → the shared wall is **vertical** → cut the gap into
  `vert[col]` as a Y-interval;
- cells differ in **row** (`b`) → the shared wall is **horizontal** → cut into
  `horiz[row]` as an X-interval.

Intervals are merged per line index. Simpler than the triangle, which must classify the
shared edge into three families (horizontal / 60° / 120°).

## 4. Toolpath — `FillMagmaRectilinear::_fill_surface_single`

- Two line families over the bbox-derived ranges (no skew):
  - **horizontal** (one per row `b`): `y = b·cs + off_y`, spanning X;
  - **vertical** (one per column `a`): `x = a·cs + off_x`, spanning Y.
- Window gaps interrupt the relevant family via `subtract_gaps` (Y-intervals split
  vertical lines, X-intervals split horizontal lines).
- Each family is clipped **per line** (so a line's fragments stay adjacent for the sweep),
  then `chain_or_connect_infill` routes within the family. Anchoring is disabled (zone
  shells provide the bonding surface).

## 5. Solver / injection / preview — UNCHANGED

- The tube solver (greedy warm start + optional CP-SAT) is **pattern-agnostic**: a square
  cell with 4 candidate neighbours instead of the triangle's 3 is just more edges; the
  matching, runs, segments, stagger, and CP-SAT model are identical.
- Per-layer presence scan, injection G-code, Z-slam/plunge/crater-iron, the spread-heat
  injection ordering, and the preview tube viz are all shared and unchanged.
- Spiral interlock applies (the square lattice translates per layer like the triangle).

## 6. New vs reused

- **NEW:** the square lattice (`RectilinearLattice`) + `SquareGeometry`;
  `square_window_cuts`; the 2-family axis-aligned toolpath.
- **REUSED unchanged:** the tube solver (greedy + CP-SAT), runs/segments/stagger/height
  bounds, presence scan, U-tube pairing, injection sequence, preview viz, dual-zone outer
  fill (any pattern may fill the outer zone).

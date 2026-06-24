# Magma Tri-hex Pattern — Design Note (locked)

Third Magma infill pattern, after Triangle and Rectilinear. This note is the
implementation reference; the design below is settled.

**Terminology:** a tri-hex injection unit is a **manifold** — one hub + N
equal-length vent legs. The U-tube (triangle/square) is the degenerate 1-leg
manifold.

## 1. Lattice — trihexagonal tiling

- Hexagon cells (**hubs**) + up/down triangle cells (**vents**) filling the gaps.
- Bipartite: a hex borders only triangles (6), a triangle borders only hexes (3);
  ratio 2 triangles : 1 hex.
- Edges remain 3 line families at 60°, so the toolpath stays triangle-like
  (single-wall, continuous sweeps) — `FillMagmaTriHex` is close to the triangle
  toolpath with the hex/triangle window logic.
- `CellId.kind` distinguishes HEX / TRI_UP / TRI_DOWN (the field already exists).
- `MagmaLattice::neighbors()` returns bipartite neighbors (vents for a hub, hubs
  for a vent), so the solver gets hub↔vent edges for free.

## 2. Injection model — the manifold

- A **hub-tube** = a hub cell over a layer range `[start, cap]`, window(s) at the
  bottom (`start`), injected at the `cap`.
- **Vent legs**: each leg spans the SAME `[start, cap]` as its hub-tube — legs are
  equal length, because windows are pinned to the tube bottom (no adjustable/partial
  legs). Plastic enters each leg at the bottom window, fills up to the cap, air
  escapes at the cap (the print surface at injection time).
- One injection fills the hub + all its legs together.

## 3. Solver — UNCHANGED

- Feed the existing tube solver the bipartite hub↔vent lattice.
- Standard cell-exclusive matching (`NoOverlap` per cell) → each hub-tube gets
  exactly ONE vent (the **primary leg**), each vent serves ≤1 hub: a bipartite
  U-tube matching.
- This schedules hub-tube ranges with stagger / height / stacking AND guarantees
  feasibility (every scheduled hub-tube has ≥1 leg → can inject / vent air).
- **Zero solver code change.** A hex having 6 candidate vents instead of 3 is just
  more edges; the matching, runs, segments, stagger, and CP-SAT model are identical.

## 4. Extra-vent sweep — NEW, per vent, runs after the solver

Goal: maximize filled vent volume by adding extra legs to the already-scheduled
hub-tubes. Runs after greedy and after CP-SAT (same code either way).

For each vent V:
1. **Unavailable mask** = layers where V is geometry-absent (part blocks the cell)
   ∪ layers already claimed by the solver's primary matching. Both are treated
   identically.
2. **Candidates** = the bordering hub-tubes' ranges `[start, cap]`.
3. **Delete** any candidate that crosses an unavailable layer — a block/claim inside
   the range would trap air (no escape) → infeasible.
4. The surviving available layers form **present-runs**. Per run:
   - candidates = hub-tubes fully contained in the run,
   - pick the non-overlapping subset covering the most layers = **weighted interval
     scheduling** (exact; sort-by-cap + DP, or brute-force the handful of candidates),
   - tiebreak toward the **least-loaded hub** (evenness; minor — legs are low-volume),
   - assign V (those layers) as legs of the chosen hub-tubes.
- Per vent independent (hubs are uncapped). A vent may be a leg of multiple stacked
  hub-tubes at different (non-overlapping) heights — each fed from its own tube's
  bottom window, which lines up with the plug below by construction.

The sweep is purely additive: feasibility was already secured by the solver's
matching, so it can never strand a hub.

## 5. Finalize

- Each hub-tube now knows its hub + all legs (primary + extras) → an `InjectionUnit`.
- **Windows:** `trihex_window_cuts` (pattern-owned, like `triangle_window_cuts` /
  `square_window_cuts`) emits one gap per (hub, leg) at the tube bottom.
- **Volume:** sum over {hub + each leg} of (per-layer actual clipped area × height)
  + each window's volume. `compute_volumes` already sums per-cell per-layer, so this
  is just a sum over the manifold's members — **no per-kind geometry needed**.

## 6. Data model

- `UTubePair` → `InjectionUnit { CellId hub; std::vector<CellId> vents; start/end
  layer; volume_mm3; injection_center; window_center_layer; … }` with `cell_a()`/
  `cell_b()` accessors so the 2-cell pair is the 1-leg special case.
- Triangle/square produce 1-leg units; their call sites change `cell_a`→`hub`,
  `cell_b`→`vents[0]`. `compute_volumes` / injection / viz iterate `vents`.

## 7. Geometry / misc

- Per-cell clipped area carries each vent's volume → **no per-kind geometry methods**.
- Hex hub geometry (`edge_length`, `inset_open_area`, `opening_diameter`,
  `inscribed_radius`, `neighbor_centroid_distance` (hex↔triangle), `interlock_radius`,
  `auto_window_height`, `auto_interior_width_from_od`) drops into a `HexGeometry`
  (`MagmaGeometry` impl) used for the hub.
- `max_neighbors()` returns the max (6); `neighbors()` already returns variable arity.
- Crater-iron start radius is already principled (derived from the per-tube slam);
  feed it the per-kind neighbour opening + hex↔triangle `neighbor_centroid_distance`
  for the neighbour-clearance cap.
- Injection-edge preference (interior/exterior) is moot for tri-hex (hub is the hex).
- Dropdown icon: `param_magmatrihex.svg` (placeholder copy of the triangle art).

## 8. New vs reused

- **NEW:** trihexagonal lattice + hex geometry; the extra-vent sweep;
  `trihex_window_cuts`; the `InjectionUnit` generalization.
- **REUSED unchanged:** the tube solver (greedy + CP-SAT), runs/segments/stagger/
  height bounds, presence scan, crater iron, injection sequence, preview viz.

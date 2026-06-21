# Magma v0.1 — Vertical Reinforcement Infill for FDM 3D Printing

**OrcaSlicer Fork | May 2026**

Magma is a new infill type that creates sealed vertical channels within FDM-printed parts that are filled
with injected plastic during printing, forming continuous "knitted" Z
reinforcement to reduce Z layer weakness in FDM printed part. 

This document is the v0.1 release notes and reference for the new
configuration settings. For a project overview, screenshots, and the experimental
status of the physical printing side, see the [project README](README.md).

---

## What's New

### Core: Magma Infill System

- **Triangle cell infill pattern** (`ipMagmaTriangle`) — equilateral triangle
  lattice using (a,b,c) integer coordinates. Three families of parallel lines
  (0/60/120 degrees) form sealed triangular channels. This is a modification of the traditional triangle infill pattern.

- **U-tube pair assignment** — adjacent cells are paired and connected by window
  gaps at their shared wall. Plastic is injected down one cell and rises up
  through the partner, forming interlocking U-shaped reinforcement columns.

- **Two-stage tube solver** —
  - *Stage 1 (Greedy):* Most-constrained-first heuristic assigns tubes in
    100-500ms. Achieves ~77-81% coverage alone.
  - *Stage 2 (CP-SAT, optional):* Google OR-Tools constraint programming solver
    refines the greedy solution, improving coverage by 3-7% and adding weak plane
    avoidance. 

- **Injection G-code generation** — per-layer injection stage with configurable
  temperature, volumetric flow rate, Z-slam nozzle sealing, dwell time, and
  retraction. Injection visit order is selectable per layer (`magma_injection_ordering`):
  Minimize travel (shortest path) or Spread heat (see below).

- **Spiral interlock** — optional per-layer circular offset shifts the entire
  lattice so tubes follow helical paths, adding pullout resistance. Bounded by
  three physical constraints (line overlap, tube area overlap, helix angle).

- **Auto tube sizing** — derives tube interior width from the measured nozzle tip
  flat (`magma_nozzle_outer_diameter`, labelled "Nozzle tip flat") using
  circumscribed circle geometry, ensuring the nozzle flat covers all three triangle
  vertices during Z-slam injection.

- **Constriction detection** — when a cell's cross-sectional area drops below 30%
  between adjacent layers (geometry pinch points), the cell is split into separate
  spans so tubes cannot bridge across near-discontinuities.

- **Auto window height** — when set to 0 (default), the window gap height is the
  geometric value (window cross-section = tube interior) plus one layer height,
  so the opening reliably spans a full printed layer.

- **Per-layer volume computation** — injection volumes account for variable layer
  heights, window gap volume, and triangle vertex overlap excess subtraction.

### Core: Dual-Zone Infill Architecture

- **Dual infill zones** — splits infill into an outer Magma zone (for injection
  reinforcement) and an inner zone (any standard infill pattern). The outer zone
  width, inner zone minimum width, and boundary shell are all configurable.

- **Zone boundary generation** — repurposes OrcaSlicer's SLA hollowing algorithm
  (OpenVDB level sets) with constrained mean curvature flow smoothing and
  morphological thin-section filtering.

- **Zone boundary shell** — configurable inner perimeter walls between zones with
  solid floor/ceiling layers for sealing.

- **Per-zone speeds** — separate speed settings for outer zone infill, zone
  shell, zone floor, and zone ceiling.

- **Per-zone filament** — outer zone can use a different filament than the inner
  zone (multi-material support).

### Solver: Greedy Warm Start

- **Most-constrained-first scoring** — cells are assigned in priority order by
  fewest viable neighbors first (ties broken by longest achievable tube), so
  boundary cells (1 neighbor) are processed before interior cells (3 neighbors),
  preventing stranding. A separate sum-of-achievable-heights difficulty map
  guides the CP-SAT stage.

- **Periodic re-scoring** — heap is rebuilt every `max(200, num_edges/3)`
  assignments with fresh consumed state, correcting stale priority ordering.

- **Longest-tube preference** — greedily expands the longest valid tube between
  cell and its most-constrained neighbor, maximizing coverage per assignment.

- **Stagger handled in refinement** — the greedy pass does not guarantee Z
  staggering of tube boundaries; weak-plane avoidance is the CP-SAT stage's
  responsibility (see below).

### Solver: CP-SAT Refinement (Optional)

- **Integer micron arithmetic** — all Z coordinates use int64_t microns,
  eliminating floating-point comparison issues in the constraint solver.

- **Discrete domains** — start/end/size variables use `Domain::FromValues()`
  with actual layer boundary positions, restricting the search to feasible layer
  boundaries and tightening the LP relaxation.

- **Weak plane avoidance** — per-cell cumulative stagger penalty using
  `AddCumulative` with Ring-0 (demand=2) and Ring-1 (demand=1) neighborhoods.
  Two-tier penalty (tight + wide) with configurable dodge distance.

- **Spatial block partitioning** — XY: R=16 cells/block, single pass with
  ~12.5% block overlap. Z: 50% overlapping windows. TBB parallelism across
  independent blocks, CP-SAT workers set to the available core count.

- **Warm start from greedy** — committed segments become CP-SAT hints. Segments
  extending outside block boundaries become frozen intervals.

- **Progress reporting** — "Magma: refining tubes — X/Y" status bar updates.
  Cancellation supported between solver passes.

### Injection

- **Z-slam sealing** — nozzle lowers into the print surface during injection to
  seal the tube opening. Configurable depth (default 0.05mm, warns above 3.5mm).

- **Auto Z-slam depth** (`magma_injection_z_slam_auto`) — derives the seal depth
  from nozzle geometry instead of by hand: `z_slam = max(0.1, (opening - flat) /
  (2 * tan(angle)))`, using the tube opening, the nozzle tip flat, and the nozzle
  cone half-angle (`magma_nozzle_cone_half_angle`, default 30°). Tracks tube size
  and nozzle automatically; the manual depth field is hidden while it is on.

- **Spread-heat injection ordering** (`magma_injection_ordering` = Spread heat) —
  a global, per-print-layer ordering (across all objects and instances) that
  separates spatially-near injections in time so combined heat does not re-melt
  neighbouring cells. Solved with CP-SAT, warm-started from the travel-optimal
  path (so it is never much longer), with a short per-layer time budget; the
  result is cached in a dedicated slicing step and falls back to travel order if
  the solve does not finish.

- **Safe park positioning** — 5-tier priority system finds safe XY positions
  during temperature changes: empty > support > sparse infill > solid infill >
  z-hop only.

- **Tube-end ironing** — optional ironing pass over injection points to smooth
  the surface and seal tube openings.

- **Configurable injection parameters** — temperature, volumetric speed, dwell
  time, Z-hop between injections, retraction, fan speed override.

- **Injection speed safety** — warns when configured volumetric speed exceeds
  the filament's max volumetric speed, and caps it automatically.

- **Z-slam depth guard** — warns and resets z-slam depth above 3.5mm with
  explanation of nozzle geometry dependence.

- **Multi-material injection** — dedicated injection filament
  (`magma_injection_filament`) uses a different extruder for tube filling,
  wired through OrcaSlicer's tool ordering infrastructure.

### GCode Preview

- **5 new extrusion roles** — ZoneOuterInfill, ZoneShell, ZoneFloor,
  ZoneCeiling, MagmaInjection with distinct colors (Volcanic Strata palette).

- **Tube fill visualization** — 3D tube centerlines simplified with
  Ramer-Douglas-Peucker, encoded as `MAGMA_TUBE` G-code comments. Preview
  slider shows progressive tube filling.

- **Near-vertical segment rendering** — parallel-transported frame computation
  in vertex shader prevents degenerate geometry at vertical injection paths.

- **Zone boundary shell overlay** — press 'J' in preview to toggle zone boundary
  visualization (Initial / Smoothed stages). Transparent red/blue rendering.

- **Tube fill preview in slicing view** — synthetic vertices from the tube map
  show tube fill coverage immediately after slicing, before G-code generation.

- **Nozzle marker correction** — during tube fill visualization playback, the
  nozzle marker stays at the actual injection point instead of following the
  synthetic underground tube path.

### Bug Fixes & Improvements

- **Width-based thin infill filter** (`filter_narrow_sparse_infill`) —
  morphological opening splits narrow sparse infill sections into solid fill
  while preserving thick regions. Distinct from the existing area-based filter.
  Auto threshold = 2x nozzle diameter.

- **Triangle vertex overlap correction** — at 60-degree line crossings, material
  is deposited twice. Both infill flow and injection volume are corrected:
  line width is reduced (floored at `magma_overlap_min_width`, default 90% of
  nozzle diameter), excess area subtracted from tube volume calculations.

- **Bridge detection zone-awareness** — zone outer infill is treated as solid
  support for bridges; unfilled cells (no tube coverage) are subtracted so
  bridges correctly span uninjected areas; zone ceiling gets bridge detection.

- **GCodeProcessor stationary extrusion fix** — Magma injection (G1 E-only, no
  XY movement) no longer causes division-by-zero in toolpath cross-section
  calculation.

- **UI tidying** — irrelevant infill settings (density, direction, rotation,
  anchoring) are hidden when Magma Triangle pattern is selected.

- **Zone role acceleration/jerk/flow** — zone shell inherits inner wall settings;
  zone outer infill inherits sparse infill settings; zone floor/ceiling inherit
  internal solid infill settings.

### General OrcaSlicer Improvements (non-Magma)

- **Ooze prevention safe parking** — new `ooze_prevention_park` option moves the
  nozzle to a safe position during multi-extruder temperature changes, reusing
  the 5-tier parking system. Prevents ooze blobs on printed surfaces.

- **Config API cleanup** — new type-safe `opt_enum<T>()` / `opt_enum_or<T>()`
  template methods replace verbose enum config access, preventing null
  dereference crashes.

- **Fix static initialization order fiasco** in StatusPanel — removed unused
  static font variables that copied Label fonts before initialization.

- **Fix member initialization order** in Plater — moved members before `priv`
  to match constructor access order.

- **Fix uninitialized ThumbnailsParams::sizes** — added default empty initializer.

- **Fix null window crash in bitmap scaling** — `create_scaled_bitmap()` falls
  back to top window when caller provides null.

### Notes

- Magma is not compatible with Spiral Vase mode printing

---

## New Configuration Settings

Magma and the dual-zone system add 48 settings: 43 for Magma and dual-infill, plus 5 general improvements that ship on the branch but apply to any print. Every setting, its tab, and its default are in the **[settings reference](settings.md)**, and the same text appears as tooltips in the app.

---

## Architecture

### File Structure

```
src/libslic3r/
├── Magma/
│   ├── MagmaTriangleCell.hpp/.cpp    — (a,b,c) lattice coordinates, geometry
│   ├── MagmaSpiralOffset.hpp/.cpp    — Per-layer helical offset computation
│   ├── MagmaTubeMap.hpp/.cpp         — Cell presence, tube pairs, volumes, windows
│   ├── MagmaGreedyWarmStart.hpp/.cpp — Most-constrained-first tube assignment
│   ├── MagmaTubeSolver.hpp/.cpp      — CP-SAT interval scheduling optimizer
│   └── MagmaInjection.hpp/.cpp       — Injection G-code, visualization, parking
├── Fill/
│   └── FillMagma.hpp/.cpp            — Triangle grid infill with window gaps
├── ZoneBoundary/
│   └── ZoneInterior.hpp/.cpp         — OpenVDB smoothing, thin section filtering
└── GCode/
    └── SafeParkPosition.hpp/.cpp     — 5-tier safe parking for temp changes
```

### Integration Points (modified existing files)

| File | Changes |
|------|---------|
| PrintConfig.hpp/.cpp | 48 new settings, 4 new enums |
| PrintObject.cpp | Magma build pipeline, solver invocation, progress/cancel |
| Print.cpp | Validation rules, dual infill gating |
| LayerRegion.cpp | Zone surface type classification |
| PerimeterGenerator.cpp/.hpp | Inner shell perimeter generation |
| Fill.cpp, FillBase.cpp | Magma pattern factory registration |
| Surface.hpp/.cpp | 4 new surface types (stZoneOuter, stZoneInner, stZoneFloor, stZoneCeiling) |
| ExtrusionEntity.hpp/.cpp | 5 new extrusion roles |
| GCode.cpp/.hpp | Injection stage, Magma extrusion handling |
| GCode/CoolingBuffer.cpp | Injection cooling handling |
| GCode/GCodeProcessor.cpp/.hpp | Magma role parsing |
| GCode/ToolOrdering.cpp/.hpp | Injection tool ordering |
| Preset.cpp/.hpp | New settings in preset buckets |
| Tab.cpp | 4 new UI option groups |
| ConfigManipulation.cpp | Setting visibility/validation rules |
| GCodeViewer.cpp/.hpp | Role labels, colors, zone shell overlay |
| GLCanvas3D.cpp | Shell loading, 'J' key toggle |
| LibVGCodeWrapper.cpp | Role mapping, tube visualization vertices |
| libvgcode Types/Shaders/ViewerImpl | New roles, colors, vertical segment fix |

### Dependencies Added

| Dependency | Purpose |
|------------|---------|
| Google OR-Tools (CP-SAT) | Constraint programming solver for tube assignment |
| libigl (ramer_douglas_peucker) | 3D tube centerline simplification for preview |

---


### Solver Modes

- **Basic** (greedy only): ~100-500ms, ~77-81% coverage. Best for quick iteration.
- **Refined** (greedy + CP-SAT): adds 3-7% coverage at 2-10 minutes. Best for
  final production slices.

---

## Design Documents

- [DESIGN-TUBE-SOLVER.md](DESIGN-TUBE-SOLVER.md) — Two-stage tube assignment
  algorithm (greedy + CP-SAT)
- [DEFENSIVE_PUBLICATION.md](DEFENSIVE_PUBLICATION.md) — Public domain
  disclosure establishing prior art (CC0 1.0)

---

## License

OrcaSlicer fork (slicer code): AGPL-3.0. Magma documentation: MIT. Defensive publication: CC0 1.0 Universal.

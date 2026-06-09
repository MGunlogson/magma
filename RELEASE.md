# Magma v0.1 — Vertical Reinforcement Infill for FDM 3D Printing

**OrcaSlicer Fork | May 2026**

Magma creates sealed vertical channels within FDM-printed parts that are filled
with injected plastic during printing, forming continuous interlocking
reinforcement targeting Z-axis weakness in FDM parts. No hardware modifications
required.

This document is the v0.1 release notes and a complete reference for the new
configuration settings. For a project overview, screenshots, and the experimental
status of the physical printing side, see the [project README](README.md).

---

## What's New

### Core: Magma Infill System

- **Triangle cell infill pattern** (`ipMagmaTriangle`) — equilateral triangle
  lattice using (a,b,c) integer coordinates. Three families of parallel lines
  (0/60/120 degrees) form sealed triangular channels.

- **U-tube pair assignment** — adjacent cells are paired and connected by window
  gaps at their shared wall. Plastic is injected down one cell and rises up
  through the partner, forming interlocking U-shaped reinforcement columns.

- **Two-stage tube solver** —
  - *Stage 1 (Greedy):* Most-constrained-first heuristic assigns tubes in
    100-500ms. Achieves 75-80% coverage alone.
  - *Stage 2 (CP-SAT, optional):* Google OR-Tools constraint programming solver
    refines the greedy solution, improving coverage by 3-7% with weak plane
    avoidance. Uses integer micron arithmetic, discrete layer-boundary domains,
    and spatial block partitioning for scalability.

- **Injection G-code generation** — per-layer injection stage with configurable
  temperature, volumetric flow rate, Z-slam nozzle sealing, dwell time, and
  retraction. TSP-ordered injection points minimize travel.

- **Spiral interlock** — optional per-layer circular offset shifts the entire
  lattice so tubes follow helical paths, adding pullout resistance. Bounded by
  three physical constraints (line overlap, tube area overlap, helix angle).

- **Auto tube sizing** — derives tube interior width from nozzle outer diameter
  using circumscribed circle geometry, ensuring the nozzle flat covers all three
  triangle vertices during Z-slam injection.

- **Constriction detection** — when a cell's cross-sectional area drops below 30%
  between adjacent layers (geometry pinch points), the cell is split into separate
  spans so tubes cannot bridge across near-discontinuities.

- **Auto window height** — when set to 0 (default), the window gap height is
  derived from tube geometry with a 20% safety margin, ensuring the opening
  exceeds the tube cross-section for free plastic flow between paired cells.

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

- **Most-constrained-first scoring** — each cell×layer is scored by the sum of
  achievable tube heights across all neighbors. Lower score = fewer options =
  higher priority. Boundary cells (1 neighbor) are naturally prioritized over
  interior cells (3 neighbors), preventing stranding.

- **Periodic re-scoring** — heap is rebuilt every `max(200, num_edges/3)`
  assignments with fresh consumed state, correcting stale priority ordering.

- **Longest-tube preference** — greedily expands the longest valid tube between
  cell and its most-constrained neighbor, maximizing coverage per assignment.

- **Natural stagger** — the priority ordering inherently spreads tube boundaries
  across Z levels without explicit stagger logic.

### Solver: CP-SAT Refinement (Optional)

- **Integer micron arithmetic** — all Z coordinates use int64_t microns,
  eliminating floating-point comparison issues in the constraint solver.

- **Discrete domains** — start/end/size variables use `Domain::FromValues()`
  with actual layer boundary positions, tightening LP relaxation by 10-30%.

- **Weak plane avoidance** — per-cell cumulative stagger penalty using
  `AddCumulative` with Ring-0 (demand=2) and Ring-1 (demand=1) neighborhoods.
  Two-tier penalty (tight + wide) with configurable dodge distance.

- **Spatial block partitioning** — XY: R=6 cells/block, 2 passes with 50%
  overlap. Z: 50% overlapping windows. TBB parallelism across independent
  blocks, 8 CP-SAT workers per block.

- **Warm start from greedy** — committed segments become CP-SAT hints. Segments
  extending outside block boundaries become frozen intervals.

- **Progress reporting** — "Magma: refining tubes X/Y" status bar updates.
  Cancellation supported between solver passes.

### Injection

- **Z-slam sealing** — nozzle lowers into the print surface during injection to
  seal the tube opening. Configurable depth (default 0.05mm, warns above 3.5mm).

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
  line width clamped to OrcaSlicer's min_bead_width, excess area subtracted from
  tube volume calculations.

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

## New Configuration Settings (45 total)

### Dual Infill Zones (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `dual_infill_enabled` | off | Split infill into outer Magma zone + inner zone |
| `dual_infill_outer_width` | 5.0mm | Width of outer Magma zone |
| `dual_infill_shell_walls` | 1 | Boundary shell wall count |
| `dual_infill_shell_width` | auto | Boundary shell line width |
| `dual_infill_min_inner_width` | 10.0mm | Min inner zone width (smaller areas fill entirely with Magma) |
| `dual_infill_solid_layers` | 1 | Solid layers at zone floor/ceiling |
| `dual_infill_solid_thickness` | 0mm (range 0–10mm) | Min solid thickness at zone transitions |

### Dual Infill Speeds (Speed tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `dual_infill_outer_speed` | 0 (auto) | Outer zone infill speed |
| `dual_infill_shell_speed` | 0 (auto) | Zone boundary shell speed |
| `dual_infill_floor_speed` | 0 (auto) | Zone floor speed |
| `dual_infill_ceiling_speed` | 0 (auto) | Zone ceiling speed |

### Magma Pattern (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_tube_width_mode` | Auto | Auto (from nozzle OD) or Manual |
| `magma_nozzle_outer_diameter` | 0 (3x bore) | Nozzle tip flat outer diameter |
| `magma_interior_width` | 3.0mm | Manual tube interior width |
| `magma_spiral_interlock` | off | Helical tube paths for pullout resistance |
| `magma_overlap_line_correction` | on | Reduce line width at 60-degree overlaps |
| `magma_overlap_min_width` | 0 (auto: 90% of nozzle) | Floor for overlap-corrected line width (%) |

### Magma Tubes (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_window_height_mm` | 0 (auto) | Window gap height |
| `magma_tube_height` | 10mm (range 1–100mm) | Max U-tube segment height |
| `magma_tube_fill_factor` | 0.8 | Injection volume multiplier |
| `magma_tube_solver_mode` | Basic | Basic (greedy only, ~1s) or Refined (greedy + CP-SAT, much slower; only worth it on complex parts) |
| `magma_solver_timeout` | 60s (range 5–600s) | Total time budget for CP-SAT (Refined mode only) |
| `magma_boundary_dodge` | 0 (auto: 4× max layer height) | Min Z-separation between neighboring tube boundaries |

### Magma Injection (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_injection_temp` | 0 (no change) | Injection temperature |
| `magma_injection_speed` | 8 mm3/s | Volumetric injection flow rate |
| `magma_injection_z_slam` | 0.05mm | Nozzle depression depth for sealing (UI warns and resets values above 3.5mm — depth depends on nozzle geometry; measure your shoulder flat) |
| `magma_injection_dwell` | 0ms | Hold time after injection |
| `magma_injection_z_hop` | 2.0mm | Lift after each injection |
| `magma_injection_retract` | on | Retract after injection |
| `magma_injection_park` | on | Park nozzle during temp changes |
| `magma_injection_park_z_hop` | 10.0mm | Park Z-hop height |
| `magma_injection_park_retract` | 2.0mm | Extra retraction during park |
| `magma_iron_tube_ends` | off | Iron over injection points |

### Other tabs

| Setting | Tab | Default | Description |
|---------|-----|---------|-------------|
| `magma_injection_fan_speed` | Filament > Cooling | 100% (per-filament array) | Part cooling fan speed during injection. One value per filament |
| `magma_injection_filament` | Extruders | 0 (current) | Dedicated filament index for tube injection (0 = use whatever's currently loaded) |
| `dual_infill_outer_filament` | Extruders | 1 | Filament for outer Magma zone |

### Internal Settings (not in UI)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_ironing_flow` | 0 (auto) — % | Ironing flow rate for tube ends (percentage) |
| `magma_ironing_spacing` | 0 (auto) — mm | Ironing line spacing (mm) |
| `magma_ironing_speed` | 0 (auto) — mm/s | Ironing speed for tube ends |
| `magma_injection_edge_pref` | Interior | Which cell receives injection |

### General Improvements (non-Magma settings)

These ship as part of the Magma branch but apply to any infill / multi-material setup:

| Setting | Default | Description |
|---------|---------|-------------|
| `filter_narrow_sparse_infill` | on | Replace narrow strips of sparse infill with solid fill (morphological opening, distinct from the existing area-based filter) |
| `minimum_sparse_infill_width` | 0 (auto: 2× nozzle) | Threshold below which sparse infill is converted to solid |
| `ooze_prevention_park` | off | Park nozzle to a safe XY position during multi-extruder temperature changes (uses the same 5-tier safe-park system as Magma injection) |
| `ooze_prevention_park_z_hop` | 5.0 mm | Z lift when parking |
| `ooze_prevention_park_retract` | 2.0 mm | Extra retraction during park to prevent ooze |

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
| PrintConfig.hpp/.cpp | 45 new settings, 4 new enums |
| PrintObject.cpp | Magma build pipeline, solver invocation, progress/cancel |
| Print.cpp | Validation rules, dual infill gating |
| LayerRegion.cpp | Zone surface type classification |
| PerimeterGenerator.cpp/.hpp | Inner shell perimeter generation |
| Fill.cpp, FillBase.cpp | Magma pattern factory registration |
| Surface.hpp/.cpp | 3 new surface types (stZoneOuter, stZoneFloor, stZoneCeiling) |
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

- **Basic** (greedy only): ~100-500ms, 75-80% coverage. Best for quick iteration.
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

MIT (OrcaSlicer fork). Defensive publication under CC0 1.0 Universal.

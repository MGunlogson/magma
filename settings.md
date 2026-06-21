# Magma settings reference

Every Magma and dual-zone setting, where to find it in OrcaSlicer, and its default. The same text appears as tooltips in the app.

There are 50 settings: 45 for Magma and dual-infill, plus 5 general improvements that ship on the branch but apply to any print.

## Dual Infill Zones (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `dual_infill_enabled` | off | Split infill into outer Magma zone + inner zone |
| `dual_infill_outer_width` | 5.0mm | Width of outer Magma zone |
| `dual_infill_shell_walls` | 1 | Boundary shell wall count |
| `dual_infill_shell_width` | auto | Boundary shell line width |
| `dual_infill_min_inner_width` | 10.0mm | Min inner zone width (smaller areas fill entirely with Magma) |
| `dual_infill_solid_layers` | 1 | Solid layers at zone floor/ceiling |
| `dual_infill_solid_thickness` | 0mm (range 0–10mm) | Min solid thickness at zone transitions |

## Dual Infill Speeds (Speed tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `dual_infill_outer_speed` | 0 (auto) | Outer zone infill speed |
| `dual_infill_shell_speed` | 0 (auto) | Zone boundary shell speed |
| `dual_infill_floor_speed` | 0 (auto) | Zone floor speed |
| `dual_infill_ceiling_speed` | 0 (auto) | Zone ceiling speed |

## Magma Pattern (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_tube_width_mode` | Auto | Auto (from nozzle tip flat) or Manual |
| `magma_nozzle_outer_diameter` | 0 (3x bore) | Measured diameter of the flat at the nozzle tip — the seal size (label: "Nozzle tip flat") |
| `magma_nozzle_cone_half_angle` | 30° (range 5–60°) | Half-angle of the cone above the tip flat; Auto Z-slam uses it to size the press depth |
| `magma_interior_width` | 3.0mm | Manual tube interior width |
| `magma_spiral_interlock` | off | Helical tube paths for pullout resistance |
| `magma_overlap_line_correction` | off | Reduce line width at 60-degree overlaps (injection volume is corrected for overlap regardless) |
| `magma_overlap_min_width` | 0 (auto: 90% of nozzle) | Floor for overlap-corrected line width (%) |

## Magma Tubes (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_window_height_mm` | 0 (auto) | Window gap height |
| `magma_tube_height` | 4.5mm (range 1–100mm) | Max U-tube segment height |
| `magma_tube_fill_factor` | 1.0 | Injection volume multiplier |
| `magma_tube_solver_mode` | Basic | Basic (greedy only, ~1s) or Refined (greedy + CP-SAT, much slower; only worth it on complex parts) |
| `magma_solver_timeout` | 60s (range 5–600s) | Total time budget for CP-SAT (Refined mode only) |
| `magma_boundary_dodge` | 0 (auto: 4× max layer height) | Min Z-separation between neighboring tube boundaries |

## Magma Injection (Strength tab)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_injection_temp` | 0 (no change) | Injection temperature |
| `magma_injection_speed` | 10 mm3/s | Volumetric injection flow rate (capped at the filament's max volumetric speed; slicing warns if you set it higher) |
| `magma_injection_ordering` | Minimize travel | Tube visit order per layer: Minimize travel (shortest path) or Spread heat (separates nearby injections in time so combined heat does not melt neighbouring cells) |
| `magma_injection_z_slam_auto` | off | Compute Z-slam depth from nozzle geometry (tube opening, tip flat, cone half-angle) instead of by hand; when on, the manual depth below is ignored |
| `magma_injection_z_slam` | 0.05mm | Manual nozzle depression depth for sealing (ignored when Auto Z-slam is on; UI warns and resets values above 3.5mm; depth depends on nozzle geometry, so measure your shoulder flat) |
| `magma_injection_plunge` | on | "Slam-melt": ramp the nozzle deeper through the injection so the hot tip keeps the seal pressed as the tube fills (drives plastic down instead of mushrooming out) |
| `magma_injection_plunge_depth` | 0.4mm | Extra depth the nozzle ramps to by the end of injection, on top of the seal depth |
| `magma_injection_dwell` | 0ms | Hold time after injection |
| `magma_injection_retract` | on | Retract after injection (during the break-lift, so it doesn't suck the plug back) |
| `magma_injection_park` | on | Park nozzle during temp changes |
| `magma_injection_park_z_hop` | 10.0mm | Park Z-hop height |
| `magma_injection_park_retract` | 2.0mm | Extra retraction during park |
| `magma_injection_iron` | on | Crater ironing: after each injection, spiral the nozzle inward so the cone plows the displaced rim back into the crater and irons it flat while scraping the nozzle clean (replaces tube-end ironing). Travel between sites uses the printer's normal z-hop/retract |
| `magma_injection_iron_turns` | 2 | Inward-spiral turns (more = shallower cuts, cleaner, slower) |
| `magma_injection_iron_speed` | 0 (auto: ironing speed) | Crater ironing move speed |
| `magma_injection_iron_hover` | 0.1mm | Hover above layer height while over neighbour cells, so it never irons a neighbour's air hole shut; descends over its own crater |
| `magma_injection_iron_margin` | 0.5mm | How far outside the crater footprint the spiral starts |

## Other tabs

| Setting | Tab | Default | Description |
|---------|-----|---------|-------------|
| `magma_injection_fan_speed` | Filament > Cooling | 100% (per-filament array) | Part cooling fan speed during injection. One value per filament |
| `magma_injection_filament` | Extruders | 0 (current) | Dedicated filament index for tube injection (0 = use whatever's currently loaded) |
| `dual_infill_outer_filament` | Extruders | 1 | Filament for outer Magma zone |

## Internal settings (not in UI)

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_injection_edge_pref` | Interior | Which cell receives injection |

## General improvements (non-Magma)

These ship as part of the Magma branch but apply to any infill or multi-material setup.

| Setting | Default | Description |
|---------|---------|-------------|
| `filter_narrow_sparse_infill` | on | Replace narrow strips of sparse infill with solid fill (morphological opening, distinct from the existing area-based filter) |
| `minimum_sparse_infill_width` | 0 (auto: 2× nozzle) | Threshold below which sparse infill is converted to solid |
| `ooze_prevention_park` | off | Park nozzle to a safe XY position during multi-extruder temperature changes (uses the same 5-tier safe-park system as Magma injection) |
| `ooze_prevention_park_z_hop` | 5.0 mm | Z lift when parking |
| `ooze_prevention_park_retract` | 2.0 mm | Extra retraction during park to prevent ooze |

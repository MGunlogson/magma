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

A cell is only kept on a layer when its clipped tube cross-section is at least 70% of the ideal cell area (and the injection point has room to seal); short or pinched cells are dropped.

| Setting | Default | Description |
|---------|---------|-------------|
| `sparse_infill_pattern` | (your choice) | Selecting Magma Honeycomb / Magma Rectilinear / Magma Triangle / Magma Tri-hex here is what turns on Magma (dropdown order). Honeycomb = regular pointy-top hexagon cells, drawn with OrcaSlicer's native honeycomb toolpath (a fast continuous vertical zigzag) for print speed — it traces the vertical walls doubled and the slants single, and the lattice is pre-expanded so the open tube is still a regular hexagon; Rectilinear = square cells; Triangle = equilateral-triangle cells; Tri-hex = mixed hexagon + triangle cells. Cell size comes from the tube interior width, not infill density |
| `dual_infill_outer_pattern` | Magma Rectilinear | Which Magma pattern fills the outer zone when dual infill is on (any of Honeycomb / Rectilinear / Triangle / Tri-hex) |
| `magma_tube_width_mode` | Auto | Auto (from nozzle tip flat) or Manual |
| `magma_nozzle_outer_diameter` | **required** | Measured diameter of the flat at the nozzle tip — the ring around the bore that presses on the print, *not* the full tip width (label: "Nozzle tip flat"). Every tube is sized so this flat can seal it, so slicing **fails with an error** until it is set. Measure the flat contact ring with calipers, or find it by printing: set Tube fill factor to 0.1 so injections leave a witness mark, Max nozzle immersion to 0, and raise the flat 0.2mm per print until injections smear across the surface instead of sitting inside the openings — then use the last clean value. Reference: a classic E3D 0.6mm nozzle measures 1.7mm |
| `magma_nozzle_cone_half_angle` | 30° (range 5–60°) | Half-angle of the cone above the tip flat. The cone is what seals a tube wider than the flat, so this sets how far the nozzle must descend for a given opening |
| `magma_interior_width` | 3.0mm | Manual tube interior width |
| `magma_spiral_interlock` | off | Helical tube paths for pullout resistance |

Line crossings double-deposit material, and the injection volume is **always** corrected for it, sized to the deposited line width. The old `magma_overlap_line_correction` / `magma_overlap_min_width` pair — which additionally thinned every bead so the crossings over-extruded less — has been **removed**. It defaulted to off (changing line width causes its own print problems) and was the only reason the tube map carried two different line widths, which had produced several places that disagreed about which one to use. Vertex overlap is a geometry problem; thinning every line to average out a local excess was the wrong lever. Set a lower sparse infill line width by hand if you want the old behaviour. (Still in git history.)

## Magma Tubes (Strength tab)

Injection volume is measured from the actual deposited toolpath after the infill is generated — this automatically captures the doubled walls, line-crossing overlaps, the window gap, and part-edge clipping — replacing the old geometric estimate.

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_window_height_mm` | 0 (auto) | Window gap height. Auto = the geometric height that makes the window flow area match the tube interior, plus a layer; Tri-hex sizes it from the vent triangle (with a 1.0 mm floor) since the window feeds only the vent |
| `magma_tube_height` | 4.0mm (range 1–100mm) | Max U-tube segment height. 3–4mm is the sweet spot: past that the melt freezes before reaching the tube bottom. Longer tubes need a wider channel to stay molten, i.e. a larger nozzle flat |
| `magma_tube_fill_factor` | 0.9 | Injection volume multiplier. 0.9 beats 1.0 at sane tube heights — the calculation assumes a perfect prism, and slightly underfilling avoids plastic mushrooming back out around the nozzle |
| `magma_tube_solver_mode` | Basic | Basic (greedy only, ~1s) or Refined (greedy + CP-SAT, much slower; only worth it on complex parts) |
| `magma_solver_timeout` | 60s (range 5–600s) | Total time budget for CP-SAT (Refined mode only) |
| `magma_boundary_dodge` | 0 (auto: 4× max layer height) | Min Z-separation between neighboring tube boundaries |

## Magma Injection (Strength tab)

> ⚠️ **Klipper users:** injection extrudes in place (lots of E, almost no XYZ movement), which trips Klipper's `max_extrude_cross_section` guard and **aborts the print** at the first injection. Raise it in `[extruder]` (e.g. `max_extrude_cross_section: 5000`, plus `max_extrude_only_distance: 500`). It's a `printer.cfg` setting and can't be set from G-code. See the [README](README.md#-printer-firmware-setup--required-before-you-print).

| Setting | Default | Description |
|---------|---------|-------------|
| `magma_injection_temp` | 0 (no change) | Injection temperature |
| `magma_injection_speed` | 0 (filament max volumetric) | Volumetric injection flow rate. 0 runs at the filament's max volumetric speed, which is what you want: the tube is narrow and the melt cools all the way down, so filling at the material's limit fills more reliably than a fixed rate — and it tracks the filament automatically. An explicit value is used as-is, still capped at that limit. Slicing fails if you set 0 on a filament that defines no max volumetric speed |
| `magma_injection_ordering` | Spread heat | Tube visit order per layer: Minimize travel (shortest path) or Spread heat (separates nearby injections in time so combined heat does not melt neighbouring cells) |
| `magma_max_immersion` | 0.6mm (range 0–3.5mm) | **How deep the nozzle may descend INTO a tube while sealing it — the setting that governs tube deformation.** Immersion exists only to fit a tube wider than the nozzle flat: a tube the flat covers is sealed by seating on the rim with no descent at all. Anything wider is sealed by the cone above the flat, which must travel down into the tube before it is wide enough. It is also what damages tubes — past first contact the nozzle interferes by a fixed sliver regardless of tube size; what varies is how far the hot tip travels *inside*, remelting the wall it passes. In testing 0.5mm printed cleanly and 1.1mm visibly deformed the cells. With Auto tube sizing this also **sizes** the tubes: they are made as large as this budget allows. 0 = tubes the flat covers outright. Requires a measured nozzle flat |
| `magma_auto_slam_press` | 0.1mm | Squish applied when the flat already covers the opening and no descent is needed — the nozzle seats on the rim and this is what guarantees positive contact. Only reached at low immersion; larger tubes seal by descending instead |
| `magma_injection_z_slam_offset` | 0mm (range ±1mm) | Adds this much to the calculated seal depth. **Only meaningful with Manual tube width** — in Auto sizing the tube is sized so the depth already lands exactly on the immersion budget and this is clamped back to it, so a positive value there does nothing. Use Max nozzle immersion instead |
| `magma_injection_plunge` | on | "Slam-melt": ramp the nozzle deeper through the injection so the hot tip keeps the seal pressed as the tube fills (drives plastic down instead of mushrooming out) |
| `magma_injection_plunge_depth` | 0.05mm | Extra depth the nozzle ramps to by the end of injection, on top of the seal depth. This spends from the same immersion budget as the seal depth — same hot metal, same direction — so slam + plunge is clamped to Max nozzle immersion |
| `magma_injection_dwell` | 0ms | Hold time after injection |
| `magma_injection_retract` | on | Retract after injection (during the break-lift, so it doesn't suck the plug back) |
| `magma_injection_park` | on | Park nozzle during temp changes |
| `magma_injection_park_z_hop` | 10.0mm | Park Z-hop height |
| `magma_injection_park_retract` | 2.0mm | Extra retraction during park |
| `magma_injection_iron` | on | Crater ironing: after each injection, spiral the nozzle inward so the cone plows the displaced rim back into the crater and irons it flat while scraping the nozzle clean. Travel between sites uses the printer's normal z-hop/retract |
| `magma_injection_iron_turns` | 0 (auto) | Inward-spiral turns (more = shallower cuts, cleaner, slower). Auto steps inward by half the nozzle flat per turn — the flat is also the width of the bevel doing the plowing, so the step has to scale with it |
| `magma_injection_iron_speed` | 40 mm/s | Crater ironing move speed. 0 borrows your ironing speed instead — but note that surface ironing and crater plowing are not the same operation |
| `magma_injection_iron_hover` | 0.2mm (min 0.01) | Hover above layer height while over neighbour cells, so it never irons a neighbour's air hole shut; descends over its own crater. Cannot be 0 — at 0 the hover and press heights are identical, which silently disables the neighbour clearance entirely |
| `magma_injection_edge_pref` | Interior | Which cell of each U-tube pair receives the injection. Interior keeps injection marks away from exterior walls; Exterior may fill the outer half of the tube better at some cost to wall quality |
| `magma_injection_iron_margin` | 0 (auto) | How far outside the crater footprint the spiral starts. Auto = half the nozzle flat plus a little clearance. Pressing in displaces material outward *and upward* into a rim around the crater; the spiral plows it back with the nozzle **bevel**, not the flat, so the flat has to begin outside that rim |

## Other tabs

| Setting | Tab | Default | Description |
|---------|-----|---------|-------------|
| `magma_injection_fan_speed` | Filament > Cooling | 100% (per-filament array) | Part cooling fan speed during injection. One value per filament. **-1 leaves the fan at whatever the print is already using** — worth considering, since the melt is being pushed down a narrow channel and full cooling can freeze it before it reaches the bottom |
| `magma_injection_filament` | Extruders | 0 (current) | Dedicated filament index for tube injection (0 = use whatever's currently loaded) |
| `dual_infill_outer_filament` | Extruders | 1 | Filament for outer Magma zone |

## General improvements (non-Magma)

These ship as part of the Magma branch but apply to any infill or multi-material setup.

| Setting | Default | Description |
|---------|---------|-------------|
| `filter_narrow_sparse_infill` | on | Replace narrow strips of sparse infill with solid fill (morphological opening, distinct from the existing area-based filter) |
| `minimum_sparse_infill_width` | 0 (auto: 2× nozzle) | Threshold below which sparse infill is converted to solid |
| `ooze_prevention_park` | off | Park nozzle to a safe XY position during multi-extruder temperature changes (uses the same 5-tier safe-park system as Magma injection) |
| `ooze_prevention_park_z_hop` | 5.0 mm | Z lift when parking |
| `ooze_prevention_park_retract` | 2.0 mm | Extra retraction during park to prevent ooze |

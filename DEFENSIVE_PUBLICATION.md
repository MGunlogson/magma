---
render_with_liquid: false
---

# Defensive Publication: Magma Vertical Reinforcement Infill System for FDM 3D Printing

**Publication Date:** February 9, 2026 (Updated March 16, 2026; June 23, 2026)

**Authors:** Mark Gunlogson

**Status:** Public Domain Disclosure under CC0 1.0 Universal

---

## 1. Abstract

This defensive publication discloses a complete software system for vertical reinforcement of Fused Deposition Modeling (FDM) 3D printed parts. The system, named Magma, modifies open-source slicer software (OrcaSlicer) to generate a user-selectable lattice infill pattern -- triangular, rectilinear (square), or tri-hex (hexagon + triangle) -- containing hollow channels (tubes) that are filled with injected molten plastic **during printing on a per-layer basis** -- not as a post-print operation. The injection occurs as a dedicated print stage within each layer's processing, using the printer's existing extruder at elevated temperature.

The system requires **no hardware modifications** to standard FDM printers. It is implemented entirely as software modifications to the slicer's infill generation, G-code output, and preview rendering subsystems.

Key technical innovations disclosed herein include:

1. A triangular lattice coordinate system using (a, b, c) integer coordinates with weak plane avoidance via CP-SAT cumulative scheduling constraints, enabling tube boundary placement that prevents weak Z-planes.

2. A three-constraint spiral offset system that creates helical, interlocking tubes by applying a circular translation to the entire lattice per layer, with displacement bounded by line overlap, tube area overlap, and helix angle constraints.

3. A coupled thermal-pressure injection depth model (designed and tested, currently replaced by user-configured tube height -- see Section 9.e) where the volumetric injection speed variable drops out of the simultaneous equations, yielding an optimal tube height that self-adjusts to balance thermal freezing and extruder pressure limits.

4. A dual-identity lattice architecture where cell identity (for stable tube pairing across layers) uses a fixed reference lattice, while per-layer geometry checks (for boundary detection and rendering) use a spiral-offset lattice.

5. A two-stage tube assignment solver combining a greedy most-constrained-first heuristic (100-500ms) with optional CP-SAT constraint programming refinement, using integer micron arithmetic, discrete layer-boundary domains, spatial block partitioning, and cumulative scheduling constraints for weak plane avoidance.

6. A G-code comment protocol (`MAGMA_TUBE`) for embedding 3D tube visualization waypoints that enables preview rendering of filled tubes without modifying the G-code motion command structure.

7. A dual-zone architecture ("egg model") using repurposed SLA hollowing algorithms for FDM inner shell boundary generation, with constrained mean curvature flow smoothing that prevents expansion into the shell zone.

8. A 5-tier safe park positioning system that finds optimal nozzle positions during injection temperature changes by classifying print surface regions (empty > support > sparse infill > solid infill > z-hop only).

9. An automatic, **per-tube** Z-slam sealing-depth model derived from nozzle cone geometry, in which each tube's press-down depth is computed from that tube's ACTUAL opening at its cap layer (the farthest point of the clipped opening from the injection point), the nozzle tip flat diameter, and the nozzle cone half-angle as `depth = max(epsilon, (opening + margin - flat) / (2 * tan(half_angle)))`, so the widening cone above the tip flat reaches each individual opening's width and seals it without manual tuning. Because the depth is derived per tube from the real (possibly boundary-clipped) opening rather than a single global ideal, smaller boundary openings receive a correspondingly shallower, non-over-pressed slam.

10. A global, per-print-layer thermal-aware injection ordering that, across all objects and instances on a layer, separates spatially-near injections in time to prevent combined heat from re-melting neighbouring cells. It is driven by a continuous decay field in which every prior injection is a heat source fading in both time and space (`exp(-dt/tau) * exp(-dist/lambda)`), built by a dispersion greedy that injects wherever is currently coolest-on-arrival and refined by a violation-directed local search; because `dt` is real elapsed injection time, inter-injection travel counts as cooling rather than opposing the spread. The solved order is cached in a dedicated slicing stage. (An equivalent exact CP-SAT routing formulation of the same objective was also implemented, measured, and is disclosed in Section 6.h as an alternative.)

11. A progressive-plunge ("slam-melt") injection in which the sealing nozzle is ramped deeper into the tube top *during* extrusion, from the geometric seal depth to that depth plus a configured plunge, so the hot tip continuously sinks into the softening surface and maintains the seal under the rising channel pressure -- driving plastic down the tube instead of letting it escape laterally around the nozzle -- while the extrusion holds its commanded volumetric rate.

12. A neighbour-aware crater-ironing finishing move that, after each injection, spirals the nozzle inward over the injection point so the angled nozzle cone plows the displaced rim back into the crater (deflecting material both inward and downward by the cone-normal geometry) and irons it flat while scraping the nozzle clean; the nozzle hovers above layer height over neighbouring cells and only descends to press inside a geometrically-derived radius that keeps the flat clear of any neighbouring tube opening's far vertex, guaranteeing a neighbour's air-escape hole is never sealed.

13. A shape-generic lattice and geometry abstraction in which the tube grid, neighbour pairing, window placement, opening size, cell-area/volume, and injection geometry are all expressed through a per-shape strategy interface, so multiple infill patterns -- triangular (equilateral cells), rectilinear (square cells), and tri-hex (hexagon + triangle cells) -- share a single tube-assignment solver, injection pipeline, and preview-rendering pipeline. Tri-hex additionally uses vent-based injection allocation (a single injection serving multiple connected vents) rather than only pairwise U-tube coupling. Any pattern may also serve as the outer-zone fill in the dual-zone architecture.

14. A dual cell-presence gate that admits a cell as a tube cell on a given layer only when BOTH (a) its clipped interior area is at least a fixed fraction (70%) of the ideal cell area AND (b) the injection point retains at least the nozzle-flat radius of clearance to the nearest opening boundary. The area test bounds how much of the cross-section survives clipping; the clearance test -- evaluated at the actual injection point -- rejects shapes where a spike or pinch intrudes toward the centre (which the area test alone would pass), guaranteeing the nozzle flat can seat. This unified per-layer gate supersedes a separate constriction-detection pass, and because injection volume is computed from each layer's actual clipped area, admitted partial cells are dosed proportionally.

15. A clipped-cavity centroid injection point, in which the nozzle aims not at the ideal lattice cell centre but at the centroid of the cell's actual (boundary-clipped) opening at the cap layer. For a regular polygon the centroid coincides with the inscribed-circle centre, so boundary-clipped cells inject at the point of greatest clearance from the part wall instead of at a centre that may sit near or past the clip -- maximizing seal reliability -- and it falls back to the lattice centre if a concave clip places the centroid outside the opening.

16. A one-to-many ("manifold") injection unit and its vent-fill allocation, in which a single injection fills a hub cell plus multiple **equal-length** vent legs -- windows pinned to the hub-tube's bottom so every leg spans the hub-tube's layer range -- and a per-vent allocation maximizes filled volume by: (a) forming an unavailable-layer mask per vent = layers absent due to part geometry UNION layers already committed to other injections; (b) discarding any candidate hub-tube whose layer range crosses that mask (which would trap injected air); and (c) within each remaining present-run, selecting by weighted interval scheduling over the contained hub-tube ranges the non-overlapping set of tubes that fills the most layers, tie-broken toward the least-loaded hub. Each vent layer is filled exactly once and hubs are uncapped, so the allocation is independent per vent and yields the maximal fill achievable with windows aligned to real tube boundaries. The pairwise U-tube is the degenerate single-leg case.

All algorithms, code, and structures described in this document are dedicated to the public domain to establish prior art and prevent patenting by third parties.

---

## 2. Definitions and Core Structures

### 2.1 Magma Tubes

Hollow channels formed within the selected Magma lattice infill pattern. Each tube is defined by a single lattice cell's interior space, bounded by the infill line walls and by the layers above and below. The interior cross-section depends on the chosen pattern -- an equilateral triangle (Magma Triangle), a square (Magma Rectilinear), or a hexagon or triangle (Magma Tri-hex) -- sized by the cell's interior width (auto-calculated from nozzle geometry, or user-specified). Tubes span multiple layers vertically and are filled with injected plastic during printing.

### 2.2 Windows (Fenestrations)

Gaps intentionally left in the shared infill walls between two adjacent cells. A window is created by omitting a segment of the infill line that forms the shared edge between two cells, for a specified number of layers (the window height). Windows connect paired tubes to form U-tube pairs, allowing injected plastic to flow from one cell down through the window into the adjacent cell.

### 2.3 U-tube Pairs

Two adjacent cells connected by a window at their shared edge. Plastic is injected into one cell (cell_a, the injection side) at the top of the tube, flows down through the tube, crosses through the window into the adjacent cell (cell_b, the vent side), and rises up. The resulting solidified plastic forms a U-shaped interlocking reinforcement column. Each U-tube pair has a defined start layer (bottom), end layer (top/cap), and injection volume.

### 2.4 Stagger Levels

Vertical offsets applied to tube boundary positions across different cells to prevent all boundaries from aligning at the same Z-height, which would create a weak horizontal plane. In the current implementation, stagger is achieved via the CP-SAT solver's cumulative scheduling constraints for weak plane avoidance (Section 5.d), rather than algebraic coloring. The solver penalizes boundary clustering within each cell's Ring-0 + Ring-1 neighborhood, producing a natural spread of tube boundaries across Z levels.

### 2.5 Triangle Grid (a, b, c) Coordinate System

A coordinate system for identifying triangular cells using three integer coordinates. The triangular grid uses three axes at 60-degree angles. Cells are classified by the sum of their coordinates:

- **Up triangles** (pointing up): `a + b + c == 2`
- **Down triangles** (pointing down): `a + b + c == 1`

Each cell has exactly three neighbors, obtained by incrementing (for down triangles) or decrementing (for up triangles) one coordinate by 1. The coordinate system enables efficient neighbor lookup, deterministic stagger calculation, and consistent cell identification across layers.

### 2.6 Dual-Zone Architecture ("Egg Model")

The print volume is divided into concentric zones:

- **Shell** (eggshell): The outermost perimeter walls of the object, unchanged from standard FDM printing.
- **Outer zone** (egg white): The region between the shell and the inner boundary, filled with the Magma triangular lattice pattern containing the injection tubes.
- **Membrane** (egg membrane): An inner shell boundary generated using repurposed SLA hollowing algorithms, consisting of additional perimeter walls that separate the outer zone from the inner zone.
- **Inner zone** (yolk): The innermost region, which may be filled with standard infill patterns (gyroid, rectilinear, etc.) or left hollow.

Three new surface types support this architecture: `stZoneOuter` (outer zone infill), `stZoneFloor` (inner shell floor -- solid layer where zone begins), and `stZoneCeiling` (inner shell ceiling -- solid layer where zone ends).

---

## 3. IMPLEMENTED SYSTEM -- Geometric Algorithms

**Implementation status: IMPLEMENTED and tested in software. All code excerpts are from the working implementation.**

### 3.a Triangular Lattice Coordinate System

The triangular lattice uses (a, b, c) integer coordinates where up triangles have `a + b + c == 2` and down triangles have `a + b + c == 1`. This coordinate system supports O(1) neighbor lookup, O(1) stagger level computation, and O(1) cell classification.

{% raw %}
```cpp
// src/libslic3r/Magma/MagmaTriangleCell.hpp

struct TriangleCell {
    int a, b, c;  // Triangle coordinates

    TriangleCell() : a(0), b(0), c(0) {}
    TriangleCell(int a_, int b_, int c_) : a(a_), b(b_), c(c_) {}

    // Check if this is an upward-pointing triangle (△)
    bool is_up() const { return (a + b + c) == 2; }

    bool operator==(const TriangleCell& other) const {
        return a == other.a && b == other.b && c == other.c;
    }

    bool operator<(const TriangleCell& o) const {
        if (a != o.a) return a < o.a;
        if (b != o.b) return b < o.b;
        return c < o.c;
    }

    // Adjacent cells sharing an edge.
    // Up triangle neighbors: decrement one coordinate by 1 → down triangles (sum=1).
    // Down triangle neighbors: increment one coordinate by 1 → up triangles (sum=2).
    std::array<TriangleCell, 3> neighbors() const {
        if (is_up())
            return {{ {a-1,b,c}, {a,b-1,c}, {a,b,c-1} }};
        else
            return {{ {a+1,b,c}, {a,b+1,c}, {a,b,c+1} }};
    }
};

// Hash functor for TriangleCell, suitable for use in unordered containers.
struct TriangleCellHash {
    size_t operator()(const TriangleCell &c) const {
        size_t h = std::hash<int>()(c.a);
        h ^= std::hash<int>()(c.b) + 0x9e3779b9 + (h << 6) + (h >> 2);
        h ^= std::hash<int>()(c.c) + 0x9e3779b9 + (h << 6) + (h >> 2);
        return h;
    }
};
```
{% endraw %}

The lattice maps (a, b, c) coordinates to world (x, y) positions via a skewed coordinate system:

```cpp
// src/libslic3r/Magma/MagmaTriangleCell.hpp

class TriangleLattice {
public:
    explicit TriangleLattice(double cell_spacing, double offset_x = 0.0, double offset_y = 0.0)
        : m_cell_spacing(cell_spacing)
        , m_edge_length(triangle_side_length(cell_spacing))
        , m_offset_x(offset_x)
        , m_offset_y(offset_y)
    {}

    // Convert lattice coordinates to world coordinates
    Vec2d to_world(double lx, double ly) const {
        return Vec2d(
            lx * m_edge_length + ly * m_edge_length * 0.5 + m_offset_x,
            ly * m_cell_spacing + m_offset_y
        );
    }

    // Convert world coordinates to lattice coordinates
    std::pair<double, double> to_lattice(double px, double py) const {
        double adjusted_x = px - m_offset_x;
        double adjusted_y = py - m_offset_y;
        double ly = adjusted_y / m_cell_spacing;
        double lx = (adjusted_x - ly * m_edge_length * 0.5) / m_edge_length;
        return {lx, ly};
    }

    // Get the triangle cell containing a world point
    TriangleCell cell_at(double px, double py) const {
        auto [lx, ly] = to_lattice(px, py);
        int col = static_cast<int>(std::floor(lx));
        int row = static_cast<int>(std::floor(ly));
        double fx = lx - col;
        double fy = ly - row;
        // fx + fy < 1 means UP triangle, >= 1 means DOWN triangle
        bool is_up = (fx + fy) < 1.0;
        int c = is_up ? (2 - col - row) : (1 - col - row);
        return TriangleCell(col, row, c);
    }

private:
    double m_cell_spacing;
    double m_edge_length;
    double m_offset_x;
    double m_offset_y;
};
```

The cell spacing is derived from the physical geometry: `cell_spacing = interior_width + line_width`, representing the center-to-center distance between parallel infill lines. The triangle side length is `cell_spacing * 2 / sqrt(3)`.

### 3.b Stagger Coloring (Original Design, Replaced)

**Note:** The algebraic stagger coloring described below was the original design approach for weak plane avoidance. The mathematical property is correct, but the implementation now uses CP-SAT cumulative scheduling constraints (Section 5.d) instead, which provide more flexible stagger that adapts to variable tube heights and boundary conditions.

The stagger level formula `(a - b) % n` produces a perfect 3-coloring of the triangular lattice. This is a mathematical property of the coordinate system: for any cell with neighbors obtained by incrementing or decrementing exactly one of (a, b, c), the `(a - b)` value changes by exactly +1 or -1, guaranteeing that all three neighbors of any cell have distinct `(a - b) mod 3` values. This eliminates the need for graph coloring algorithms -- the coloring is computed in O(1) per cell from coordinates alone.

For `num_levels >= 3`, the stagger pattern ensures that no two adjacent cells have windows at the same Z-height, preventing horizontal weak planes. The formula generalizes to any number of stagger levels, though 3 is optimal (the chromatic number of the triangular lattice dual graph).

### 3.c Three-Constraint Spiral Offset for Helical Interlock

The spiral offset system translates the entire triangular lattice in a circular path per layer, creating helical tubes that interlock with adjacent tubes spiraling in the opposite rotational direction. The per-layer displacement is bounded by three independent constraints:

```cpp
// src/libslic3r/Magma/MagmaSpiralOffset.cpp

SpiralParams compute_spiral_params(float interior_width, float line_width,
                                    float layer_height, bool enabled)
{
    SpiralParams params;
    params.enabled = enabled;

    if (!enabled) {
        params.spiral_radius = 0.f;
        params.angle_per_layer = 0.f;
        return params;
    }

    // Constraint 1: Printability - 40% line overlap between layers
    constexpr float target_line_overlap = 0.40f;
    const float max_disp_line = (1.0f - target_line_overlap) * line_width;

    // Constraint 2: Tube continuity - 75% tube area overlap between layers
    constexpr float target_tube_overlap = 0.75f;
    const float max_disp_tube = (1.0f - target_tube_overlap) * interior_width;

    // Constraint 3: Maximum helix angle for injection flow.
    // Cap so helix angle never exceeds ~27 degrees (tan(27) = 0.5).
    constexpr float MAX_HELIX_TAN = 0.5f;
    const float max_disp_helix = MAX_HELIX_TAN * layer_height;

    // Use the most restrictive constraint
    const float max_displacement = std::min({max_disp_line, max_disp_tube, max_disp_helix});

    // Interlock: swept circles of adjacent tubes should touch
    const float cell_spacing = static_cast<float>(
        cell_spacing_from_geometry(interior_width, line_width));
    params.spiral_radius = cell_spacing / 2.0f;

    // Per-layer angle from radius and displacement
    params.angle_per_layer = max_displacement / params.spiral_radius;

    return params;
}

Vec2d compute_spiral_offset(const SpiralParams &params, int layer_id)
{
    if (!params.enabled)
        return Vec2d(0.0, 0.0);

    const float layer_angle = float(layer_id) * params.angle_per_layer;
    return Vec2d(
        params.spiral_radius * std::cos(layer_angle),
        params.spiral_radius * std::sin(layer_angle)
    );
}
```

The circular offset creates helical tubes: as the lattice translates in a circle, each cell's center traces a helix through 3D space. Adjacent cells spiral in opposite rotational directions because they are on opposite sides of the shared lattice lines. This produces mechanical interlock between adjacent tube pairs, significantly increasing the shear strength of the reinforcement structure.

The three constraints ensure: (1) infill lines maintain 40% overlap between layers for reliable adhesion during printing, (2) tube cross-sections maintain 75% area overlap to preserve continuous channels for injection, and (3) the helix angle stays below 27 degrees to allow injected plastic to flow through the channel without excessive resistance.

### 3.d Dual Identity vs. Position Tracking

A critical architectural decision separates cell identity from cell position. Cell identity (which cell a given (a,b,c) coordinate refers to) must be stable across all layers for tube pairing to work correctly -- the same (a,b,c) cell on layer 5 must be the same tube as (a,b,c) on layer 50. However, the physical position of that cell shifts per layer due to spiral offset.

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — scan_layers()

// FIXED reference lattice for cell IDENTITY (a,b,c coordinates).
// Cell identity must be stable across layers for tube pairing to work.
TriangleLattice ref_lattice(m_cell_spacing, 0.0, 0.0);

for (int i = 0; i < int(layers.size()); ++i) {
    const Layer *layer = layers[i];
    const int layer_id = static_cast<int>(layer->id());

    // Spiral-offset lattice for this layer's actual cell positions.
    // Pre-built per layer during build() and cached in m_layer_data[layer_id].lattice
    // (eliminates repeated sin/cos + TriangleLattice construction).
    const TriangleLattice &layer_lattice = m_layer_data[layer_id].lattice;

    // ... enumerate cells using ref_lattice for identity,
    // but use layer_lattice for position/containment checks ...
}
```

Lattices are pre-built per layer during `build()` and cached in `m_layer_data[layer_id].lattice`, eliminating repeated `sin`/`cos` computation and `TriangleLattice` construction during `scan_layers()`.

The reference lattice (zero offset) is used to enumerate cells and assign (a,b,c) coordinates. The layer lattice (with spiral offset) is used for geometric checks: is the cell center inside the model boundary? What is the cell's area after clipping to the model? This dual-lattice approach ensures that tube assignments are stable while geometric computations reflect the actual per-layer positions.

### 3.e Two-Tier Constriction Detection (superseded by the dual presence gate)

**Historical note:** the standalone two-tier constriction-detection pass below has been **superseded by the dual cell-presence gate** (Section 1, claim 14, and Section 3.f). A cell now counts as present on a layer only if its clipped area is at least 70% of the ideal cell area AND the injection point keeps at least the nozzle-flat radius of clearance to the nearest opening boundary. Because that per-layer gate already excludes any under-area or pinched layer from a cell's presence, no separate constriction pass is run. The original algorithm is retained here for prior art.

Constriction detection identifies layers where a cell's usable area drops sharply, indicating a geometric pinch point (e.g., where a model narrows) that would block injection flow. A tube should not bridge across such a constriction.

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — detect_constrictions()

void MagmaTubeMap::detect_constrictions()
{
    int constrictions_found = 0;

    for (auto &[cell, presence] : m_cells) {
        if (presence.first_layer == presence.last_layer)
            continue;

        for (int i = presence.first_layer; i < presence.last_layer; ++i) {
            if (!presence.present(i) || !presence.present(i + 1))
                continue;

            double area_i   = presence.area(i);
            double area_ip1 = presence.area(i + 1);

            if (area_i <= 0.0 || area_ip1 <= 0.0)
                continue;

            // Tier 1: Area ratio heuristic (fast)
            double ratio = std::min(area_i, area_ip1) / std::max(area_i, area_ip1);
            if (ratio > 0.7)
                continue;  // Healthy overlap, skip expensive check

            // Tier 2: Severe constriction splits the cell
            if (ratio < 0.3) {
                int idx = i + 1 - presence.first_layer;
                if (idx > 0 && idx < int(presence.layers.size())) {
                    presence.layers[idx] = false;
                    presence.areas[idx]  = 0.0;
                    ++constrictions_found;
                }
            }
        }
    }
}
```

Tier 1 is a fast area-ratio heuristic: if consecutive layers have area ratio > 0.7, the cell is healthy and no further check is needed. Tier 2 applies a stricter threshold (ratio < 0.3) to split the cell's presence, preventing tubes from bridging across near-discontinuities. This two-tier approach avoids the cost of full polygon overlap computation for the majority of cells that pass the fast check.

### 3.f Boundary Cell Area Computation

For cells near the model boundary, the system uses a fast/slow dual-path approach:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — scan_layers()

// Interior inset: if cell center is this far inside the zone region,
// the tube inscribed circle fits entirely.
const coord_t interior_inset = scale_(m_interior_width * 0.5);
ExPolygons interior_region = offset_ex(zone_regions, -interior_inset);

for (const TriangleCell &cell : cells) {
    Vec2d center_mm = layer_lattice.cell_center(cell);
    Point center_pt(scale_(center_mm.x()), scale_(center_mm.y()));

    // Fast path: center inside tube-clearance inset -> fully unobstructed
    bool is_interior = false;
    for (const ExPolygon &ep : interior_region) {
        if (ep.contains(center_pt)) {
            is_interior = true;
            break;
        }
    }

    if (is_interior) {
        m_cells[cell].mark_present(layer_id, inset_area_scaled2);
        continue;
    }

    // Slow path: boundary cell, compute actual clipped area
    std::array<Vec2d, 3> corners = layer_lattice.cell_corners(cell);
    Polygon triangle;
    // ... build triangle polygon from corners ...
    ExPolygons inset = offset_ex(triangle, -scale_(half_line_width));
    ExPolygons clipped = intersection_ex(inset, zone_regions);
    double area = 0.0;
    for (const ExPolygon &ep : clipped)
        area += std::abs(ep.area());
    if (area < min_area_scaled2)
        continue;  // Too constricted for injection flow
    m_cells[cell].mark_present(layer_id, area);
}
```

Interior cells (center inside the inset region by half the interior width) use the precomputed ideal cell area, avoiding polygon clipping entirely. Boundary cells undergo exact polygon intersection to determine their actual usable area. A cell is admitted on a layer only if that area is at least **70%** of the ideal cell area AND the injection point retains at least the nozzle-flat radius of clearance to the nearest opening boundary (the dual presence gate of claim 14): the area term rejects cells too clipped to hold a useful tube, while the clearance term rejects spikes or pinches intruding toward the injection point that the area term alone would pass. Injection volume is then computed from each layer's actual clipped area, so an admitted partial cell is dosed proportionally.

### 3.g Adaptive Layer Height Support

The system uses millimeter-based tube boundaries rather than fixed layer counts, enabling correct operation with variable layer heights (adaptive slicing). Per-layer heights are stored from the Layer objects (in `m_layer_data` indexed by layer ID, containing `print_z`, `height`, and the pre-built `lattice` for that layer), and all height comparisons operate in millimeters rather than layer counts. A helper function `span_height_mm()` computes the physical height of any layer range using these tables.

**Historical note:** The `assign_default_tubes()` function originally performed mm-based boundary placement using `fmod` alignment and per-layer height accumulation. This function was replaced by the two-stage solver (Section 5), which uses integer micron arithmetic for boundary placement. The mm-based boundary concept is preserved in the solver's `MicronTables` (Section 5.a), but the implementation path changed.

Tube boundaries are placed at mm-based grid lines, with boundary crossings detected via accumulated layer heights:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — (historical: assign_default_tubes)

// How far into the current tube_h_mm period is span_bottom_z?
double into_period = std::fmod(span_bottom_z - stagger_offset_mm, tube_h_mm);
if (into_period < 0) into_period += tube_h_mm;
double first_target_mm = tube_h_mm - into_period;
if (first_target_mm < 1e-6) first_target_mm += tube_h_mm;

// Walk layers accumulating height to find boundary crossings
double accum = 0.0;
double target = first_target_mm;
for (int i = span.start; i <= span.end; ++i) {
    accum += m_layer_heights[i];
    if (accum >= target - 1e-6 && i < span.end) {
        boundaries.push_back(i + 1);
        target += tube_h_mm;
    }
}
```

---

## 4. IMPLEMENTED SYSTEM -- Tube Assignment

**Implementation status: IMPLEMENTED and tested in software.**

**Historical note:** The deterministic pairing and salvage assignment described below were the original tube assignment algorithms. They have been superseded by the two-stage solver described in Section 5 (greedy warm start + CP-SAT refinement). The algorithms are disclosed here for completeness and prior art.

### 4.a Default Deterministic Pairing

Default tube pairing iterates only up-triangles (sum=2), evaluating all three down-triangle neighbors and selecting the partner with the greatest total shared height in millimeters. The best-partner selection ensures optimal coverage at sloped boundaries where the default a-axis partner may only exist for a fraction of the cell's height:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — assign_default_tubes()

// Only iterate up triangles -- each up-down pair considered once.
for (const auto &[cell, presence] : m_cells) {
    if (!cell.is_up())
        continue;

    // Try all 3 DN neighbors, pick the one with the longest total shared span.
    auto neighbors = cell.neighbors();
    TriangleCell best_partner;
    double best_total_shared_mm = 0.0;

    for (const TriangleCell &neighbor : neighbors) {
        auto nit = m_cells.find(neighbor);
        if (nit == m_cells.end())
            continue;

        std::vector<SharedSpan> nspans = find_shared_spans(presence, nit->second);
        double total_mm = 0.0;
        for (const SharedSpan &s : nspans)
            total_mm += span_height_mm(s.start, s.end);

        if (total_mm > best_total_shared_mm) {
            best_total_shared_mm = total_mm;
            best_partner = neighbor;
            // ...
        }
    }
    // ... create tube pairs for best partner ...
}
```

### 4.b Algebraic Shared Edge Detection

The shared edge between two adjacent triangle cells is determined algebraically from their (a,b,c) coordinates. Since neighbors differ in exactly one coordinate, the differing coordinate identifies the edge type:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.hpp

enum class SharedEdge { Horizontal, Col60, Diag120 };

inline SharedEdge shared_edge(const TriangleCell &a, const TriangleCell &b) {
    if (a.a != b.a) return SharedEdge::Col60;       // differ in a -> 60 degree edge
    if (a.b != b.b) return SharedEdge::Horizontal;   // differ in b -> horizontal edge
    return SharedEdge::Diag120;                       // differ in c -> 120 degree edge
}
```

This O(1) computation eliminates geometric edge-finding. The shared edge type determines which line family (horizontal, 60-degree, or 120-degree) the window gap appears on, and the exact lattice vertices bounding the shared edge.

### 4.c Tube Height Grid Placement with Short Segment Merging

Tube boundaries are placed at mm-based grid lines aligned with the stagger offset. After boundary placement, short leading and trailing segments are merged into their neighbors to prevent tubes that are too short for structural utility:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — assign_default_tubes()

// Merge short first/last segments into their neighbors (mm-based check)
while (boundaries.size() >= 3) {
    double first_seg_h = span_height_mm(boundaries[0], boundaries[1] - 1);
    if (first_seg_h >= m_min_tube_height_mm)
        break;
    boundaries.erase(boundaries.begin() + 1);
}
while (boundaries.size() >= 3) {
    double last_seg_h = span_height_mm(
        boundaries[boundaries.size() - 2], boundaries.back() - 1);
    if (last_seg_h >= m_min_tube_height_mm)
        break;
    boundaries.erase(boundaries.end() - 2);
}
```

The minimum tube height is structurally derived: `window_height_mm * 2 + 2 * min_layer_height` in millimeters, ensuring sufficient solid wall material above and below each window for structural integrity.

### 4.d Uncovered Layer Range Detection

For salvage tube assignment, the system computes which layers of a cell are NOT covered by existing tube pairs:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp

static CellPresence uncovered_presence(
    const CellPresence &presence,
    const std::vector<int> &pair_indices,
    const std::vector<UTubePair> &pairs)
{
    if (pair_indices.empty())
        return presence;

    CellPresence result;
    for (int layer = presence.first_layer; layer <= presence.last_layer; ++layer) {
        if (!presence.present(layer))
            continue;

        bool covered = false;
        for (int idx : pair_indices) {
            const UTubePair &p = pairs[idx];
            if (layer >= p.pair_start_layer && layer <= p.pair_end_layer) {
                covered = true;
                break;
            }
        }

        if (!covered)
            result.mark_present(layer, presence.area(layer));
    }

    return result;
}
```

This enables cells that are partially covered by default tubes to have their uncovered ranges assigned to salvage tubes, maximizing reinforcement coverage.

### 4.e Greedy Salvage Tube Recovery

Salvage tube assignment maximizes shared uncovered height between a cell and its neighbors. It processes candidates sorted by first layer (bottom-up), evaluating all three neighbors for each unassigned or partially-uncovered cell:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — assign_salvage_tubes()

for (const TriangleCell &cell : candidates) {
    // Get this cell's uncovered layers
    CellPresence cell_uncovered = uncovered_presence(presence, cell_pairs, m_pairs);
    if (cell_uncovered.first_layer > cell_uncovered.last_layer)
        continue;  // Fully covered

    // Try all 3 neighbors, prefer longest shared uncovered height (in mm)
    TriangleCell best_partner;
    double best_height_mm = 0.0;
    SharedSpan best_span{-1, -1};

    for (const TriangleCell &neighbor : cell.neighbors()) {
        auto nit = m_cells.find(neighbor);
        if (nit == m_cells.end())
            continue;

        CellPresence nbr_uncovered = uncovered_presence(
            neighbor_presence, nbr_pairs, m_pairs);
        std::vector<SharedSpan> spans = find_shared_spans(
            cell_uncovered, nbr_uncovered);

        for (const SharedSpan &span : spans) {
            double h_mm = span_height_mm(span.start, span.end);
            if (h_mm >= m_min_tube_height_mm && h_mm > best_height_mm) {
                best_partner = neighbor;
                best_height_mm = h_mm;
                best_span = span;
            }
        }
    }

    if (best_height_mm > 0) {
        UTubePair pair;
        pair.cell_a = cell;
        pair.cell_b = best_partner;
        pair.pair_start_layer = best_span.start;
        pair.pair_end_layer = std::min(
            layer_at_height_from(best_span.start, m_max_tube_height_mm),
            best_span.end);
        pair.is_salvaged = true;
        // ... register pair ...
    }
}
```

Salvage tubes are marked with `is_salvaged = true` to distinguish them from default deterministic pairs. Cells with no viable partner are marked as solid fill (empty pair index vector).

### 4.f Per-Layer Tube Volume Computation

Tube volume is computed by accumulating per-layer cell areas (in scaled squared units) multiplied by per-layer heights, then adding window gap volume and subtracting triangle vertex overlap excess:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — compute_volumes()

for (UTubePair &pair : m_pairs) {
    double tube_volume_scaled2_mm = 0.0;
    double window_height_mm = 0.0;
    double overlap_excess_volume = 0.0;

    for (int layer_id = pair.pair_start_layer; layer_id <= pair.pair_end_layer;
         ++layer_id) {
        double area_a = /* cell_a area at layer_id */;
        double area_b = /* cell_b area at layer_id */;
        double lh = /* layer height at layer_id */;

        tube_volume_scaled2_mm += (area_a + area_b) * lh;

        // Accumulate window height using mm-based Z check
        if (m_layer_data[layer_id].bottom_z() < pair.window_end_z)
            window_height_mm += lh;

        // Per-layer overlap excess: 2 cells per pair
        overlap_excess_volume += excess_area_per_cell_mm2 * 2.0 * lh;
    }

    double tube_volume = tube_volume_scaled2_mm * SCALING_FACTOR * SCALING_FACTOR;
    double window_volume = inset_side * m_line_width * window_height_mm;
    double orig_volume = tube_volume + window_volume;
    pair.volume_mm3 = std::max(0.0, orig_volume - overlap_excess_volume);
}
```

The window gap volume uses the inset side length (not the full edge) since interiors are smaller than the outer triangle. Window layer membership is checked via mm-based Z comparison (`bottom_z() < pair.window_end_z`) rather than layer counts, ensuring correct behavior with variable layer heights. The overlap excess subtraction accounts for triangle vertex overlap regions where 3 line families cross at 60 degrees, depositing material twice -- this excess physically occupies tube interior space, so injection volume is reduced accordingly.

---

## 5. IMPLEMENTED SYSTEM -- Optimized Tube Assignment (Two-Stage Solver)

**Implementation status: IMPLEMENTED and tested in software.**

The default deterministic pairing (Section 4) is superseded by an optimized two-stage solver that significantly improves coverage and structural quality. The system operates in two modes: **Basic** (Stage 1 only, ~100-500ms) and **Refined** (Stage 1 + Stage 2, minutes).

```
MagmaTubeSolver::solve()
  build_micron_tables()     — layer boundaries in integer microns
  build_edges()             — adjacent cell pairs, shared presence runs
  greedy_warm_start()       — fast heuristic, populates m_committed
  validate("GREEDY")        — check constraints, log coverage
  if (Refined mode) {
    for each Z level:
      solve_pass()          — CP-SAT reads m_committed as warm start
    validate("CPSAT")       — check constraints, log coverage
  }
  extract_results()         — microns → UTubePair layer indices
  validate("FINAL")         — final constraint check + coverage summary
```

### 5.a Integer Micron Representation

All tube boundary positions are stored as 64-bit integer microns (µm), eliminating floating-point comparison errors in the constraint solver. Pre-computed once per object:

```cpp
// src/libslic3r/Magma/MagmaTubeSolver.cpp

top_um[L]    = llround(print_z * 1000)     // authoritative layer top
bottom_um[0] = llround(bottom_z * 1000)    // first layer bottom
bottom_um[L] = top_um[L-1]                 // exactly contiguous (no gap)
```

Since `bottom_um[L+1] == top_um[L]`, all layer boundaries form a single sorted sequence. This property is exploited for discrete domain construction.

### 5.b Stage 1: Greedy Warm Start (Most-Constrained-First Heuristic)

A fast deterministic heuristic that assigns tubes using a priority queue ordered by constraint tightness. Runs in 100-500ms for models with 1000+ cells.

```cpp
// src/libslic3r/Magma/MagmaGreedyWarmStart.cpp

void greedy_warm_start(
    const unordered_map<TriangleCell, CellPresence> &cells,
    const vector<EdgeData> &edges,
    const unordered_map<TriangleCell, vector<size_t>> &cell_edges,
    const MicronTables &um,
    int64_t min_h_um, int64_t max_h_um,
    vector<vector<CommittedSegment>> &committed);
```

**Scoring:** For each unconsumed cell×layer, the score equals the sum of achievable tube heights across all unconsumed neighbors. Lower score = fewer/shorter options = more constrained. This naturally prioritizes boundary cells (1 neighbor, low score) over interior cells (3 neighbors, high score), preventing stranding.

**Assignment:** Pop the most constrained cell×layer from a min-heap. Find its most constrained neighbor (fewest unconsumed layers in their shared run at this Z). Expand the longest valid tube between them, respecting min/max height bounds, consumed intervals, and run boundaries. Mark consumed on both cells.

**Periodic re-scoring:** After every `max(200, num_edges/3)` assignments, rebuild the heap from scratch with fresh consumed state. As tubes are assigned, heap ordering becomes stale — cells that became more constrained due to neighbor consumption need re-prioritization. The floor of 200 prevents churn on small models. Typically triggers 3-10 re-scores per model.

**Data structures:**
- `CellConsumed`: sorted non-overlapping micron intervals per cell with binary search overlap checking and insert-merge for additions. O(log n) per operation.
- `CellLayerScore`: min-heap entry with cell, layer, micron boundaries, and score.

**Key properties:**
- Deterministic (no random choices) for reproducible slicing
- Most-constrained-first prevents stranding of boundary cells
- Longest-tube preference maximizes coverage per assignment
- Natural stagger: the priority ordering inherently spreads tube boundaries across Z levels without explicit stagger constraints

### 5.c Stage 2: CP-SAT Refinement (Constraint Programming)

Optional second stage using Google's CP-SAT (Constraint Programming with Satisfiability) solver from OR-Tools. Starts from the greedy solution and locally improves coverage while avoiding weak planes. Typically adds 3-7% absolute coverage.

**Variables** (per segment slot on each edge):
```cpp
active   : BoolVar              — is this segment used?
start    : IntVar               — tube bottom in microns (discrete domain)
end      : IntVar               — tube top in microns (discrete domain)
size     : IntVar               — tube height in microns (discrete domain)
interval : OptionalIntervalVar(start, size, end, active)
```

**Discrete domains from layer boundaries:** All micron-space variables use `Domain::FromValues()` with the actual layer boundary positions, rather than continuous ranges. Since each boundary is both the end of one layer and the start of the next, a unified boundary list per edge run is computed:

```cpp
// Unified boundary list: one value at each layer interface
std::vector<int64_t> boundaries;
boundaries.push_back(bottom_um[eff_start]);
for (int L = eff_start; L <= eff_end; ++L)
    boundaries.push_back(top_um[L]);

// Feasible sizes: all achievable boundary-to-boundary heights within bounds
std::set<int64_t> size_set;
for (size_t i = 0; i < boundaries.size(); ++i)
    for (size_t j = i + 1; j < boundaries.size(); ++j) {
        int64_t s = boundaries[j] - boundaries[i];
        if (s > max_h_um) break;
        if (s >= min_h_um) size_set.insert(s);
    }
```

This dramatically tightens the LP relaxation (the solver's internal linear programming bound), improving solve quality by 10-30% compared to continuous ranges. The feasible-differences domain for size/contribution variables prevents the LP from considering non-achievable heights.

**Constraints:**
1. **NoOverlap per cell** — all segment intervals on a cell (active + frozen from other blocks) cannot overlap in Z.
2. **Height bounds** — encoded in the discrete size domain [min_h_um, max_h_um].
3. **Segment ordering** — symmetry breaking: segment k is active only if k-1 is active, and starts after k-1 ends.

**Objective function:**
```
Maximize:
    (W_COVERAGE + W_LENGTH) × Σ{ size × active }    — coverage + length tiebreaker
  - W_STAGGER_TIGHT × Σ{ tight_capacity_per_cell }   — very close boundaries
  - W_STAGGER_WIDE  × Σ{ wide_capacity_per_cell }    — moderate clustering
```

| Weight | Value | Purpose |
|--------|-------|---------|
| W_COVERAGE | 1,000,000 | 1µm of coverage vastly outweighs all stagger penalty |
| W_LENGTH | 1 | Tiebreaker: prefer fewer, longer tubes |
| W_STAGGER_TIGHT | 2 | Penalize boundaries within dodge/2 of neighbors |
| W_STAGGER_WIDE | 1 | Penalize boundaries within full dodge distance |

### 5.d Weak Plane Avoidance (Stagger Penalty)

When tube boundaries on nearby cells cluster at the same Z height, they create a horizontal "weak plane" — a layer with reduced reinforcement continuity. The stagger penalty discourages this using cumulative scheduling constraints.

For each cell, two `AddCumulative` constraints (tight + wide scale) measure peak boundary concentration in the cell's Ring-0 + Ring-1 neighborhood:

- **Ring-0** (cell's own edges): each tube boundary creates an interval with demand = 2
- **Ring-1** (neighbor's edges): each tube boundary creates an interval with demand = 1
- **Capacity**: soft IntVar with domain [0, 10000] — the capped upper bound prevents LP overestimation that would bias the solver toward stagger at the expense of coverage

Zone interval widths derive from the configurable dodge distance (default: `4 × max_layer_height`). When dodge is 0 or very small, the entire stagger section is skipped.

### 5.e Warm Start from Greedy Solution

Committed segments from the greedy stage become CP-SAT warm start hints:
- Segments fully inside a block's Z range → `SolutionHint(active=1, start, end, size)`
- Segments extending outside the block's Z range → frozen as fixed intervals in the NoOverlap constraint (not optimizable, but prevent conflicts)
- Segments from edges crossing block XY boundaries → frozen on the in-block cell

The warm start gives CP-SAT a complete initial solution, dramatically reducing search time compared to starting from scratch.

### 5.f Spatial Block Partitioning

The model is spatially partitioned into independent blocks for bounded computation:

- **XY partitioning:** R=16 cells per block side, a single XY pass per Z level. Adjacent blocks overlap by R_OVERLAP=2 cells (stride = R − R_OVERLAP), so every edge is interior to at least one block.
- **Z partitioning:** Window = 4 × max_h_layers, stride = 2 × max_h_layers (50% overlap). Every tube is fully visible in at least one Z window.
- **Z range trimming:** Loop terminates at the maximum layer with any edge activity, not the model's total layer count (skips empty upper Z levels).
- **Edge collection:** Uses cell reverse lookup (`m_cell_edges`) instead of scanning all edges — O(block cells × edges per cell) instead of O(total edges).

### 5.g Parallelism and Cancellation

- **Block scheduling:** Blocks are solved sequentially (not in parallel across blocks).
- **CP-SAT workers per block:** all available cores (`tbb::this_task_arena::max_concurrency()`) — the parallelism lives *inside* each block's CP-SAT solve rather than across blocks.
- **Cancellation:** Checked between passes via `throw_if_canceled()` (OrcaSlicer's standard pattern). Current blocks finish their timeout before cancellation takes effect.
- **Progress:** Reports "Magma: refining tubes X/Y" via OrcaSlicer's status callback.

### 5.h Validation Framework

Reusable `validate_committed()` function checks all constraints on committed segments. Called after each stage (GREEDY, CPSAT, FINAL):

1. **Layer range** — start/end within model bounds
2. **Height bounds** — tube height within [min_h, max_h] ± 0.01mm tolerance
3. **Edge validity** — both cells are neighbors
4. **Cell presence** — both cells present at every layer in the tube
5. **Per-cell NoOverlap** — no two tubes on the same cell overlap in Z
6. **Per-edge NoOverlap** — no two segments on the same edge overlap
7. **Coverage summary** — overall %, cells unfilled, cells <25%, cells <50%

### 5.i Performance

| Model | Cells | Greedy | +CP-SAT (10s) | +CP-SAT (20s) |
|-------|-------|--------|---------------|---------------|
| 20mm cube | 71 | 80.6% / 4ms | 90.6% / ~80s | — |
| Stanford bunny | 1056 | 76.5% / 503ms | 79.0% / ~197s | 80.5% / ~589s |

The greedy stage alone provides excellent coverage for quick iteration. CP-SAT refinement adds 3-7% coverage at significant time cost — best for final production slicing.

---

## 6. IMPLEMENTED SYSTEM -- Window System

**Implementation status: IMPLEMENTED and tested in software.**

### 5.a Auto Window Height from Cross-Section Geometry

Window height is automatically calculated in mm to match the tube cross-section area to the window opening area, ensuring adequate flow between paired cells:

```cpp
// src/libslic3r/Magma/MagmaTriangleCell.cpp

static double calculate_auto_window_height_mm(double interior_width, double line_width)
{
    double cell_spacing = cell_spacing_from_geometry(interior_width, line_width);
    double tube_area = inset_triangle_area(cell_spacing, line_width);
    double side = triangle_side_length(cell_spacing);
    double inset_side = side - line_width * SQRT3;
    if (inset_side <= 0)
        return 0.1;
    // Geometric height: window cross-section equals tube interior (caller adds 1 layer)
    double window_height_mm = tube_area / inset_side;
    return std::max(0.1, window_height_mm);
}
```

The formula `tube_area / inset_side` derives from equating the tube interior cross-section area (the inset triangle area after accounting for line width eating into the interior) with the window opening area (`inset_side * window_height`), where `inset_side = side - line_width * sqrt(3)` is the gap length between two adjacent inset triangle interiors along the shared edge. The caller (`from_config`) then adds one layer height to this geometric value so the window reliably spans a full printed layer despite layer-registration accuracy. The result is in mm (not layers), supporting variable layer heights directly.

### 5.b Window Gap Interval Merging

Window gaps are organized by line family (horizontal, 60-degree, 120-degree). Each line family uses a map from line index to sorted, merged intervals of world-coordinate ranges where lines should be interrupted:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.hpp

struct WindowGaps {
    double cell_spacing;
    double offset_x, offset_y;

    std::map<int, std::vector<std::pair<double, double>>> horiz;
    std::map<int, std::vector<std::pair<double, double>>> col60;
    std::map<int, std::vector<std::pair<double, double>>> diag120;
};
```

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — window_gaps()

// Sort and merge intervals per line index
for (auto &[key, intervals] : result.horiz)
    merge_intervals(intervals);
for (auto &[key, intervals] : result.col60)
    merge_intervals(intervals);
for (auto &[key, intervals] : result.diag120)
    merge_intervals(intervals);
```

The merge function combines overlapping or adjacent intervals (within 0.01mm tolerance) into a single interval, preventing double-gap artifacts when multiple tube pairs share the same line segment.

### 5.c Line Generation with Built-In Gaps

Window gaps are subtracted during line generation, not clipped after the fact. This is more efficient than generating full lines and then clipping, and avoids numerical issues with post-hoc line splitting:

```cpp
// src/libslic3r/Fill/FillMagma.cpp — _fill_surface_single()

// Horizontal lines with gaps built in
for (int b = row_min; b <= row_max; ++b) {
    coord_t y_s = coord_t(scale_(b * cs + off_y));

    auto it = gaps.horiz.find(b);
    if (it == gaps.horiz.end()) {
        all_lines.push_back(make_horiz_segment(x_min, x_max, y_s));
    } else {
        subtract_gaps(x_min, x_max, it->second, [&](double lo, double hi) {
            all_lines.push_back(make_horiz_segment(lo, hi, y_s));
        });
    }
}
```

The `subtract_gaps` template function walks sorted gap intervals, emitting kept segments between gaps:

```cpp
// src/libslic3r/Fill/FillMagma.cpp

template<typename EmitFn>
static void subtract_gaps(double lo, double hi,
                          const std::vector<std::pair<double, double>> &gaps,
                          EmitFn emit)
{
    double cursor = lo;
    for (const auto &gap : gaps) {
        double gl = std::max(gap.first, lo);
        double gr = std::min(gap.second, hi);
        if (gr <= gl)
            continue;
        if (gl > cursor + 0.01)
            emit(cursor, gl);
        cursor = std::max(cursor, gr);
    }
    if (hi > cursor + 0.01)
        emit(cursor, hi);
}
```

### 5.d Parametric Y-Gap Splitting for Diagonal Lines

For 60-degree and 120-degree lines, window gaps are specified as Y-coordinate intervals. Since these lines are not horizontal, the Y intervals must be converted to parametric positions along the line segment:

```cpp
// src/libslic3r/Fill/FillMagma.cpp

static void split_line_by_y_gaps(
    const Vec2d &p0, const Vec2d &p1,
    const std::vector<std::pair<double, double>> &y_gaps,
    Polylines &out)
{
    double dy = p1.y() - p0.y();

    // Convert Y intervals to parametric t values along p0->p1
    auto y_to_t = [&](double y) { return (y - p0.y()) / dy; };
    auto t_to_point = [&](double t) -> Vec2d {
        return Vec2d(p0.x() + t * (p1.x() - p0.x()),
                     p0.y() + t * dy);
    };

    std::vector<std::pair<double, double>> t_gaps;
    for (const auto &gap : y_gaps) {
        double gl = std::max(gap.first, y_lo);
        double gr = std::min(gap.second, y_hi);
        if (gr <= gl)
            continue;
        double t0 = y_to_t(gl);
        double t1 = y_to_t(gr);
        if (t0 > t1) std::swap(t0, t1);
        t_gaps.push_back({t0, t1});
    }

    std::sort(t_gaps.begin(), t_gaps.end());
    subtract_gaps(0.0, 1.0, t_gaps, [&](double t_lo, double t_hi) {
        Vec2d a = t_to_point(t_lo);
        Vec2d b = t_to_point(t_hi);
        // ... emit polyline segment ...
    });
}
```

The parametric conversion correctly handles both upward-sloping (60-degree) and downward-sloping (120-degree) lines by sorting t-values after conversion.

### 5.e Structural Minimum Validation

Tube height is clamped to a structural minimum ensuring sufficient solid wall material above and below each window. The minimum is now mm-based:

```cpp
// src/libslic3r/Magma/MagmaTubeMap.cpp — build()

m_min_tube_height_mm = m_window_spec.window_height_mm * 2.0
                       + 2.0 * double(m_min_layer_height);
```

The formula ensures: one window height of solid wall below the window, one window height of solid wall above the window, plus two minimum layers of padding. User-specified tube height is clamped to this minimum. Stagger is now handled by the CP-SAT solver's cumulative scheduling constraints (Section 5.d) rather than explicit stagger level clamping.

---

## 7. IMPLEMENTED SYSTEM -- Injection and G-code

**Implementation status: IMPLEMENTED and tested in software. The injection system generates working G-code; multi-material filament switching is fully wired but not yet tested on multi-material hardware.**

### 6.a Per-Layer Injection as Print Stage

Injection occurs as a dedicated print stage within each layer's processing, not as a post-print operation. The injection sequence for each layer:

1. Switch to injection filament if configured (using OrcaSlicer's existing tool change infrastructure)
2. Heat nozzle to injection temperature (with optional nozzle parking during heat-up)
3. For each injection point (in the layer's chosen order -- travel-optimal or heat-spread, see Section 6.h):
   a. Travel to injection cell center (built-in travel: retract/lift/avoid-crossing)
   b. Unretract
   c. Z-slam seal (lower nozzle to the seal depth, Section 6.c)
   d. Emit role and dimension tags for preview
   e. Emit tube visualization metadata
   f. Extrude calculated volume as segmented G1 commands, ramping the nozzle
      deeper between segments if plunge is enabled (Section 6.c)
   g. Dwell for air displacement
   h. Break-lift to crack the seal, then retract
   i. Crater ironing: spiral inward to plow the rim back and clean the nozzle (Section 6.d)
4. Cool nozzle back to printing temperature
5. Switch back to original print filament if needed

### 6.b Injection Speed and Volume

Injection volumetric speed is user-configured via `magma_injection_speed` (default 10 mm^3/s), capped at `filament_max_volumetric_speed`. Tube height is user-specified via `magma_tube_height` (default 4.5mm).

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp

double vol_speed = std::max(1.0, injection_speed_vol);
double max_vol = config.filament_max_volumetric_speed.get_at(extruder_id);
if (max_vol > 0)
    vol_speed = std::min(vol_speed, max_vol);
```

A coupled thermal-pressure model for automatic depth/speed calculation was designed, implemented, and tested but removed from the current release (see Section 9.e).

### 6.c Z-Slam Sealing

During stationary injection, the nozzle lowers into the surface to create a mechanical seal against the tube opening. This prevents plastic from escaping laterally during injection. The depth is configurable via `magma_injection_z_slam` (default 0.05mm), clamped to 3.5mm with a UI warning for large values. Set to 0 to disable.

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp (simplified)

double slam_depth = std::min(config.magma_injection_z_slam.value, 3.5);

// Lower the nozzle into the surface to seal against the opening
if (slam_depth > 0) {
    sprintf(buf, "G1 Z%.3f F%d ; z-slam seal\n", layer_z - slam_depth, z_feedrate);
    gcode += buf;
}

// ... injection extrusion (optionally with progressive plunge) ...

// Finish: crack the seal *before* retracting, so retraction can't pull the
// freshly injected plug back up through the still-sealed interface. A small
// fixed break-lift relieves the contact pressure regardless of plunge depth;
// the crater-iron wipe (Section 6.d) then returns the nozzle to layer height.
sprintf(buf, "G1 Z%.3f F%d ; injection break-lift\n",
        layer_z - slam_depth - plunge_depth + 0.3, z_feedrate);
gcode += buf;
if (inj_retract)
    gcode += gcodegen.writer().retract();
```

Small values (0.05mm) work with nozzles that have a wide flat tip. Nozzles with a narrow flat and tapered tip may need deeper values (0.5-1.0mm) so the taper widens enough to seal the tube opening. The slam/lift moves use the printer's Z travel speed (`travel_speed_z`, firmware-capped) rather than a hardcoded feedrate, so the nozzle does not linger on the hot tube top.

**Auto Z-slam depth from nozzle cone geometry.** Choosing this depth by hand requires reasoning about the nozzle's tip flat and the cone above it. When `magma_injection_z_slam_auto` is enabled, the depth is instead derived from geometry. A standard nozzle tip is a flat ring of diameter `flat` (the measured `magma_nozzle_outer_diameter`, "Nozzle tip flat") with a cone of half-angle `theta` (`magma_nozzle_cone_half_angle`, default 30 degrees) widening above it. To seal a tube opening of diameter `opening`, the nozzle must descend until the cone has widened from `flat` to `opening` plus a small seal margin (0.1mm, so the cone clears the opening rather than just grazing it and so the auto depth satisfies the seal-prediction check). Each unit of descent widens the cone by `2 * tan(theta)`, giving:

```
// src/libslic3r/Magma/MagmaInjection.cpp
double opening   = tube_map.tube_opening_diameter();          // inscribed opening of the inset triangle
double flat      = nozzle_flat > 0 ? nozzle_flat : 3.0 * nozzle_diameter;
double theta_rad = magma_nozzle_cone_half_angle * PI / 180.0;
double slam_depth = std::max(0.1, (opening + 0.1 - flat) / (2.0 * std::tan(theta_rad)));  // +0.1mm seal margin
slam_depth = std::min(slam_depth, 3.5);                       // shared clamp
```

When the flat already covers the opening with margin (`flat >= opening + margin`) the numerator is non-positive and the depth floors at a minimal 0.1mm press for a clean seal. A pointier cone (smaller `theta`) requires a deeper slam for the same opening; a wider flat requires less. This makes the seal depth track tube size and nozzle automatically, and is what allows tubes intentionally sized larger than the flat (Manual tube width) to still seal. When auto mode is on, the manual `magma_injection_z_slam` field is ignored (and hidden in the UI).

**Progressive plunge ("slam-melt").** A single fixed seal depth can fail mid-injection: as channel pressure rises, plastic finds the lateral gap at the seal and mushrooms out around the nozzle instead of flowing down the tube. The plunge ramps the nozzle deeper *while injecting* — the extrusion is split into segments and the Z is stepped down between them from `slam_depth` to `slam_depth + plunge_depth` over the course of the injection, so the hot tip keeps sinking into the softening tube top and holds the seal shut as it fills:

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp -- per extrusion segment k of K
double z = layer_z - (slam_depth + plunge_depth * (k + 1) / K);
// emit: G1 Z<z>           (sink the nozzle)
//       G1 F<inj_feed>    (re-assert injection feedrate; the Z move's feedrate
//                          must not leak into the stationary extrude)
//       G1 X.. Y.. E<seg> (extrude this segment at the injection rate)
```

The volumetric injection rate is held constant across the plunge (re-asserted after each Z move, since a raw Z move's feedrate is otherwise sticky). The total depth is clamped so `slam + plunge` stays within a safe intrusion.

### 6.d Crater Ironing

Pressing a round/conical nozzle into a triangular tube opening necessarily displaces material into a raised rim around a central crater (the seal/plunge intrusion), and coats the nozzle in plastic that would otherwise string to the next injection. Crater ironing is a finishing move after each injection that redistributes the rim back into the crater and cleans the nozzle in one motion.

The sequence: (1) a small fixed **break-lift** cracks the seal *before* retracting (so retraction can't pull the plug back up through the still-sealed interface); (2) retract; (3) an **inward spiral** over the injection centre.

The key mechanism is using the **nozzle cone as a plow**: with the flat hovering just above layer height and the nozzle positioned outside the rim, the cone's flank — whose outward normal points `(cos theta, -sin theta)` = inward and *downward* — deflects rim material toward the centre and down into the crater as the nozzle spirals in. A flat vertical edge would only push laterally; the cone's angle is what fills the depression.

```
crater_r = r_flat + (slam + plunge) * tan(theta)          # intrusion footprint radius
start_R  = crater_r + margin                              # begin spiral outside the rim
# Neighbour protection: only PRESS (descend to layer height) inside the radius
# where the flat's outer edge stays >= 0.5 mm short of a neighbour opening's far
# vertex, so a sliver of every neighbour air hole stays open:
D    = neighbour-centroid distance  (= cell_side / sqrt(3) for the triangle grid)
Ropen= neighbour opening vertex radius (inset triangle -- excludes cell walls)
cap  = (D + Ropen) - 0.5 - r_flat
# spiral radius r: shrink start_R -> 0 over `turns` revolutions
#   r > cap  -> hover at layer_top + hover      (never irons a neighbour shut)
#   r <= cap -> descend hover -> layer_top      (press/iron our own crater)
```

A short stroke across the centre flattens the gathered mound (only where `cap > 0`, i.e. the cell has room). The whole pass is non-extruding; the retraction performed at the break-lift keeps it from oozing. Inter-injection travel afterwards uses the slicer's normal travel path (retraction, z-hop, avoid-crossing). Tunable: turns (cut depth), speed, hover height, and start margin; start radius, neighbour clearance, and the descent profile are derived from the cell and nozzle geometry.

### 6.e Multi-Material Injection Filament Switching

The system supports a dedicated injection filament via `magma_injection_filament`, following OrcaSlicer's existing `support_filament` pattern. This enables using a different material for injection (e.g., a higher-temperature material for stronger reinforcement).

Filament switching is handled upstream by `ToolOrdering`, which registers the injection filament extruder on layers that have tube caps (injection points). The injection code itself does not perform tool changes -- by the time `generate_injection_gcode()` runs, the current extruder is already the injection filament:

```cpp
// src/libslic3r/GCode/ToolOrdering.cpp

// Magma injection filament: register on cap layers so ToolOrdering
// schedules the tool change and wipe tower handles the transition.
if (object.config().magma_injection_filament.value > 0) {
    if (const auto* tube_map = object.magma_tube_map()) {
        unsigned int inj_ext = (unsigned int)object.config().magma_injection_filament.value;
        for (int lid : tube_map->injection_layer_ids()) {
            LayerTools &lt = this->tools_for_layer(object.layers()[lid]->print_z);
            lt.extruders.push_back(inj_ext);
        }
    }
}
```

The configuration parameter uses 1-based indexing (0 = current filament, 1 = filament 1, etc.) matching the `support_filament` convention. The implementation is fully wired through config definitions (`PrintConfig.hpp`), UI (`Tab.cpp`, `ConfigManipulation.cpp`), preset serialization (`Preset.cpp`), and extruder collection (`Print.cpp`). Multi-material hardware testing has not been performed at time of publication, but code review confirms correct integration with the tool change system.

### 6.f Segmented Injection Extrusion

Injection volume is split into per-waypoint G1 E commands proportional to the 3D path segment length. This enables the preview slider to show progressive tube filling:

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp

double filament_length = volume * e_per_mm3;

if (waypoints.size() >= 2) {
    double total_path_len = 0;
    for (size_t i = 1; i < waypoints.size(); ++i)
        total_path_len += (waypoints[i] - waypoints[i - 1]).norm();

    for (size_t i = 1; i < waypoints.size(); ++i) {
        double seg_len = (waypoints[i] - waypoints[i - 1]).norm();
        double seg_e = (total_path_len > 0)
            ? filament_length * (seg_len / total_path_len)
            : filament_length / double(waypoints.size() - 1);
        gcode += gcodegen.writer().extrude_to_xy(
            xy, seg_e, "injection segment");
    }
}
```

Each G1 command receives a proportional share of the total extrusion amount, weighted by the 3D distance between consecutive waypoints along the U-tube path. This produces multiple G-code lines for a single stationary injection, each with its own slider position in the preview, enabling visual progressive fill animation.

### 6.g Auto-Sizing

Interior width and window height are automatically calculated from the nozzle geometry:

```cpp
// src/libslic3r/Magma/MagmaTriangleCell.cpp

double calculate_auto_interior_width(double nozzle_diameter)
{
    // Fallback when nozzle outer diameter is not specified.
    // Uses 3.0x bore as a conservative default.
    return nozzle_diameter * 3.0;
}
```

When the nozzle outer diameter is known, `calculate_auto_interior_width_from_od()` computes the largest inset triangle that fits within the nozzle shoulder circle. It uses circumscribed circle geometry: for an equilateral triangle with side `s`, the circumscribed diameter is `2s / sqrt(3)`. Setting this equal to `nozzle_od` and solving for the interior width sizes the tube opening so all three vertices are covered by the nozzle flat during z-slam injection (report a slightly conservative flat to build in a sealing margin).

Window height is auto-calculated from `tube_area / inset_side` (plus one layer height) where `inset_side = side - line_width * sqrt(3)`. This equates the window opening cross-section to the tube interior cross-section, then adds one layer height so the window reliably spans a full printed layer. The minimum window height is 0.1mm.

### 6.h Heat-Spread Injection Ordering

When two spatially-adjacent tubes are injected back-to-back, their combined heat can re-melt the thin wall between them and break the seal. The order in which injections are visited on a layer is selectable via `magma_injection_ordering`:

- **Minimize travel** -- the shortest nozzle path, computed by the existing KD-tree nearest-neighbour tour (`chain_points()`). This is the default.
- **Spread heat** -- a thermal-aware order that deliberately separates spatially-near injections in time.

The ordering is computed **globally per print layer**: all injection points from every object and every instance that fall on the same layer Z are collected and ordered together. A per-object order would be defeated on a plate of small parts, where each part's tubes would still be injected as a tight cluster. Because injection happens as the last operation on a layer, the global set is well-defined at that point.

The order is solved once, ahead of G-code generation, in a dedicated slicing stage (`psMagmaInjectionOrder`) and cached by layer Z (the same merged-`print_z` bucketing OrcaSlicer uses for its per-layer tool ordering), so G-code export performs a lookup rather than a solve.

**Decay model.** The objective is to keep spatially-near injections far apart in *real time*. Each prior injection is treated as a heat source that fades with both elapsed time and distance, so the residual heat a candidate point sees is

```
heat(candidate) = sum over already-injected i of
                    exp(-dt_i / tau) * exp(-dist(candidate, i) / lambda)
```

where `dt_i` is the real elapsed injection time since `i` was injected, `lambda` ~ the median nearest-neighbour spacing (heat couples only to the immediate ring), and `tau` is derived from the layer's own pace (`tau = SEP_TARGET * median per-injection step time`, `SEP_TARGET ~ 8`) so the time scale self-adjusts. `dt` comes from a real injection-phase timing model -- travel distance / travel speed, plus per-injection extrude time (volume / volumetric rate), z-hops, and dwell -- so a longer hop to a distant cell *is* extra cooling, coupling travel and thermal separation instead of opposing them.

**Stage 1 -- time-decay dispersion greedy.** Maintain the residual-heat field over the not-yet-injected points. Starting from the travel-optimal tour's first point, repeatedly:
- pick the remaining point with the lowest heat *on arrival* -- `heat(c) * exp(-travel_time(cur,c)/tau)` plus a small travel tiebreak `beta * travel_time(cur,c)` so the nozzle prefers nearer cool spots;
- advance the clock by that step's real time and decay the whole field by `exp(-step_time/tau)`;
- deposit the new injection's spatial heat onto its neighbours.

This naturally round-robins across spatial clusters (e.g. instances on a multi-part plate) and stripes across a single dense lattice, while keeping travel bounded.

**Stage 2 -- violation-directed local-search polish.** Hill-climb on a rank-gap proxy of the objective: immediate-ring pairs visited fewer than `WINDOW = min(n, 8)` injections apart are "crowded". For each currently-crowded near pair, try swaps that increase its time separation; each swap's delta touches only the two moved points' neighbours, so it is O(degree). This dissolves residual clusters the greedy left behind -- including end-of-pass "painted-into-a-corner" leftovers -- converging to a local optimum.

The whole pipeline is deterministic and runs in O(n^2) (sub-millisecond per layer for typical counts) with no external solver dependency. Very large layers (above a few thousand simultaneous injections) fall back to travel-optimal order.

**Alternative formulation (implemented, measured, removed -- see git history).** The same objective was first expressed and solved *exactly* as a Hamiltonian-circuit (travelling-salesman) routing problem with an added time-gap heat penalty:

```
arc[i][j] in {0,1}  -- tour edge;   rank[i] in [0,n) -- visiting position (MTZ)
minimize  sum dist(i,j)*arc[i][j]                                   (travel)
        + sum over near pairs of  median_nn * w * max(0, WINDOW - |rank[i]-rank[j]|)   (heat)
```

solved with CP-SAT (OR-Tools), warm-started from the travel-optimal tour (so it is never worse than travel order), over a sparse arc set (each node's k-nearest neighbours plus the warm-start tour's edges, guaranteeing a feasible circuit exists), with a distance-tiered penalty (immediately-adjacent pairs weighted 2x) and a short per-layer time budget. This was benchmarked against the greedy+polish pipeline on the real decay objective: warm-started from the polished order it returned the *identical* order at a multi-second cost, so it was removed from the shipping path. It is disclosed here as prior art alongside the greedy method.

**Prior art scope.** This disclosure establishes prior art for ordering in-situ mid-print injection events by: (a) a global, cross-object, per-layer schedule rather than per-object; (b) a continuous decay field combining temporal *and* spatial decay so each past injection's thermal influence fades in both time and distance; (c) using *real elapsed injection time* (travel + extrude + z-hop + dwell) as the temporal axis, so inter-injection travel counts as cooling; (d) a dispersion greedy that selects the lowest-heat-on-arrival point with a travel tiebreak; (e) a violation-directed local search refining only currently-crowded near pairs; (f) the equivalent exact formulation as a travel-plus-heat-penalty Hamiltonian circuit solved by constraint programming, warm-started from the travel-optimal tour over a sparse candidate-edge set; and (g) caching the solved per-layer order in a dedicated slicing stage keyed by layer height.

---

## 8. IMPLEMENTED SYSTEM -- Preview and Visualization

**Implementation status: IMPLEMENTED and tested in software.**

### 7.a MAGMA_TUBE G-code Comment Protocol

Tube visualization data is embedded in G-code comments, preserving backward compatibility with G-code processors that do not understand the Magma extensions:

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp

static std::string format_tube_viz_comment(const std::vector<Vec3d>& waypoints,
                                            float width)
{
    std::ostringstream oss;
    oss << "; MAGMA_TUBE n=" << waypoints.size() << " w=" << width << " pts=";
    for (size_t i = 0; i < waypoints.size(); ++i) {
        if (i > 0) oss << ';';
        char buf[64];
        snprintf(buf, sizeof(buf), "%.3f,%.3f,%.3f",
                 waypoints[i].x(), waypoints[i].y(), waypoints[i].z());
        oss << buf;
    }
    oss << '\n';
    return oss.str();
}
```

Example output:
```
; MAGMA_TUBE n=5 w=0.60 pts=1.234,5.678,10.000;1.234,5.678,5.000;2.345,6.789,5.000;2.345,6.789,5.000;2.345,6.789,10.000
```

The GCodeProcessor parses these comments and expands the single stationary injection extrusion into synthetic vertices tracing the U-tube spiral path: descend through cell A, cross through the window into cell B, ascend through cell B. The sequential slider animates tube filling progressively.

### 7.b 3D Douglas-Peucker Simplification

The U-tube spiral path through 3D space is simplified using the Ramer-Douglas-Peucker algorithm (via libigl) to reduce the number of waypoints while preserving the helical shape:

```cpp
// src/libslic3r/Magma/MagmaInjection.cpp

static std::vector<Vec3d> build_tube_viz_waypoints(
    const MagmaTubeMap& tube_map,
    const UTubePair& pair,
    double layer_z,
    int window_center_layer)
{
    // ... build full_path tracing descent A -> window -> ascent B ...

    if (full_path.size() > 2) {
        Eigen::MatrixXd P(full_path.size(), 3);
        for (size_t i = 0; i < full_path.size(); ++i)
            P.row(i) = full_path[i].transpose();

        Eigen::MatrixXd S;
        Eigen::VectorXi J;
        igl::ramer_douglas_peucker(P, double(iw) * 0.1, S, J);

        std::vector<Vec3d> simplified;
        simplified.reserve(S.rows());
        for (int i = 0; i < S.rows(); ++i)
            simplified.push_back(S.row(i).transpose());
        return simplified;
    }
    return full_path;
}
```

The tolerance is set to `interior_width * 0.1`, meaning simplification preserves features larger than 10% of the tube diameter. When spirals are disabled, RDP typically reduces 20-120 points down to approximately 5 key points (top of A, bottom of A, window crossing, bottom of B, top of B). With spirals enabled, additional points are retained where the helix curvature is significant.

### 7.c erMagmaInjection Extrusion Role

A dedicated extrusion role `erMagmaInjection` is added to OrcaSlicer's role system:

```cpp
// src/libslic3r/ExtrusionEntity.hpp
erMagmaInjection,  // Magma injection extrusion role
```

This role is rendered in lava-orange color (RGB 255, 25, 0) in the G-code preview:

```cpp
// src/libvgcode/src/ViewerImpl.cpp
{ 255,  25,   0 }, // MagmaInjection - Molten Lava (brightest)
```

The dedicated role enables: distinct visual identification of injection extrusions in the preview, separate speed/flow settings for injection vs. normal printing, and correct classification of stationary extrusions (which would otherwise be classified as unretracts).

### 7.d Zone Boundary Surface Types

Three new surface types enable distinct rendering and per-zone settings:

```cpp
// src/libslic3r/Surface.hpp

// Dual infill zone surface types
stZoneOuter,    // Outer zone filled with Magma Triangle U-tube pattern
stZoneFloor,    // Zone floor - propagates solid upward into zone
stZoneCeiling,  // Zone ceiling - propagates solid downward into zone
```

With helper methods:

```cpp
bool is_zone_outer() const { return this->surface_type == stZoneOuter; }
bool is_zone_floor() const { return this->surface_type == stZoneFloor; }
bool is_zone_ceiling() const { return this->surface_type == stZoneCeiling; }
bool is_zone_boundary() const { return is_zone_floor() || is_zone_ceiling(); }
bool is_zone() const { return is_zone_outer() || is_zone_boundary(); }
```

Zone boundaries are treated as solid surfaces for shell propagation (top/bottom shells propagate through zone boundaries), bridge detection, and overhang support computation.

---

## 9. IMPLEMENTED SYSTEM -- Zone Boundary Generation

**Implementation status: IMPLEMENTED and tested in software.**

### 8.a SLA Hollowing Repurposed for FDM

The inner shell boundary is computed using OrcaSlicer's existing SLA `generate_interior()` function, which was originally designed to hollow SLA (resin) prints for material savings. The system wraps this function with custom zone-specific processing:

```cpp
// src/libslic3r/ZoneBoundary/ZoneInterior.hpp

// Regenerate mesh from grid after processing
void regenerate_mesh_from_grid(sla::Interior &interior);

// Apply constrained mean curvature smoothing
void smooth_interior(sla::Interior &interior, const TriangleMesh &original_mesh,
                     int iterations = 5);

// Filter thin sections via morphological reconstruction
void filter_thin_interior(sla::Interior &interior, double min_width);
```

The SLA hollowing function computes an interior mesh by offsetting the original mesh inward by a specified thickness, using OpenVDB level-set operations. This produces an inner shell mesh that follows the contours of the outer model at a consistent distance, forming the boundary between the outer zone (Magma infill) and the inner zone (standard infill or hollow).

### 8.b Constrained Mean Curvature Flow Smoothing

The inner shell boundary undergoes smoothing to reduce stair-step artifacts while maintaining minimum shell thickness:

```cpp
// src/libslic3r/ZoneBoundary/ZoneInterior.cpp

void smooth_interior(sla::Interior &interior, const TriangleMesh &original_mesh,
                     int iterations)
{
    // Create valid zone grid: original mesh offset inward by thickness
    double thickness_offset = interior.thickness;
    auto valid_zone_grid = redistance_grid(*original_grid, -thickness_offset,
                                           in_range, in_range);

    const int smooth_passes_per_clamp = 5;

    // Convergence detection via L1 energy
    auto compute_l1_energy = [&]() -> double {
        double energy = 0;
        for (auto iter = interior.gridptr->cbeginValueOn(); iter; ++iter)
            energy += std::abs(iter.getValue());
        return energy;
    };

    double prev_energy = compute_l1_energy();
    double prev_rel_change = 0;

    for (int i = 0; i < iterations; ++i) {
        openvdb::tools::LevelSetFilter<openvdb::FloatGrid> filter(*interior.gridptr);

        // Apply multiple smoothing passes before clamping
        for (int j = 0; j < smooth_passes_per_clamp; ++j) {
            filter.meanCurvature();
        }

        // Clamp to valid zone using CSG intersection (preserves both inputs)
        interior.gridptr = openvdb::tools::csgIntersectionCopy(
            *interior.gridptr, *valid_zone_grid);

        // Plateau detection
        double curr_energy = compute_l1_energy();
        double rel_change = (prev_energy > 0)
            ? std::abs(curr_energy - prev_energy) / prev_energy : 0;

        if (i > 0 && prev_rel_change > 0 && rel_change >= 0.5 * prev_rel_change) {
            break;  // Converged
        }

        prev_rel_change = rel_change;
        prev_energy = curr_energy;
    }
}
```

The algorithm works as follows:

1. A **valid zone grid** is created by offsetting the original mesh inward by the shell thickness. This grid represents the boundary that the interior surface must not cross (to maintain minimum shell thickness).

2. **Batched mean curvature passes** (5 per iteration) smooth stair-step artifacts. Mean curvature flow shrinks convex bumps inward, which is the desired direction (away from the shell zone).

3. **CSG intersection clamping** prevents the smoothed interior from expanding outward into the shell zone. This is applied after each batch of smooth passes.

4. **L1 energy convergence detection** measures the total absolute SDF values. When the relative change between iterations plateaus (the change rate stops decreasing), smoothing has reached equilibrium and further iterations are skipped.

The batching strategy (5 smooth passes before clamping) is more effective than alternating single passes because mean curvature primarily shrinks convex features inward, which the clamping constraint does not block. Batching allows more effective smoothing per CSG operation.

### 8.c Thin Section Filtering

Before smoothing, thin inner zone sections are removed using morphological reconstruction:

```cpp
// src/libslic3r/ZoneBoundary/ZoneInterior.cpp

void filter_thin_interior(sla::Interior &interior, double min_width)
{
    float threshold = float(min_width / 2.0 * interior.voxel_scale);
    int threshold_voxels = int(std::ceil(threshold));

    // 1. Extract thick core (SDF interior at threshold distance from boundary)
    auto thick_mask = openvdb::tools::sdfInteriorMask(
        *interior.gridptr, -threshold);

    // 2. Dilate mask back to reach original surface
    openvdb::tools::dilateActiveValues(thick_mask->tree(), threshold_voxels,
        openvdb::tools::NN_FACE_EDGE_VERTEX,
        openvdb::tools::PRESERVE_TILES);

    // 3. Keep original SDF where mask is active, set to outside elsewhere
    float background = interior.gridptr->background();
    for (auto iter = interior.gridptr->beginValueOn(); iter; ++iter) {
        openvdb::Coord coord = iter.getCoord();
        if (!thick_mask->tree().isValueOn(coord)) {
            iter.setValue(background);
        }
    }

    openvdb::tools::pruneInactive(interior.gridptr->tree());
}
```

The algorithm is: erode the SDF to find a thick core (regions where the interior is at least `min_width/2` from the boundary in all directions), dilate back to the original surface extent, then intersect with the original to keep only regions connected to the thick core. This removes small disconnected islands and thin protrusions that would create unusable infill zones.

---

## 10. DESIGNED (SOME SINCE IMPLEMENTED)

**Implementation status: These features were designed with detailed specifications. Several have since been implemented and are marked inline — Whirl Seal → Crater Ironing (9.c), Stagger-Level Ordering → thermal-aware ordering (9.d), Hexagonal → Magma Tri-hex (9.b), and Rectilinear (Grid) → Magma Rectilinear (9.f). The remainder (9.a Corner Width Optimization, 9.e Coupled Thermal-Pressure Depth Model) were not implemented for the stated reasons. All are disclosed here for defensive publication purposes to establish prior art.**

### 9.a Corner Width Optimization

**Design:** Increase infill line width near triangle corners to make the tube cross-section more circular, improving injection flow. The implementation would use distance-to-vertex calculation with a blend ratio to smoothly transition from normal line width to enhanced corner width. Per-point width values would be stored in ThickPolylines and rendered using OrcaSlicer's existing `variable_width()` extrusion system.

**Reason for removal:** At Magma cell scales (approximately 1.27mm edge length with a 0.4mm nozzle), width transitions occur in approximately 4.4ms at 100mm/s print speed. However, extruder pressure advance response time is 20-60ms for direct drive extruders. The extruder cannot track flow changes fast enough for the feature to produce meaningful results at these scales. The design is sound for larger cell sizes but impractical for the current target geometry.

### 9.b Hexagonal / Tri-hex Infill Pattern

**Status update: IMPLEMENTED as Magma Tri-hex.** The pure-hexagon lattice below was the original design; it now ships as **Magma Tri-hex**, a hybrid lattice of hexagonal cells plus the triangular cells that tile the gaps between them. Tri-hex uses **vent-based injection allocation** (a single injection serving multiple connected vents) rather than only pairwise U-tube coupling, and runs on the shared per-shape lattice/solver/injection pipeline (claim 13). Mixing triangular cells between the hexagons recovers the triangular pattern's continuous line families while keeping the hexagonal cells' multi-neighbour pairing. The original pure-hex design is retained below for prior art.

**How it works (Magma Tri-hex):**

- *Lattice.* A trihexagonal tiling: hexagon cells (hubs) with up/down triangle cells filling the gaps. It is bipartite -- a hex borders only triangles (6), a triangle borders only hexes (3), in a 2:1 triangle:hex ratio -- and its edges remain three line families at 60 degrees, so it prints with the triangle pattern's continuous single-wall sweeps.

- *Manifold injection unit.* One injection fills a **manifold**: a hub cell over a layer range [start, cap] plus N **vent legs**, each a triangle cell spanning the SAME [start, cap]. Windows are pinned to the tube bottom, so all legs are equal length; plastic enters each leg at the bottom window, fills up to the cap, and air escapes at the cap (the print surface at injection time). The two-cell U-tube is the degenerate one-leg manifold.

- *Hub scheduling (reuses the existing solver unchanged).* The bipartite hub<->vent adjacency is fed to the same tube-assignment solver (Section 5); ordinary per-cell exclusivity yields a hub<->vent matching that gives every hub-tube exactly one **primary** leg -- which both schedules the hub-tube's range, stagger, and height and guarantees the hub can inject (air escape).

- *Vent-fill allocation (maximize filled volume).* A second per-vent pass adds further legs to maximize total filled vent volume. For each vent it forms an "unavailable" layer mask -- the union of layers where the vent cell is absent due to part geometry AND layers already claimed by the primary matching -- and discards any candidate hub-tube whose [start, cap] crosses that mask (a block or prior claim inside the range would trap injected air). The surviving layers split the vent into present-runs; within each run it selects, by weighted interval scheduling over the fully-contained hub-tube ranges, the non-overlapping set covering the most layers (tie-broken toward the least-loaded hub for even distribution), and attaches the vent to those tubes as extra legs. Because hubs are uncapped and each vent layer is filled exactly once, the passes are independent per vent and yield the maximal vent fill achievable with windows aligned to real tube bottoms.

**Design (original pure-hex):** A modified honeycomb pattern with 6 neighbors per cell, 120-degree corners, adapted for Magma tube formation. Each hexagonal cell would have 6 potential pairing partners, with window placement on any of the 6 shared edges.

**Original trade-off (motivating the hybrid form):** A pure-hexagon lattice prints more slowly than the triangular pattern due to more direction changes per unit area -- the triangular pattern produces 3 sets of parallel lines (0, 60, 120 degrees), each printable in a single continuous sweep, whereas a hexagon perimeter requires more direction changes and shorter segments. The tri-hex form mixes triangular cells between hexagons to recover continuous sweeps.

### 9.c Whirl Seal Move (superseded by implemented Crater Ironing)

**Status update:** This was the original design for a circular nozzle motion around the injection hole. It is now **implemented and superseded** by Crater Ironing (Section 6.d), which is a spiral (not a single circle) that additionally uses the nozzle cone to plow the displaced rim back into the crater and is neighbour-aware. The original single-circle design is retained below as disclosed prior art.

**Design:** A circular motion of the nozzle around the injection hole before and/or after injection. The nozzle would trace a circle of radius approximately equal to the interior width, flattening any loose plastic from previous printing operations and ensuring a clean surface for the Z-slam seal to press against. Specification included configurable radius, speed, and number of revolutions.

### 9.d Stagger-Level Injection Ordering (alternative within the implemented ordering family)

**Status update:** Thermal-aware injection ordering **is now implemented** -- see Section 6.h, which orders injections globally per layer to spread spatially-near injections out in time. The stagger-level scheme described below was an earlier design for the same goal (preventing thermal cross-talk between simultaneously-filled neighbours); it is retained here as a disclosed alternative formulation within that family.

**Design:** Order injection within each layer so that U-tube pairs with the lowest floor (deepest tubes) are filled first. This ensures that deeper tubes solidify before shallower fills, preventing thermal interactions between adjacent tubes being filled simultaneously. The ordering would be: within each stagger level, sort by `pair_start_layer` ascending; across stagger levels, process the lowest stagger level first.

**Why the spatial heat-spread order (6.h) was implemented instead:** The stagger-level scheme orders by tube depth and stagger class, which only indirectly correlates with spatial proximity -- two tubes at the same stagger level can still be physically adjacent. The implemented order penalises *spatial* time-proximity directly (and globally across objects), which targets the actual heat-coupling failure more precisely, while the TSP warm start keeps travel close to optimal. The stagger-level variant remains a simpler heuristic of interest for extremely dense single-object tube patterns, and is disclosed for prior-art purposes.

### 9.e Coupled Thermal-Pressure Injection Depth Model

**Design:** Automatic computation of maximum achievable injection depth using a coupled thermal and pressure model. The tube is modeled as a hollow cylinder with triangular cross-section and equivalent hydraulic diameter.

**Thermal constraint:** The fill time `t_fill = 2 * depth * A_cell / V_dot` (U-tube path = 2x depth) must not exceed the freeze time `t_freeze = D_h^2 / (4 * alpha)` (thermal diffusion across the channel cross-section), where `alpha` is the thermal diffusivity of the plastic (~0.10 mm^2/s for typical FDM thermoplastics).

**Pressure constraint (Hagen-Poiseuille, laminar flow):** The pressure drop `dP = 32 * mu * L * v / D_h^2` through the U-tube path (L = 2x depth) must not exceed the extruder's maximum pressure `dP_max` (~15 MPa for direct-drive). The melt viscosity `mu` (~50 Pa*s at injection temperature, shear-thinned at ~1000 s^-1) is configurable per material.

**Coupled solution:** Setting `t_fill = fudge * t_freeze` and `V_dot = V_dot_max` simultaneously:

```
Variables:
  A_cell = sqrt(3)/4 * iw^2          -- triangular channel cross-section (mm^2)
  P_cell = 3 * iw                    -- triangular perimeter (mm)
  D_h    = 4 * A_cell / P_cell       -- hydraulic diameter = 0.577 * iw (mm)
  alpha  = thermal diffusivity of plastic (mm^2/s, configurable)
  mu     = melt viscosity at injection temp (Pa*s, configurable)
  dP_max = extruder max pressure (MPa, configurable)
  fudge  = tuning factor (configurable, absorbs hardware/material variation)

Coupled depth solution (V_dot drops out):
  depth^2 = fudge * dP_max * D_h^4 / (512 * mu * alpha)
  depth   = D_h^2 * sqrt(fudge * dP_max / (512 * mu * alpha))

Implied injection speed (self-adjusting):
  V_dot = dP_max * A_cell * D_h^2 / (64 * mu * depth)

Melt rate cap:
  if V_dot > filament_max_volumetric_speed:
    recompute depth using thermal-only at capped speed
    depth = fudge * V_dot_cap * D_h^2 / (8 * A_cell * alpha)
```

**Optimality:** The coupled solution is the global maximum depth. For any injection speed V, achievable depth = min(thermal(V), pressure(V)). Since thermal depth increases with V and pressure depth decreases with V, their intersection maximizes the minimum. No speed choice can produce deeper tubes.

**When user specifies injection speed:** The system independently computes the thermal limit and pressure limit at that speed and uses the minimum:

```
depth_thermal  = fudge * V_dot * D_h^2 / (8 * A_cell * alpha)
depth_pressure = dP_max * A_cell * D_h^2 / (64 * mu * V_dot)
max_depth      = min(depth_thermal, depth_pressure)
```

**Reason for removal:** The model was implemented and produced physically reasonable results, but the material parameters (viscosity, thermal diffusivity) vary significantly between filament brands and are not available in standard slicer profiles. Tuning the fudge factor required test prints for each material, which was not practical for a general-purpose tool. The design is retained for future implementation when material databases include thermal/rheological properties, or when a calibration procedure can derive the parameters from test prints.

**Prior art scope:** This disclosure establishes prior art for: (a) using coupled Hagen-Poiseuille pressure and thermal diffusion models to automatically compute injection tube depth limits, (b) the mathematical property that volumetric speed drops out of the coupled solution, yielding a depth that depends only on geometry and material properties, (c) automatic injection speed derivation from the coupled solution, and (d) configurable material parameters (viscosity, thermal diffusivity, extruder pressure) for per-filament injection optimization.

### 9.f Rectilinear (Grid) Infill Pattern

**Status update: IMPLEMENTED as Magma Rectilinear.** Now shipping as a selectable pattern (square cells, two perpendicular single-wall line families, a window omitted from a shared edge). The original design and trade-off discussion below are retained for prior art.

**Design:** A grid lattice in which two families of parallel infill lines at 0 and 90 degrees form square (or, with unequal spacing, rectangular) cells. Each cell is a vertical channel with a square cross-section. As with the triangular pattern, cell spacing is derived from the nozzle and interior-width geometry, each cell is paired with an orthogonally adjacent neighbor sharing a wall, and a window gap omitted from the shared wall connects the pair into a U-tube. Stagger levels, spiral interlock, and per-layer volume computation apply directly, substituting the square-cell geometry (cross-section `iw^2`, perimeter `4 * iw`, hydraulic diameter `iw`) into the same formulas. A 45-degree-rotated variant produces diamond cells with injection holes offset between layers.

**Advantages:** The two line families are long, continuous, orthogonal sweeps that print quickly with minimal direction changes (matching the speed characteristics of standard rectilinear/grid infill). The square cross-section presents a large flat sealing area and is straightforward to model and size.

**Trade-offs vs. triangle:** Square cells have 90-degree interior corners, which give somewhat poorer injection flow and are a little harder for a round nozzle to seal than the 120-degree corners of the triangular pattern; for equal wall material the grid produces fewer reinforcing tubes per unit area, and window placement is limited to the 4 cell edges. The triangular pattern remains the default for those reasons, but rectilinear is offered as an option where its long, continuous orthogonal sweeps and large flat sealing face are preferred.

**Prior art scope:** This disclosure establishes prior art for square-, rectangular-, and diamond-cross-section channel variants of the Magma tube system, including orthogonal grid cell pairing, window placement on grid cell edges, and the application of stagger, spiral interlock, and volume computation to grid-based Magma channels.

---

## 11. SPECULATIVE EMBODIMENTS

**Implementation status: SPECULATIVE. These concepts are disclosed for broader defensive coverage. None have been implemented or tested. They represent reasonable extensions of the disclosed system that a person skilled in the art might pursue.**

### 10.a Non-Planar and Conformal Layers

The Magma tube system could be extended to non-planar printing (curved-layer FFF) where the Z-height varies continuously across each layer. In this embodiment:

- Tube walls would follow the curved layer surface, producing smooth cylindrical channels regardless of the tube's angle relative to the build plate.
- The triangular lattice would be projected onto the curved surface using geodesic coordinates rather than Cartesian (a, b, c) coordinates.
- Window placement would use geodesic distance along the curved surface rather than Z-height offsets.
- 5-axis or 6-axis robotic implementations could print non-planar layers with arbitrary orientation, enabling tubes aligned with structural load paths.
- Conformal cooling channels (following the contour of the part surface at a fixed offset depth) could be generated using the same lattice system projected onto offset surfaces.

### 10.b Advanced Channel Topologies

Beyond U-tube pairs, the channel network could employ:

- **Graph-traversal routing:** Model the tube network as a graph and compute shortest-path or Hamiltonian-path injection routes that fill the maximum number of tubes with a single injection point per connected component.
- **Branching networks:** Tree-structured channels where a single injection point feeds multiple tubes through branching junctions, reducing the number of injection operations per layer.
- **Polygonal cross-sections:** Hexagonal, star-shaped, or other cross-section geometries that provide different flow characteristics or structural properties.
- **Dead-end termination with pressure relief:** Tubes that terminate without connecting to a vent, using micro-venting (sub-0.2mm air exit holes) that allow air to escape via surface tension while retaining injected plastic.
- **Series-connected tubes:** Multiple U-tube pairs connected in series through shared windows, enabling a single injection to fill multiple tube pairs.
- **Lattice mixing:** Combining triangular and hexagonal cells in different regions of the same part based on local structural requirements.

### 10.c Simulation-Driven Optimization

- **FEA stress-adaptive topology:** Use finite element analysis to compute principal stress vectors throughout the part, then align tube orientation and density with the stress field. High-stress regions would receive denser tubes aligned with the tensile direction; low-stress regions would receive sparser tubes or none.
- **CFD flow-optimized injection:** Model the injection process using computational fluid dynamics with non-Newtonian fluid models (power-law or Carreau-Yasuda) to optimize tube geometry for complete filling. Include thermal coupling (fluid cooling during injection) and solidification front tracking.
- **Wall-modifying generators:** Locally thicken infill walls at tube interfaces to improve the seal between tube walls and injection plastic. Could use adaptive line width based on proximity to tube centers.
- **Topology optimization with injection constraints:** Standard SIMP or level-set topology optimization with additional constraints ensuring that all high-density regions are reachable by injection tubes and that tube networks remain connected.

### 10.d Hardware Methods

- **Parallel injection manifolds:** A plate with multiple injection nozzles arranged to match the tube pattern, enabling simultaneous injection of multiple tubes. The manifold would press against the print surface with spring-loaded nozzles that accommodate slight height variations.
- **Plate injection manifolds:** A flat plate with channels machined to match the tube pattern, pressing against the print surface to inject multiple tubes through a single pressurized reservoir.
- **Vacuum-assisted filling:** Apply vacuum to the vent side of each U-tube pair while injecting from the injection side, reducing air resistance and enabling faster, more complete fills. The vacuum could be applied through a manifold plate on the vent side.
- **Back-pressure monitoring via motor torque:** Monitor extruder motor current or stepper driver load during injection to detect tube blockages, overfilling, or air locks. Abort injection for a specific tube if back-pressure exceeds a threshold.
- **Micro-venting:** Sub-0.2mm diameter air exit holes at the top of vent-side tubes, sized to allow air to escape via surface tension effects while retaining the higher-viscosity injection plastic. Could be implemented as intentional gaps in the top layer of infill.
- **Heated injection manifold:** A separate heated element that maintains injection material at elevated temperature during multi-tube injection, avoiding the thermal cycling of heating/cooling the printer's hotend for each injection layer.
- **High-flow nozzles:** CHT, Volcano, or other high-throughput nozzle geometries that sustain greater volumetric flow at lower pressure drop, enabling faster injection before the surrounding cell walls heat-soak.
- **Purpose-shaped injection nozzles:** Nozzles with tips profiled to match the tube cross-section (e.g., triangular) and a flat sealing face, improving the seal between nozzle and tube opening during Z-slam injection.
- **Compliant tip seals:** Silicone or elastomer gaskets at the nozzle tip that conform to the print surface and seal around the tube opening during injection.
- **Non-stick nozzle coatings:** PTFE or other low-adhesion coatings on the injection nozzle to prevent injected material from adhering to and lifting off the tip when the nozzle retracts.
- **Thermally isolated injection nozzles:** A thermal break around the injection nozzle limiting heat conduction into the cell tops, reducing premature softening or deformation of the surrounding printed walls during injection.
- **Enlarged-bore injection nozzles:** A nozzle with a larger bore dedicated to injection, providing greater volumetric throughput at lower pressure than the printing nozzle.

### 10.e Material Variations

The injection channels could be filled with materials other than the same thermoplastic used for printing:

- **Curable polymers:** Two-part epoxy, polyurethane, or UV-curable resins that provide superior strength-to-weight ratios compared to re-melted thermoplastic. Channels would be designed with appropriate flow and cure time considerations.
- **Cementitious materials:** Cement, grout, or hydraulite for applications where thermal properties or compressive strength are more important than tensile strength. Channels would be sized for the larger particle sizes of cementitious materials.
- **Functional fluids:** Conductive inks for embedded wiring, phase-change materials (PCMs) for thermal management, coolant channels for active cooling. Channels would be sealed at both ends after filling.
- **Reinforced slurries:** Chopped fiber matrices (carbon fiber, glass fiber, aramid) suspended in a carrier resin. The channel cross-section would be sized to allow fiber passage without clogging, and flow modeling would account for fiber orientation effects.
- **Low-melting-point metals:** Solder, Field's metal, or other low-melting alloys for applications requiring electrical conductivity or thermal conductivity. Injection temperature and tube wall material compatibility would need to be verified.
- **Foaming agents:** Materials that expand after injection to fill voids and provide insulation or cushioning. Channel sizing would account for expansion ratio.
- **Asymmetric dual-material injection:** Printing the channel walls in a higher-temperature structural material (e.g., PETG, ABS, PC, or fiber-filled composite) while injecting a lower-temperature or lower-viscosity material (e.g., PLA), using a dual-extruder, IDEX, or toolchanger machine so the structure and injectate can have independent temperatures and nozzle geometries. The injected material interlocks mechanically with the channel geometry and need not chemically bond to the walls.
- **Low-melt and sacrificial injectates:** Low-melting-point thermoplastics such as polycaprolactone (PCL, ~60°C) or TPU, or sacrificial sugar/wax fills for lost-material post-processing, chosen for ease of injection or subsequent removal.
- **Adhesives and sealants:** Glue, silicone, or other room-temperature-curing adhesives and sealants injected to bond adjacent layers, where the injectate cures chemically rather than re-solidifying thermally.
- **Post-injection annealing:** Heat-treating the completed part to fuse the injected material to the channel walls and strengthen the interfacial bond after injection.

### 10.f Shell Mode

A variant where the part consists primarily of form-following shells with injection channels between them, designed for curved or sloped surfaces where planar infill is inefficient. The shells would follow the part's contour at varying offsets, with channels running between adjacent shells. This mode would be particularly effective for thin-walled parts, aerodynamic surfaces, and enclosures where the structural load follows the surface geometry.

### 10.g Adaptive Cell Sizing

Variable-density tube patterns where cell size varies across the part based on:

- **Local stress analysis:** Denser cells (smaller cell spacing) in high-stress regions, sparser cells in low-stress regions.
- **Geometric constraints:** Smaller cells near thin features, corners, and complex geometry where larger cells would not fit. Larger cells in open regions for faster printing.
- **User-defined density maps:** Painted or region-specified density multipliers that allow manual control over reinforcement distribution.
- **Gradient transitions:** Smooth transitions between different cell sizes using intermediate cells, avoiding abrupt changes that could create stress concentrators.
- **Anisotropic cell shapes:** Non-equilateral triangles stretched along a preferred direction to provide directional reinforcement.

---

## 12. Legal Notice

### Public Domain Dedication

This document and all concepts, methods, algorithms, code, data structures, and embodiments described herein are dedicated to the **Public Domain** under the **Creative Commons CC0 1.0 Universal** dedication.

To the extent possible under law, the authors have waived all copyright and related or neighboring rights to this work. This work is published from the United States.

Full text of the CC0 dedication: https://creativecommons.org/publicdomain/zero/1.0/

### Prior Art Declaration

This document serves as a **Defensive Publication**. All concepts, methods, algorithms, code, and structures described herein are disclosed to the public to establish **Prior Art**, preventing the patenting of these ideas by third parties. This work is dedicated to the Public Domain under the Creative Commons CC0 1.0 Universal dedication.

The original publication date of **February 9, 2026** establishes the priority date for Sections 1-4, 6-12. The update date of **March 16, 2026** establishes the priority date for Section 5 (Optimized Tube Assignment). The update date of **June 23, 2026** establishes the priority date for the multi-pattern lattice abstraction (Magma Rectilinear and Magma Tri-hex), the dual cell-presence gate, the per-tube actual-opening Z-slam sealing model, and the clipped-cavity centroid injection point (novel claims 13-15). Any patent application filed after the applicable date covering substantially similar subject matter is anticipated by this disclosure.

The disclosed system encompasses, but is not limited to:

1. Triangular lattice coordinate systems for infill tube placement in FDM printing
2. Stagger coloring algorithms using modular arithmetic on lattice coordinates
3. Spiral offset systems creating helical interlocking tubes in layered manufacturing
4. Dual-lattice identity/position tracking for stable tube assignment across layers
5. Coupled thermal-pressure models for computing injection depth limits
6. Z-slam sealing techniques for nozzle-based injection into printed channels
7. Per-layer injection as a print stage within FDM printing processes
8. Window (fenestration) placement in infill walls for U-tube formation
9. G-code comment protocols for embedding 3D visualization metadata
10. SLA hollowing algorithms repurposed for FDM dual-zone boundary generation
11. Constrained mean curvature flow smoothing for zone boundaries
12. Morphological reconstruction for filtering thin interior sections
13. Salvage tube assignment algorithms for boundary cells
14. Constriction detection using area-ratio heuristics
15. Parametric gap splitting for diagonal infill lines
16. Volumetric speed fallback hierarchies for injection extrusion
17. Crater ironing: a post-injection inward-spiral plow that pushes the displaced rim back into the crater and scrapes the nozzle clean, hovering over neighbour cells so their air holes stay open
18. Multi-material filament switching for injection
19. Segmented injection extrusion for progressive preview animation
20. Auto-sizing of tube geometry from nozzle diameter
21. 3D Douglas-Peucker simplification of tube visualization paths
22. Adaptive layer height support for tube boundary placement
23. Non-planar and conformal layer extensions for tube systems
24. Graph-traversal and branching injection routing topologies
25. Simulation-driven optimization of tube placement and flow
26. Hardware manifold and vacuum-assisted injection methods
27. Alternative injection materials (curable polymers, cementitious, functional fluids)
28. Shell-mode reinforcement with inter-shell channels
29. Adaptive and anisotropic cell sizing
30. Corner width optimization for circular tube cross-sections
31. Hexagonal infill pattern variants for tube systems
32. Whirl seal moves for injection surface preparation
33. Stagger-level injection ordering for thermal management
34. Micro-venting for dead-end tube termination
35. Two-stage greedy + constraint programming tube assignment solvers
36. Most-constrained-first scoring heuristic for tube assignment priority queues
37. Integer micron arithmetic for constraint solver variable domains
38. Discrete layer-boundary domains for tightening LP relaxation in interval scheduling
39. Cumulative scheduling constraints for weak plane avoidance in tube boundary stagger
40. Spatial block partitioning with overlapping XY/Z passes for scalable constraint solving
41. Warm-start hint transfer from greedy heuristic to constraint programming solver
42. Periodic re-scoring of priority queues to correct stale constraint ordering
43. Per-cell consumed-interval tracking with binary search overlap detection
44. Five-tier safe park positioning for injection temperature changes
45. Parallel-transported frame computation for near-vertical GCode preview rendering
46. Square (rectilinear) and tri-hex (hexagon + triangle) Magma lattice patterns, and a shape-generic per-shape geometry/lattice abstraction sharing one solver, injection, and rendering pipeline across patterns
47. Vent-based injection allocation (a single injection serving multiple connected vents) for mixed hexagon/triangle lattices
48. Dual cell-presence gating combining a minimum clipped-area fraction with a minimum injection-point clearance to the opening boundary
49. Per-tube injection sealing depth computed from each tube's actual (boundary-clipped) opening rather than a single global ideal
50. Clipped-cavity centroid injection-point selection (inscribed-circle centre for regular cells) for boundary-clipped cells

### Source Code Availability

The complete source code implementing the IMPLEMENTED portions of this disclosure is available as open-source software under the same CC0 public domain dedication. The code is implemented as modifications to OrcaSlicer, an open-source 3D slicer application.

---

## Structured Data for Search Engine Indexing

```json
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Defensive Publication: Magma Vertical Reinforcement Infill System for FDM 3D Printing",
  "datePublished": "2026-02-09",
  "author": {
    "@type": "Organization",
    "name": "Magma Project Contributors"
  },
  "description": "Public domain disclosure of a software system for vertical reinforcement of FDM 3D printed parts using a selectable lattice infill (triangular, rectilinear/square, or tri-hex hexagon+triangle) with hollow channels filled by per-layer injection during printing. Establishes prior art for coordinate systems, a shape-generic per-pattern lattice abstraction, spiral interlock, coupled thermal-pressure injection models, two-stage greedy/CP-SAT tube assignment solvers with integer micron arithmetic and discrete domain optimization, a dual area+clearance cell-presence gate, per-tube actual-opening Z-slam sealing, clipped-cavity centroid injection points, zone boundary generation, safe park positioning, and G-code visualization protocols.",
  "license": "https://creativecommons.org/publicdomain/zero/1.0/",
  "keywords": [
    "FDM 3D printing",
    "vertical reinforcement",
    "infill pattern",
    "triangular lattice",
    "injection molding",
    "per-layer injection",
    "U-tube channels",
    "spiral interlock",
    "helical tubes",
    "stagger coloring",
    "window fenestration",
    "coupled thermal-pressure model",
    "hydraulic diameter",
    "Hagen-Poiseuille",
    "injection depth",
    "Z-slam seal",
    "G-code generation",
    "slicer software",
    "OrcaSlicer",
    "open source",
    "public domain",
    "defensive publication",
    "prior art",
    "CC0",
    "zone boundary",
    "SLA hollowing",
    "mean curvature flow",
    "OpenVDB",
    "dual-zone architecture",
    "multi-material injection",
    "tube visualization",
    "Douglas-Peucker simplification",
    "adaptive layer height",
    "constriction detection",
    "salvage tube assignment",
    "morphological reconstruction",
    "constraint programming",
    "CP-SAT solver",
    "OR-Tools",
    "interval scheduling",
    "greedy heuristic",
    "most-constrained-first",
    "warm start",
    "integer micron arithmetic",
    "discrete domains",
    "LP relaxation",
    "weak plane avoidance",
    "spatial block partitioning",
    "cumulative scheduling",
    "safe park positioning",
    "parallel transport frame"
  ],
  "inLanguage": "en",
  "isAccessibleForFree": true,
  "proficiencyLevel": "Expert",
  "genre": "Defensive Publication",
  "about": {
    "@type": "Thing",
    "name": "Magma Vertical Reinforcement Infill System",
    "description": "Software-only vertical reinforcement for FDM 3D printing via per-layer injection into triangular lattice channels"
  }
}
```

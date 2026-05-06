# Magma Tube Assignment: Greedy + CP-SAT Solver

## What This Solves

Magma creates U-tube infill channels by pairing adjacent triangle cells. Each
pair shares a contiguous vertical range of layers — plastic is injected down
one cell and up the other through a window at the bottom.

The assignment problem: for every pair of adjacent cells, decide **how many**
tube segments to place, **where** (start/end in Z), and **which neighbor** to
pair with, such that:

- No cell-layer is used by two tubes simultaneously
- Tube heights are within physical bounds (min/max mm)
- Neighboring tubes' boundaries are vertically staggered (no weak planes)
- Coverage is maximized (unpaired = hollow = no Z-reinforcement)

## Two-Stage Architecture

The solver has two stages. The greedy stage always runs. The CP-SAT refinement
stage is optional (controlled by `magma_tube_solver_mode` setting).

```
MagmaTubeSolver::solve()
  build_micron_tables()     — layer boundaries in integer microns
  build_edges()             — adjacent cell pairs, shared presence runs
  greedy_warm_start()       — fast heuristic, populates m_committed
  validate("GREEDY")        — check constraints, log coverage
  if (Refined mode) {
    solve_pass(0, 0)        — single XY pass per Z level, CP-SAT refinement
                              over R x R overlapping blocks
    validate("CPSAT")       — check constraints, log coverage
  }
  extract_results()         — microns → UTubePair layer indices
  validate("FINAL")         — final constraint check + coverage summary
```

### User Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Tube solver quality | Basic | Basic (greedy only, ~1s) or Refined (greedy + CP-SAT) |
| Solver timeout | 60s | Total time budget for CP-SAT (Refined only, 5–600s) |
| Stagger period | auto | Grid clustering period in mm (0=auto: max_tube_height/3) |

---

## Stage 1: Greedy Warm Start

Fast, deterministic heuristic (~100-500ms for 1000+ cells). Produces good
initial tube assignments that Stage 2 can refine.

### Algorithm: Most-Constrained-First with Periodic Re-scoring

**Scoring**: For each unconsumed cell×layer, compute a score = sum of achievable
tube heights across all unconsumed neighbors. Lower score = fewer/shorter
options = more constrained. Push to a min-heap.

**Assignment**: Pop the most constrained cell×layer. Find its most constrained
neighbor (fewest unconsumed layers in their shared run at this Z). Expand the
longest valid tube between them (respecting min/max height, run boundaries,
and consumed intervals on both cells). Mark consumed on both cells.

**Periodic re-scoring**: After every `max(200, num_edges/3)` assignments, rebuild
the heap from scratch with fresh consumed state. This corrects stale priority
ordering — cells that became constrained due to neighbor consumption get
re-prioritized. Typically triggers ~3-10 re-scores per model.

### Key Properties

- **Most constrained first**: boundary cells (1 neighbor) before interior (3).
  Prevents stranding.
- **Longest tubes**: maximizes coverage per assignment. Prefers fewer, taller
  tubes (stronger reinforcement).
- **Natural stagger**: the priority ordering causes different edges to "take
  turns" at each Z level, spreading boundaries without explicit stagger logic.
- **Respects runs**: never crosses constriction breaks.
- **Layer-aligned**: all boundaries at actual layer positions from MicronTables.

### Data Structures

- `CellConsumed`: sorted non-overlapping micron intervals per cell. Binary
  search for overlap checks, insert+merge for additions.
- `CellLayerScore`: min-heap entry with cell, layer, and score.

### Performance

| Model | Cells | Tubes | Coverage | Time |
|-------|-------|-------|----------|------|
| 20mm cube | 71 | 148 | 80.6% | 4ms |
| Stanford bunny | 1056 | 4517 | 76.5% | 503ms |

---

## Stage 2: CP-SAT Refinement (Optional)

Constraint-based optimization using Google's CP-SAT solver. Starts from the
greedy solution and improves coverage and stagger. Controlled by the "Refined"
solver mode setting.

### Units: Microns

All interval variables operate in **integer microns** (µm). This eliminates
layer-index lookup tables for variable layer heights — tube height becomes a
simple linear bound.

Pre-computation (once per object):
```
top_um[L]    = llround(print_z * 1000)         — authoritative
bottom_um[0] = llround(bottom_z * 1000)
bottom_um[L] = top_um[L-1]                     — exactly contiguous
```

### Discrete Domains

All micron-space variables use discrete domains derived from a unified layer
boundary list. Since `bottom_um[L+1] == top_um[L]`, each boundary is both the
end of one layer and the start of the next:

```
boundaries = [bottom_um[eff_start], top_um[eff_start], ..., top_um[eff_end]]

start, end  ∈ Domain::FromValues(boundaries)
size        ∈ Domain::FromValues({b[j]-b[i] | j>i} ∩ [min_h, max_h])
contrib     ∈ {0} ∪ sizes
```

This dramatically tightens the LP relaxation compared to continuous ranges,
improving solver performance by 10-30%.

### CP-SAT Model (per block)

**Variables** (per segment slot):
```
active   : BoolVar              — is this segment used?
start    : IntVar               — tube bottom (discrete boundary domain)
end      : IntVar               — tube top (discrete boundary domain)
size     : IntVar               — height (discrete feasible-difference domain)
interval : OptionalIntervalVar(start, size, end, active)
```

**Constraints**:
1. **NoOverlap per cell** — all segment intervals + frozen intervals
2. **Height bounds** — encoded in size domain [min_h_um, max_h_um]
3. **Segment ordering** — symmetry breaking within runs

**Objective**:
```
Maximize:
    W_COVERAGE(1M) × Σ{ contrib }        — coverage (fill ratio, dominant)
  - W_AVG(5)       × deficit              — discourage avg tube length reduction
```

**Average-length deficit** (1 IntVar, 1 constraint):
```
min_avg    = greedy_avg × (100 - stagger_tolerance) / 100   (stagger_tolerance is an internal constant)
deficit    = max(0, min_avg × Σ{active} - Σ{contrib})
```

| Weight | Value | Purpose |
|--------|-------|---------|
| W_COVERAGE | 1,000,000 | 1µm of coverage >> all other terms; fill never sacrificed |
| W_AVG | 5 | Worst-case deficit ~500K < 1M; discourages splits at ~20-30K per |

### Stagger: Domain Restriction

Stagger is handled structurally by domain restriction, not by objective terms.
Tube boundaries can only land on `{run endpoints ∪ phase-grid points}`:

- **Run endpoints** (start/end of viable cell-pair range): always included,
  guaranteeing that the maximum-fill solution is always feasible.
- **Phase-grid points**: 3 grids offset by 0, P/3, 2P/3 where P = stagger_period.
  SharedEdge type (Horizontal/Col60/Diag120) maps each edge to its phase via
  triangle 3-coloring. Adjacent edges always use different grids.

When a run must split (run height > max_tube_height), internal split points are
forced to grid positions. Different edges have different grids → different split
positions → automatic stagger with zero constraints or objective terms.

No W_GRID_DIST, W_DODGE, or W_ACTIVATION in the objective. Earlier designs used
dodge penalties, but these spread injections across many Z levels. Domain
restriction concentrates them on a small set of grid-aligned heights. The
average-length deficit discourages needless splitting (same effect as the old
W_ACTIVATION but tied to the actual metric we care about).

### Warm Start from Greedy

Committed segments from the greedy stage (stored in `m_committed`) become
CP-SAT warm start hints:
- All segments for decision edges → `AddHint(active, start, end)`
- Segments from XY-boundary edges → frozen on the in-block cell
- Remaining slots hinted inactive (complete initial solution)

### Block Partitioning

The model is spatially partitioned into XY blocks for bounded computation:

- **XY**: R=16 cells per block side. Single XY pass per Z level with overlapping
  blocks so every edge is interior to at least one block.
- **Z**: Full object height (no Z windowing). Stagger decisions at the bottom
  cascade freely through the entire column without window boundary blindness.

Edge collection uses cell reverse lookup (`m_cell_edges`) instead of scanning
all edges — O(block cells × edges per cell) instead of O(total edges).

### Segment Slots per Run

Each run (contiguous cell-pair presence range) gets K segment slots:
```
K = max(2, K_from_greedy × 13 / 10 + 1)
K_from_greedy = number of greedy tubes on this run
```
The 30% headroom over the greedy count gives CP-SAT room to split tubes for
stagger without running out of slots.

### Parallelism

Blocks are solved **sequentially**. CP-SAT uses all available cores internally
for its own search, which dominates the time budget for a single block. Running
blocks in parallel would over-subscribe the CPU and hurt total throughput.

### Cancellation

Checked between passes via `throw_if_canceled()` (OrcaSlicer's standard
pattern). Throws `CanceledException` which propagates up to the UI. Current
blocks finish their timeout before cancellation takes effect.

---

## Validation

Reusable `validate_committed()` function checks all constraints on committed
segments. Called after each stage (GREEDY, CPSAT, FINAL):

1. **Layer range** — start/end within model bounds
2. **Height bounds** — tube height within [min_h, max_h] ± 0.01mm tolerance
3. **Edge validity** — both cells are neighbors
4. **Cell presence** — both cells present at every layer in the tube
5. **Per-cell NoOverlap** — no two tubes on the same cell overlap in Z
6. **Per-edge NoOverlap** — no two segments on the same edge overlap
7. **Coverage summary** — overall %, cells unfilled, cells <25%, cells <50%

---

## Files

```
src/libslic3r/Magma/
    MagmaGreedyWarmStart.hpp/.cpp  — greedy warm start algorithm
    MagmaTubeSolver.hpp/.cpp       — CP-SAT solver, validation, orchestration
    MagmaTubeMap.hpp/.cpp          — bridge: reads config, calls solver
```

## Performance

Indicative numbers from development testing. Actual times depend on solver
timeout, model complexity, and machine.

| Model | Cells | Greedy stage | + CP-SAT refinement |
|-------|-------|--------------|--------------------|
| 20mm cube | 71 | 80.6% coverage / ~4ms | ~90% / 1-2 min |
| Stanford bunny | 1056 | 76.5% / ~500ms | 79-80% / 5-10 min |

The greedy stage alone provides good coverage in milliseconds — fast enough
for interactive slicing. CP-SAT refinement adds 3-7% coverage at a significant
time cost; recommended for final production slicing on complex models.

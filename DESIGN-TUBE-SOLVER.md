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
    for (z_off = 0; z_off <= max_layer; z_off += z_stride)
      solve_pass(0, 0, z_off)  — one XY pass over R x R overlapping blocks
                                 for this 50%-overlapping Z window
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
| Weak plane avoidance | 0 (auto) | Min Z-separation between neighboring tube boundaries in mm, via `magma_boundary_dodge` (0 = auto ≈ 4 × max layer height). Refined mode only |

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

**Objective** — a three-tier lexicographic preference encoded as a single
weighted sum (each tier's minimum contribution exceeds the next tier's maximum
total, so higher tiers always dominate):
```
Maximize:
    W_COVERAGE(1M) × Σ{ contrib }              — Tier 1: coverage (fill µm, dominant)
  - W_ACTIVATION(100) × Σ{ active }            — Tier 2: prefer fewer, longer tubes
  - W_STAGGER_TIGHT(2) × Σ{ tight_capacity }   — Tier 3a: spread boundaries (close range)
  - W_STAGGER_WIDE(1)  × Σ{ wide_capacity }    — Tier 3b: spread boundaries (wider range)
```

**Why a fixed activation cost?** A linear length bonus (`W × size`) cannot
prevent splitting, because `W × S == W × (S/2) + W × (S/2)`. A fixed penalty per
active segment makes one long tube strictly cheaper than two short tubes of the
same total coverage. `W_ACTIVATION` is set above the maximum stagger benefit a
single split could earn (~36), so coverage and tube count are never traded away
for stagger.

| Weight | Value | Purpose |
|--------|-------|---------|
| W_COVERAGE | 1,000,000 | 1µm of coverage >> all other terms; fill never sacrificed |
| W_ACTIVATION | 100 | Fixed cost per active segment; prefers fewer, longer tubes |
| W_STAGGER_TIGHT | 2 | Penalty per unit of peak boundary concentration in the tight zone |
| W_STAGGER_WIDE | 1 | Penalty per unit of peak boundary concentration in the wide zone |

### Stagger: Cumulative-Constraint Penalty

Stagger is an **objective penalty** built from CP-SAT cumulative constraints, not
domain restriction. Boundaries are free to land on any feasible layer boundary;
the objective simply discourages neighboring tube ends from clustering at the
same Z. The strength of the penalty is controlled by the dodge distance from the
`magma_boundary_dodge` setting (0 = stagger disabled, the whole block below is
skipped when `dodge_um == 0`).

**Exclusion zones.** Each tube boundary (a `start` or `end`, plus any frozen
boundary from committed segments) gets a fixed-width interval centered on its
position. Two zone widths are used:

- **Wide zone** = `dodge_um` (the full dodge distance).
- **Tight zone** = `dodge_um / 2`.

If two boundaries fall within a zone width of each other, their intervals
overlap. Feeding those intervals to a cumulative constraint makes the peak number
of simultaneously-overlapping boundaries show up as the cumulative's *capacity*
variable. That capacity is left fully soft (any value is feasible) and is
**subtracted from the objective**, so the solver minimizes peak boundary
concentration — i.e. it pushes boundaries apart.

**Tight vs. wide.** Each cell builds two cumulatives — one over tight zones
(weight `W_STAGGER_TIGHT = 2`) and one over wide zones (weight
`W_STAGGER_WIDE = 1`). This gives a graduated penalty: boundaries that are very
close together overlap in *both* the tight and wide zones and pay both penalties;
boundaries that are only moderately close overlap in the wide zone alone and pay
only the smaller penalty.

**Ring weighting.** Cumulatives are built per cell over its Ring-1 neighborhood,
with each boundary contributing a demand:

- **Ring-0** (the cell's own edges): demand = 2.
- **Ring-1** (edges of neighboring cells): demand = 1.

Boundaries on the cell's own edges therefore count double, so the solver works
hardest to separate the boundaries most directly above/below each other.

### Warm Start from Greedy

Committed segments from the greedy stage (stored in `m_committed`) become
CP-SAT warm start hints:
- All segments for decision edges → `AddHint(active, start, end)`
- Segments from XY-boundary edges → frozen on the in-block cell
- Remaining slots hinted inactive (complete initial solution)

### Block Partitioning

The model is spatially partitioned into XY blocks for bounded computation:

- **XY**: R=16 cells per block side. Single XY pass per Z level with overlapping
  blocks (R_OVERLAP=2 cells, stride = R − R_OVERLAP) so every edge is interior to
  at least one block.
- **Z**: 50%-overlapping Z windows. Window = 4 × max tube height in layers,
  stride = 2 × max tube height in layers (= window minus overlap). The driver
  loops `for (z_off = 0; z_off <= max_layer; z_off += z_stride)`, calling
  `solve_pass(0, 0, z_off, …)` once per window. The 2× overlap means every tube
  lies fully inside at least two Z windows, so boundary decisions are never made
  blind to the layers just above or below.

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

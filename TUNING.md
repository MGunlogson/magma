# Tuning Magma

Settings that print well, and the reasoning behind them so you can adapt them to hardware
we have not tested.

## Known-good settings

Measured on a **0.6 mm E3D V6 brass nozzle** (tip flat 1.75 mm, cone half-angle 30°) with
**PLA** at 12 mm³/s max volumetric speed.

| Setting | Value |
|---|---|
| Sparse infill pattern | Magma Rectilinear |
| Tube interior width | 1.6 mm |
| Max tube height | 3.5–4 mm |
| Nozzle tip flat | 1.75 (measure your own) |
| Nozzle cone half-angle | 30 |
| Seal press | 0.1 |
| Plunge depth | 0.4 (0.4–0.6 all print the same, 0.2 leaks) |
| Tube fill factor | 0.9 |
| Injection speed | 0 (auto) |
| Injection dwell | 0 |
| Injection order | Spread heat |

If that describes your printer, use those numbers and skip to [Symptoms](#symptoms).

## Keep injections under about 1.5 seconds

This is the strongest predictor of a clean print. Tubes filling in 1.5 s or less have
printed cleanly. By 2 s the lattice starts to deform. By 3 s the cells around the injection
point are destroyed and leaking.

    injection time = volume per tube / filament max volumetric speed

Injection runs at the filament's maximum rate already, so that rate is fixed by your
material and the only lever is less plastic per tube. For PLA at 12 mm³/s, 1.5 s is about
18 mm³. The slicer shows the time in the readout and warns past the limit.

We do not know why the limit exists. Two explanations fit every test print, and none of them
separated the two:

* The nozzle is a heat source for as long as it is sealed into a cell, and long enough
  contact softens the surrounding walls until the seal fails.
* The melt cools on the way down and freezes before reaching the bottom, so backpressure
  pushes it back out past the seal.

Both look identical from outside: plastic escaping onto the top surface. Both get worse with
longer injections. Treat 1.5 s as a solid rule of thumb for the hardware above rather than a
physical constant. The direction is not in doubt. Shorter is better, and nothing we tried
made a long injection safe.

Splitting a long injection into shorter bursts does not work. The melt freezes into a plug
and the rest of the injection has nowhere to go.

## Set these four, in order

### 1. Nozzle tip flat

The diameter of the flat ring around your nozzle's orifice, not the orifice itself. Measure
it with calipers. Everything else resolves against it.

If unsure, declare it slightly low. Too large means the cone stops short of covering the
cell, and the tube leaks at any depth. Too small costs a little extra descent and nothing
else.

### 2. Tube interior width

The nozzle seals a cell by descending until its cone covers the cell's furthest corner. A
cell only slightly wider than the flat is covered almost immediately, and that shallow
engagement has no tolerance for the unevenness of a rim printed in 0.2 mm layers. It leaks.
Below 0.4 mm of seal depth it is unreliable, and the slicer warns. 0.5 mm is comfortable.

Your flat therefore sets a minimum tube width:

| Nozzle tip flat | Minimum tube interior |
|---|---|
| 1.00 mm | 1.03 mm |
| 1.20 | 1.18 |
| 1.40 | 1.32 |
| 1.60 | 1.46 |
| 1.75 | 1.56 |
| 2.00 | 1.74 |

Prefer the smaller end of what your flat can seal, but stay above the floor rather than on
it. See [Why the nozzle matters most](#why-the-nozzle-matters-most).

### 3. Max tube height

Tube volume is about `2 × cell area × height × fill factor`. Once width is fixed, height is
what trades against the 1.5 s limit, and it is the cheaper of the two to give up because it
does not disturb the seal.

Do not spend the whole budget on height. The unmeasured freezing risk above gets worse the
further the melt has to travel, and a tall narrow channel is its worst case. Every good
print so far has been at 3–4 mm. Treat these as a ceiling, not a target:

| Tube interior | Max height (PLA, 18 mm³) |
|---|---|
| 1.05 mm | 9.1 mm |
| 1.19 | 7.1 |
| 1.33 | 5.7 |
| 1.47 | 4.6 |
| 1.58 | 4.0 |
| 1.75 | 3.3 |

For other materials, scale by their volumetric rate. The readout shows the real number.

### 4. Plunge depth

The nozzle keeps descending while the injection runs. It adds grip at the seal the same way
the initial press does, and it takes nothing from the tube or the seal. The only cost is
total depth into the part.

0.2 mm is not enough once an injection is long enough to matter. 0.4 to 0.6 are
indistinguishable. Use 0.4.

## Leave these alone

**Injection speed: 0 (auto).** Auto is the filament's maximum volumetric rate. Slowing it
down is the most damaging single change you can make: it melts the lattice and makes every
tube leak.

**Injection dwell: 0.** Holding the nozzle down afterwards helps nothing. It does not let
the plastic settle or the seal set. Five seconds of dwell melts a cell wall outright.

**Pattern: Magma Rectilinear.** All four patterns print. Rectilinear has the best
combination of print speed and printability, and it is what every number here was measured
on. See [PATTERNS.md](PATTERNS.md).

## Why the nozzle matters most

A smaller tip flat seals a smaller cell. Smaller cells win twice, because every tube gets
the same 1.5 s budget whatever its size, so more of them puts more plastic into the part:

| Nozzle tip flat | Smallest tube | Reinforcement per mm² |
|---|---|---|
| 1.00 mm | 1.03 mm | 3.08 mm³ |
| 1.40 | 1.32 | 2.27 |
| 1.75 | 1.56 | 1.79 |
| 2.00 | 1.74 | 1.55 |

A 1.0 mm flat delivers roughly twice the reinforcement of a 2.0 mm one. If you want more out
of Magma than your settings give, a nozzle with a smaller shoulder beats every software
setting here.

That table assumes each tube fills to the full budget, which for a small cell means a tall
narrow channel: a 1.05 mm cell would need to be 9 mm tall. That shape is the one most at
risk from the freezing problem above, so read the right-hand column as an upper bound rather
than a measured result.

## Symptoms

| What you see | Cause | Fix |
|---|---|---|
| Plastic smeared on the top surface, tubes under-filled | Seal leaking, or melt froze partway down and backpressure pushed it out. These look identical | Check seal depth is above 0.4 mm and re-measure the flat. If the seal is comfortable, the tube is probably too tall |
| Lattice around injection points deformed | Injection too long | Less volume per tube: height first, then width |
| Leaks and deformation together | Injection much too long | The wall softened and took the seal with it. Cut height hard |
| Blobs dragged across the plate | Ooze from over-long injections elsewhere | One bad object contaminates a whole plate. Fix the worst first |
| Prints fine, reinforcement feels thin | Tubes larger than they need to be | Each tube gets the same time budget whatever its size, so smaller cells put more in. Reduce width before height |

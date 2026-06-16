# How Magma works

This is the mechanism in more detail than the [README](README.md), without the math. For the full algorithms and the physics model, see the [defensive publication](DEFENSIVE_PUBLICATION.md). For the tube solver specifically, see [DESIGN-TUBE-SOLVER.md](DESIGN-TUBE-SOLVER.md).

## The lattice

Magma replaces normal infill with a triangle lattice that forms hollow U-shaped vertical channels. These channels are injected at calculated intervals, "knitting" the part together with a 3D lattice. Each triangular cell is a vertical tube. Tubes are paired with their "neighbors" at specified points where "windows" are formed between them. These windows become the bottom of the U-shaped channel, allowing plastic to flow from one side of the tube pair to the other when the nozzle is pressed down onto one of the pairs' tube tops.

The infill itself is a modified version of triangle infill. With additional logic for calculating neighboring pairs, ensuring min and max tube height bounds, drawing "windows" at the bottom of assigned tube pairs for injection, and injection code for when the layer reaches the top of each tube. Additionally, there's special rendering code so you can view the tubes and injection process in the slice preview.

![One printed layer, top down](assets/screenshots/01-triangle-infill-windows.png)

*The orange triangle grid is the Magma zone. Hexagonal gaps are windows.*

## U-tubes and windows

A solver pairs each triangle cell with an edge sharing neighbor and removes a short section of their shared wall at the bottom, leaving a window. The pair becomes a U: two vertical tubes joined at the base.

During injection the nozzle seals against the top of one tube and pushes plastic in. It flows down that side, through the window, and up the partner. Air escapes out the partner's open top. The window is auto-sized to be at least as wide as the tube, so it never bottlenecks the flow.

![The windows from inside the part](assets/screenshots/02-tube-windows.png)

*Every paired cell has a gap in its shared wall, so plastic flows from one tube into its partner.*

## Staggering (the solver)

If every tube started and ended on the same layers, their ends would line up into a weak horizontal plane, the exact problem Magma is trying to fix. So the solver staggers tube ends across Z, and pairs cells to reinforce as much of the part as possible.

There are two solver modes. Basic is a fast greedy pass (about a second) that covers most of the part. Refined adds a constraint solver (CP-SAT) that improves coverage and stagger at a large time cost, worth it mainly on complex models. The details are in [DESIGN-TUBE-SOLVER.md](DESIGN-TUBE-SOLVER.md).

## Dual Infill Zones

Solid fill is heavy and slow. And most of it doesn't contribute much to part strength. The "shell" of the object is where stress is concentrated, and what gives it strength. 

Existing solutions are varying forms of manual "parts hollowing". This is annoying and creates problems like supports being printed in the part interior.

A better solution is automatic hollowing. A thin shell between the inner and outer zones lets you assign a different infill type to each.

Magma currently supports such a "dual zone" infill. With Magma outer shell, and user selectable inner "yolk". This allows the use of a lightweight infill like lightning in the inner yolk while preserving part strength via the solid Magma outer zone. 

![Cutaway after slicing](assets/screenshots/03-dual-zone.png)

*Red Magma tubes form the outer zone around a solid blue inner zone. The band between them is the zone-boundary shell.*

Press **J** in the preview to toggle the zone-boundary overlay, which shows the computed inner-zone region (raw and smoothed). It is useful for checking how the zones split on complex models.

![Zone boundary overlay](assets/screenshots/05-zone-boundary-overlay.png)

*The J overlay shows the computed inner zone, handy for diagnosing zone splitting.*

## Spiral interlock (optional, off by default)

With spiral interlock on, the whole lattice rotates slightly each layer, so tubes follow helical paths instead of straight columns. The idea is extra mechanical grip against the surrounding walls. I have not measured whether it actually helps, and it has a real cost: the spiral widens each tube's footprint, so fewer full tubes fit, especially in thin sections. Leave it off unless you are specifically testing it.

![Spiral interlock](assets/screenshots/06-spiral-interlock.png)

*Spiral interlock makes the tubes helical instead of vertical.*

## The injection sequence

Injection runs as the print climbs, not all at the end. At the right height the printer parks motion, drops the nozzle onto a tube top, presses down to seal (z-slam), extrudes the calculated volume, lifts, and moves to the next. With a dedicated injection filament it can switch to a second extruder and material first. Temperature changes during injection use safe parking so the nozzle does not ooze on the part.

![Mid-print injection](assets/screenshots/04-injection-paths.png)

*Each red column is one injection event.*

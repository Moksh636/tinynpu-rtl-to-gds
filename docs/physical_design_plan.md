# Physical-Design Exploration Plan

> **Status:** Future scope. `v0.2.0-alpha` performs only RTL simulation, lint,
> and a Yosys synthesizability check. It does not claim placed-and-routed GDS.

## Goals

- Establish synthesis area and timing for the one-MAC baseline
- Implement the accelerator through OpenLane/OpenROAD
- Record area, worst slack, clock target, and estimated power
- Compare one-MAC, 2x2-MAC, and 4x4-MAC architectures
- Document throughput-versus-PPA tradeoffs

## Planned Flow

1. Freeze a synthesizable top-level interface.
2. Add clock and IO constraints.
3. Run Yosys synthesis and archive statistics.
4. Run floorplanning, placement, clock-tree synthesis, and routing.
5. Run timing and design-rule checks.
6. Archive reproducible configuration and reports.
7. Compare architectures using the same process and constraints.

## Required Evidence

A future physical-design milestone should include:

- Tool and PDK versions
- Configuration files and commands
- Synthesized cell count and area
- Core utilization
- Target and achieved clock frequency
- Worst setup and hold slack
- Estimated power with stated assumptions
- Congestion or DRC summary
- Layout screenshots

Until this evidence exists, project descriptions should use “RTL-to-synthesis
checks” rather than claiming a completed RTL-to-GDS implementation.

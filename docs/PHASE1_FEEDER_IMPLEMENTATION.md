# Phase 1 — Three-Phase Unbalanced Feeder Model Implementation

This package implements Phase 1 of the EV Hosting Capacity and Power Quality DSM project.

## Implemented files

- `src/feeder/build_feeder_network.m`
- `src/feeder/bfs_power_flow.m`
- `src/feeder/compute_pq_indices.m`
- `src/feeder/assign_households.m`
- `tests/test_phase1_feeder.m`
- `tests/test_bfs_power_flow.m`
- `tests/test_pq_indices.m`

## Scope

The implementation builds a deterministic radial three-phase four-wire LV feeder from `config/feeder_params.json`, assigns 100 households to transformer zones, buses, and phases, solves unbalanced power flow with backward-forward sweep, and computes the Phase 1 PQ index set.

## Notes

- Source branches include transformer leakage impedance in series with the first LV branch.
- Neutral conductor voltage drop is included in the BFS forward sweep.
- THDv, THDi, and K-factor are kept as numeric placeholders in Phase 1 because harmonic source spectra are introduced later by the EV/appliance models.
- The PQ result struct intentionally avoids NaN values so validation gates can run cleanly.

## Validation

Run:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

Expected Phase 1 validation coverage:

- Feeder construction from JSON
- Household zone, phase, bus, and EV assignment
- Balanced-load BFS convergence
- Balanced-load VUF near zero
- 30% phase-A unbalance gives measurable VUF and neutral current
- No-load bus voltages equal source voltage
- Heavy end-of-feeder loading produces voltage drop
- PQ indices are numeric and contain no NaN/Inf values

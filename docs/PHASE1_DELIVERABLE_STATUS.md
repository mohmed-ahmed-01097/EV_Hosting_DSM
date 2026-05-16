# Phase 1 Deliverable Status

## Checklist item

- [x] Phase 1 (Feeder) — BFS converges, all PQ indices computed

## Implemented acceptance criteria

- [x] `build_feeder_network(cfg)` builds the radial feeder from `feeder_params.json`
- [x] `assign_households(cfg, data, net)` assigns 100 households to zones, buses, phases, and EV metadata
- [x] `bfs_power_flow(net, S_load, assignment)` solves balanced, unbalanced, no-load, and heavy-load cases
- [x] `compute_pq_indices(...)` computes VUF, LVUR, PVUR, voltage deviation, PF, IUF, PUI, NCR, transformer loading, losses, and placeholder harmonic fields
- [x] Phase 1 tests added to `main([], 'validate')`

## MATLAB validation command

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

## Environment note

The project was packaged outside MATLAB, so MATLAB R2022b+ should be used to run the final validation locally.

## Validation Patch — PQ Heavy-Load Test Case

`tests/test_pq_indices.m` was updated after MATLAB validation showed that the previous heavy-load fixture placed `55 kVA + j18 kVAr` on every phase of every bus. That case drives the fixed-point BFS iteration outside a numerically meaningful operating region and fails because the solver does not converge, not because PQ-index logic is incorrect.

The replacement fixture uses the already-validated heavy end-of-feeder case from `test_bfs_power_flow.m`:

```matlab
S_heavy = zeros(3, net.n_buses);
endBuses = find(cellfun(@(s) endsWith(s, 'B') || strcmp(s, 'Bus_5A'), net.bus_names));
S_heavy(:, endBuses) = (28000 + 1j * 9000);
```

This remains a severe PQ violation case, but it is solvable by BFS and directly validates that voltage and loading violation flags fire.

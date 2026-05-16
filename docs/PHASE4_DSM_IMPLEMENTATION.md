# Phase 4 DSM Controller Implementation

This package implements Phase 4 of the EV Hosting Capacity and PQ thesis project.

## Implemented modules

| File | Purpose |
|---|---|
| `src/dsm/build_milp_problem.m` | Builds household-level DSM MILP matrices. |
| `src/dsm/run_household_milp.m` | Solves the household schedule using `intlinprog` when available. |
| `src/dsm/rule_based_controller.m` | Deterministic fallback scheduler for environments without Optimization Toolbox or infeasible MILP cases. |
| `src/dsm/v2g_scheduler.m` | EV charging and V2G heuristic helper. |
| `src/dsm/comfort_index.m` | Comfort index calculation. |
| `src/dsm/feeder_supervisor.m` | Hierarchical feeder-level coordination loop. |

## Design notes

- The MILP encodes controllable appliance start variables, EV charging power, V2G discharge power, SOC dynamics, SOC target, comfort penalty, and optional household power headroom constraints.
- The controller uses `intlinprog` if available. If the solver is unavailable or infeasible, it falls back to `rule_based_controller` so validation and future scenario work can continue.
- `feeder_supervisor` schedules households, assembles three-phase feeder loads, runs BFS, computes PQ indices, identifies violating time steps, and tightens affected household limits for up to `cfg.dsm.max_coordination_iterations`.

## Validation

Run:

```matlab
main([], 'validate')
```

Phase 4 validation includes:

- Single-appliance preferred-time scheduling.
- Non-overlap behavior for two controllable appliances.
- EV SOC target satisfaction.
- V2G discharge/SOC reserve behavior.
- Household power limit enforcement.
- Feeder supervisor smoke test with BFS and PQ summary.

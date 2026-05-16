# Phase 4 - DSM Controller

Implemented files:

- `build_milp_problem.m` - constructs the household DSM MILP matrices for `intlinprog`.
- `run_household_milp.m` - solves the household DSM problem and falls back to a deterministic rule-based controller if needed.
- `rule_based_controller.m` - heuristic scheduling fallback for controllable appliances and EV charging.
- `v2g_scheduler.m` - deterministic EV/V2G scheduling helper.
- `comfort_index.m` - computes aggregate and per-appliance comfort scores.
- `feeder_supervisor.m` - hierarchical feeder-level coordination loop with BFS/PQ checks.

Validation files:

- `tests/test_milp.m`
- `tests/test_phase4_dsm.m`

Run:

```matlab
main([], 'validate')
```

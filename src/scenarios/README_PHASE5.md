# Phase 5 - Scenario Execution Layer

This folder implements the seven thesis scenarios plus Baseline 0.

## Implemented runners

```text
run_baseline0.m   - Baseline 0: no EVs, no DSM
run_scenario0.m   - No EVs, rule-based DSM
run_scenario1.m   - Uncontrolled EV integration
run_scenario2.m   - Slow vs fast uncontrolled EV charging comparison
run_scenario3.m   - MILP-controlled EV only
run_scenario4.m   - MILP-controlled household loads + EV
run_scenario5.m   - MILP-controlled household loads + EV + V2G
run_scenario6.m   - Full hierarchical AI-DSM using feeder_supervisor
run_all_scenarios.m
run_scenario_core.m
```

## Result struct

Each scenario returns a `results` struct with the Phase 5 contract fields:

```text
scenario_id
description
pq_summary
pq_timeseries
costs
hosting_capacity_pct
comfort_summary
L_feeder_w
runtime_s
```

Additional diagnostic fields are also stored:

```text
L_house_w
S_series
schedules
metadata
comparison   % Scenario 2 only
```

## Notes

- The shared `run_scenario_core.m` avoids duplicated scenario logic.
- EV charging is injected in Phase 5 because Phase 2 intentionally generates EV metadata, not scheduled EV power.
- Scenario 6 calls the Phase 4 `feeder_supervisor` for hierarchical DSM coordination.
- Hosting capacity is a representative-step screening estimate. Full thesis runs can refine it by evaluating all time steps and Monte Carlo seeds.

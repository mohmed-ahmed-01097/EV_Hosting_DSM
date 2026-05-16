# Phase 5 Implementation - Scenario Execution

Phase 5 implements the thesis scenario layer. It connects the already implemented population load model, feeder model, pricing engine, and DSM controllers into comparable scenario result structs.

## Files added

```text
src/scenarios/run_baseline0.m
src/scenarios/run_scenario0.m
src/scenarios/run_scenario1.m
src/scenarios/run_scenario2.m
src/scenarios/run_scenario3.m
src/scenarios/run_scenario4.m
src/scenarios/run_scenario5.m
src/scenarios/run_scenario6.m
src/scenarios/run_all_scenarios.m
src/scenarios/run_scenario_core.m
tests/test_phase5_scenarios.m
```

## Scenario mapping

| Runner | Scenario | EV charging | DSM | V2G |
|---|---:|---|---|---|
| `run_baseline0` | Baseline 0 | None | None | No |
| `run_scenario0` | 0 | None | Rule-based | No |
| `run_scenario1` | 1 | Uncontrolled | None | No |
| `run_scenario2` | 2 | Slow vs fast uncontrolled | None | No |
| `run_scenario3` | 3 | MILP EV only | EV scheduling | No |
| `run_scenario4` | 4 | MILP | Load + EV MILP | No |
| `run_scenario5` | 5 | MILP | Load + EV MILP | Yes |
| `run_scenario6` | 6 | Supervised MILP | Feeder supervisor | Yes |

## Design choices

1. A shared scenario core avoids seven independent implementations of feeder assembly, PQ evaluation, costs, and hosting-capacity reporting.
2. EV charging power is injected at scenario level, because Phase 2 creates household EV metadata and deliberately does not add EV charging power to the base household profile.
3. Rule-based, MILP, and supervised DSM scenarios reuse the Phase 4 controllers.
4. Scenario 2 stores both top-level mixed-charger results and an explicit slow/fast comparison under `results.comparison`.
5. Hosting capacity is implemented as a deterministic representative-step screening estimate. It evaluates EV penetration from 0% to 50% in 5% increments, stopping at the first PQ violation.

## MATLAB usage

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'scenario', 4)       % run Scenario 4 only
main([], 'scenarios', [-1 1 4 6])
main([], 'all_scenarios')
```

Scenario results are saved by `main` to:

```text
results/scenario_results.mat
```

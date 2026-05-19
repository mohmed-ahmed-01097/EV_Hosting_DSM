# Phase 5 Lean Results Test Fix

## Issue

`test_phase5_scenarios.m` still expected full/debug scenario fields such as:

- `L_house_w`
- `S_series`
- `schedules`

These fields are intentionally removed by the lean results policy to prevent very large `scenario_results.mat` files.

## Fix

The Phase 5 test is now lean-results compatible:

- Compares Scenario 1 energy against baseline using `L_feeder_w` instead of `L_house_w`.
- Validates Scenario 4 matrix shape using `L_feeder_w` as `T x 3`.
- Validates Scenario 5/6 via `comfort_summary` and `pq_summary`, not stored schedules.
- Explicitly keeps `cfg.results.storage_mode = 'lean'` during the test so regressions are caught.

## Expected Validation

Run:

```matlab
main([], 'validate')
```

Expected result:

```text
[test_phase5_scenarios] Complete. Phase 5 scenario validation passed.
```

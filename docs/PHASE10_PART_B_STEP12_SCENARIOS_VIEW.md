# Phase 10 PART B Step 12 — Scenarios View + Sequential Runner

## Scope

This step implements the Scenarios view described in the Phase 10 Bug Fixes + MATLAB App Designer UI plan.

Step 12 includes:

- Scenario card row for Baseline 0 and Scenarios 0–6
- Scenario selection checkboxes
- Active scenario detail selector
- Run This, Run Selected, Stop, and Reset buttons
- Live execution progress label
- Scenario-specific timestamped log
- Live/last three-phase feeder-load preview using lean `L_feeder_w`
- Sequential scenario dispatch with `drawnow('limitrate')`
- Result storage to `results/scenario_results.mat`
- Script/test helper `run_scenarios_sequential.m`

## Important design decision

The App class uses private methods for UI-state access. Therefore, the external helper:

```matlab
src/ui/app_helpers/run_scenarios_sequential.m
```

is implemented as a **struct-context helper** for scripts, tests, and future wrappers. The App itself uses its own private sequential runner so it can safely access private UI handles and private state.

## Files updated

```text
src/ui/EVHostingDSM_App.m
src/ui/app_helpers/run_scenarios_sequential.m
tests/test_part_b_step12_scenarios_view.m
tests/run_config_tests.m
```

## Validation

Run only this step:

```matlab
test_part_b_step12_scenarios_view()
```

Run full validation:

```matlab
main([], 'validate')
```

## UI launch

```matlab
launch_app()
```

Then open the **Scenarios** sidebar card and use:

- `Run This` to run the dropdown scenario
- `Run Selected` to run checked scenario cards
- `Stop` to stop after the current scenario finishes
- `Reset` to clear scenario status cards/logs

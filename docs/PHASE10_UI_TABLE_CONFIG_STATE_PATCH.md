# Phase 10 UI Patch — Tables, Config Controls, and Persisted Test State

This patch improves the MATLAB UI after visual review of the dashboard, scenario, results, export, load, pricing, and tests screens.

## Changes

- Added `src/ui/app_helpers/style_app_table.m` so UI tables use the same dark professional theme as the plot axes.
- Applied the table style to scenario/result/test/config-related tables.
- Replaced the Config group's old advanced key/value table behavior with a dynamic editor panel that rebuilds text boxes, numeric fields, checkboxes, and sliders when the selected group changes.
- Added persisted UI test state with a `LastRunAt` timestamp column in `results/tables/ui_test_report.csv`.
- The Tests view now reloads the previous test report on app startup/reopen instead of resetting to all queued rows.
- Removed a duplicated `createComponents(app)` constructor call.

## User-facing behavior

- Tables now visually match the dark plot style.
- Selecting `Simulation`, `EV Parameters`, `PQ Limits`, `DSM Controller`, `Pricing`, or `HVAC` updates a dynamic editor area with controls instead of a table.
- Previous UI test results, including date/time of the last run, are restored when the app opens again.

## Validation

```matlab
run startup.m
test_part_b_ui_table_config_state_patch()
```

# Phase 9 - Main Entry Point and Results Export

Phase 9 finalizes the project runner and thesis-ready CSV export path.

## Added files

- `src/io/export_results_tables.m`
- `tests/test_phase9_main_export.m`

## Updated files

- `src/main.m`
- `tests/run_config_tests.m`

## Exported tables

Scenario execution now writes MATLAB results and CSV tables under the dynamic project results folder:

```text
<project_root>/results/scenario_results.mat
<project_root>/results/tables/scenario_summary.csv
<project_root>/results/tables/scenario_cost_summary.csv
<project_root>/results/tables/scenario_comfort_summary.csv
<project_root>/results/tables/scenario_violations.csv
<project_root>/results/tables/deliverables_checklist.csv
```

## Main commands

```matlab
main([], 'validate')
main([], 'scenario', 4)
main([], 'scenarios', [-1 1 4 6], 'plot')
main([], 'all_scenarios')
```

`main([], 'all_scenarios')` now runs the scenario layer, saves `scenario_results.mat`, exports thesis tables, and generates figures when multiple scenarios are executed.

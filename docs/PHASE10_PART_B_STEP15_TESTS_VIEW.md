# Phase 10 PART B — Step 15 Tests View

## Scope

This step implements the interactive Tests view for the MATLAB UI.
It follows the Phase 10 plan requirement for a Tests page with:

- Run All Tests
- Run Selected
- Clear Results
- A status table
- A details panel
- A progress indicator
- A saveable CSV test report

## Added files

```text
src/ui/app_helpers/app_test_runner.m
src/ui/app_helpers/appDefaultTestNames.m
tests/test_part_b_step15_tests_view.m
```

## Updated files

```text
src/ui/EVHostingDSM_App.m
tests/run_config_tests.m
README.md
```

## UI behavior

The Tests view exposes a validation table with columns:

```text
Run | Test | Status | Time_s | Last result
```

The user can check or uncheck tests and run either the full list or only selected rows.
Each test is executed sequentially on the main MATLAB thread. This is compatible with compiled applications because it avoids `parfeval`, `parfor`, and background workers.

The app updates progress using:

```matlab
drawnow('limitrate')
```

## Output

The Save Test Report button writes:

```text
results/tables/ui_test_report.csv
```

## Validation

Run:

```matlab
cd EV_Hosting_DSM
run startup.m
test_part_b_step15_tests_view()
```

Or:

```matlab
main([], 'validate')
```

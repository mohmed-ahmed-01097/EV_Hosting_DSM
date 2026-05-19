# Phase 10 PART A - Bug Fixes Implemented

This package implements the mandatory PART A bug fixes from `EV_DSM_BugFix_and_UI_Prompt.md` before starting the MATLAB App Designer UI.

## Completed fixes

1. Added `cfg.dsm.lambda_comfort` and `cfg.dsm.comfort_ci_threshold`.
2. Updated neutral conductor modeling to read `conductors.neutral.multiplier` from `feeder_params.json`.
3. Added `cfg.ev.v2g_revenue_fraction` and replaced the hardcoded 50% V2G revenue coefficient.
4. Added compiled-app-safe `progress_cb` hooks and `drawnow('limitrate')` to long-running simulation paths.
5. Added `compute_harmonic_pq.m` and integrated EV harmonic THDi, THDv, and K-factor calculation in scenario PQ evaluation.
6. Added `sensitivity_analysis.m` and `monte_carlo_runner.m` under `src/uq/`.
7. Reworked Scenario 2 to return separate `results.slow` and `results.fast` sub-results.
8. Added compiled-app-safe path helper `src/ui/app_helpers/get_root_dir.m` and updated `config_loader.m` output behavior for deployed apps.

## Validation

Run:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

Or run the targeted check only:

```matlab
test_part_a_bug_fixes()
```

## Scope note

PART B UI implementation is intentionally not included in this package. The code now has the hooks needed by the UI: progress callbacks, compiled-safe paths, UQ files, harmonic KPIs, and Scenario 2 sub-results.

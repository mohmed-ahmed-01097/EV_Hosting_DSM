# Phase 10 PART B — Step 9 UI Scaffold Implemented

## Scope

This package implements **Step 9 only** from PART B:

> APP -> create `src/ui/` folder structure + `app_helpers/`

The uploaded Phase 10 plan defines the UI as a dashboard-first MATLAB App Designer application with a left sidebar, live progress feedback, embedded plots, pop-out figures, English-only labels, and compiled `.exe` compatibility.

## Added structure

```text
src/ui/
├── launch_app.m
├── build_exe.m
├── README_PHASE10_STEP9.md
└── app_helpers/
    ├── get_root_dir.m
    ├── app_theme.m
    ├── app_log.m
    ├── app_kpi_gauges.m
    ├── app_feeder_plot.m
    ├── app_load_profile_plot.m
    ├── app_scenario_comparison.m
    ├── app_popout_plot.m
    ├── app_export_helper.m
    └── run_scenarios_sequential.m
```

## Intentional exclusions

`EVHostingDSM_App.mlapp` is **not** created in Step 9. It belongs to Step 10.

`launch_app.m` and `build_exe.m` are included as guarded scaffold files. They produce clear errors until the actual App Designer class exists.

## Validation

Run:

```matlab
main([], 'validate')
```

or:

```matlab
test_part_b_step9_ui_structure()
```

## Next step

PART B Step 10: build `EVHostingDSM_App.mlapp` class skeleton.

# Phase 10 PART B — Step 9 UI Scaffold

This folder contains the MATLAB App Designer UI scaffold for the EV Hosting DSM simulator.

Step 9 scope:

- Create `src/ui/`.
- Create `src/ui/app_helpers/`.
- Add compiled-safe helper functions used by the future App Designer class.
- Add `launch_app.m` and `build_exe.m` placeholders with clear Step 10/Step 16 guard errors.

Step 9 intentionally does **not** implement `EVHostingDSM_App.mlapp`. That belongs to Step 10.

## Helper files

- `get_root_dir.m`
- `app_theme.m`
- `app_log.m`
- `app_kpi_gauges.m`
- `app_feeder_plot.m`
- `app_load_profile_plot.m`
- `app_scenario_comparison.m`
- `app_popout_plot.m`
- `app_export_helper.m`
- `run_scenarios_sequential.m`

## Validation

Run:

```matlab
main([], 'validate')
```

or:

```matlab
test_part_b_step9_ui_structure()
```

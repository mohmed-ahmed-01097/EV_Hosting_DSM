# Phase 10 PART B — Step 10 App Skeleton

## Scope

This package implements **PART B — Step 10** from the Phase 10 plan: the dashboard-first App Designer-compatible app class skeleton.

Step 10 creates the app shell only. Detailed controls for Dashboard, Config, Feeder, Load, Pricing, Scenarios, Results, Export, and Tests are implemented in later UI steps.

## Added

```text
src/ui/EVHostingDSM_App.m
tests/test_part_b_step10_app_skeleton.m
```

## Updated

```text
src/ui/launch_app.m
src/ui/build_exe.m
tests/run_config_tests.m
README.md
```

## Design decision

The UI skeleton is implemented as a programmatic `matlab.apps.AppBase` class in:

```text
src/ui/EVHostingDSM_App.m
```

This keeps the app source reviewable, diff-friendly, and editable in this phase. MATLAB can still launch it with:

```matlab
launch_app()
```

and the compiler helper now supports either:

```text
EVHostingDSM_App.mlapp
EVHostingDSM_App.m
```

When the final App Designer binary `.mlapp` is produced inside MATLAB, `build_exe.m` will prefer the `.mlapp` automatically.

## Implemented skeleton features

- Main `uifigure`
- Left sidebar card navigation
- Nine content panels
- Dashboard placeholder view
- Status bar
- Text execution log
- Progress indicator
- Project startup initialization
- Config, survey, weather, feeder, and assignment loading
- Safe `drawnow('limitrate')` UI refresh calls
- `launch_app()` now constructs the class
- `build_exe()` supports `.m` AppBase class and `.mlapp`

## Validation

Run:

```matlab
cd EV_Hosting_DSM
run startup.m
test_part_b_step10_app_skeleton()
```

Or full validation:

```matlab
main([], 'validate')
```

## Launch

```matlab
launch_app()
```


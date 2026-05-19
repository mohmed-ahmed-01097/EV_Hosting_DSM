# Phase 10 PART B Step 10 — App Skeleton

This folder now includes the first executable dashboard-first UI class:

```text
EVHostingDSM_App.m
```

The class inherits from `matlab.apps.AppBase` and creates:

- Main `uifigure`
- Left sidebar card navigation
- Nine content panels
- Dashboard status cards
- Feeder mini-map placeholder
- Quick action buttons
- Persistent status bar
- Progress indicator
- Execution log

Launch:

```matlab
run startup.m
launch_app()
```

Compile helper:

```matlab
build_exe()
```

`build_exe.m` supports both `EVHostingDSM_App.mlapp` and the current programmatic `EVHostingDSM_App.m` file.

Step 10 does not yet implement the detailed controls for each view. Those belong to Steps 11 through 15.

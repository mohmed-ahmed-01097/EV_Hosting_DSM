# Phase 10 PART B - Step 14 Export View

Step 14 adds the Export view to `EVHostingDSM_App.m` and expands `app_export_helper.m`.

The Export view supports:

- Selected or all thesis figure export
- PNG/EPS/SVG format selection
- CSV scenario table export
- LaTeX `.tex` report generation
- Dynamic output folder selection

Launch:

```matlab
run startup.m
launch_app()
```

Validate:

```matlab
test_part_b_step14_export_view()
```

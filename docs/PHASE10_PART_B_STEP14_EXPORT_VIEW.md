# Phase 10 PART B - Step 14 Export View

This package implements the Export view specified in the Phase 10 UI plan.

## Implemented UI areas

- Figure export card with thesis figure checkboxes
- PNG, EPS, and SVG format selection
- Dynamic export folder path derived from `cfg.output_dir`
- CSV/table export card
- LaTeX thesis report card
- Export log/status text areas

## Implemented callbacks

- `onExportSelectedFigures(app)`
- `onExportAllFigures(app)`
- `onExportSelectedCsv(app)`
- `onGenerateLatexReport(app)`
- `onBrowseExportFolder(app)`
- `refreshExportView(app)`

## Helper updates

`src/ui/app_helpers/app_export_helper.m` now supports:

- `figures_selected`
- `tables_selected`
- `latex_report`
- legacy single figure/table export modes

The helper remains lean-result compatible and does not require huge debug fields such as `L_house_w`, `S_series`, or full `pq_timeseries`. It uses retained fields such as `pq_summary`, `costs`, `comfort_summary`, `hosting_capacity_pct`, and `L_feeder_w`.

## Output folders

Exports go to dynamic project paths:

```text
<project_root>/results/figures/png
<project_root>/results/figures/eps
<project_root>/results/figures/svg
<project_root>/results/tables
<project_root>/results/thesis_results_report.tex
```

## Validation

Run:

```matlab
test_part_b_step14_export_view()
```

Or:

```matlab
main([], 'validate')
```

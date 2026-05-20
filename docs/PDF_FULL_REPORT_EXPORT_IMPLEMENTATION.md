# PDF Full Report Export Implementation

This patch adds a full PDF report export path for the EV Hosting DSM UI.

## New capability

The Export page now includes **Generate PDF Report**. The generated report includes:

- Modern cover page
- Used configuration summary
- Scenario KPI table
- Cost and comfort table
- Scenario comparison plots
- Hosting capacity plot
- Load-profile plot when `L_feeder_w` is retained
- Voltage and cost plots
- Appendix with output paths and scenario descriptions

## Output path

Reports are written to:

```text
<project_root>/results/reports/ev_dsm_full_scenario_report.pdf
```

or to the selected export folder when the user changes the export destination in the UI.

## Implementation files

```text
src/ui/app_helpers/app_pdf_report.m
src/ui/app_helpers/app_export_helper.m
src/ui/EVHostingDSM_App.m
tests/test_part_b_pdf_export_report.m
```

## Usage

From the UI:

1. Run one or more scenarios.
2. Open Export.
3. Confirm the export folder.
4. Click **Generate PDF Report**.

From MATLAB:

```matlab
outFile = app_pdf_report(all_results, cfg, struct('name','ev_dsm_full_scenario_report'));
```

Or through the helper dispatch:

```matlab
outFile = app_export_helper('pdf_report', all_results, cfg, opts);
```

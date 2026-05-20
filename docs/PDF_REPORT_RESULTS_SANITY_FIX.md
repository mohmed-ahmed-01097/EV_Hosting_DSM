# PDF Report and Results Sanity Fix

## Purpose
This patch addresses two issues observed in the generated `ev_dsm_full_scenario_report.pdf`:

1. **PDF layout problems**: the cover page placed too much content on one page, and some plots used ambiguous axes or labels.
2. **Unrealistic scenario results**: the no-EV baseline was already infeasible, with very low voltage and transformer overload. That makes every EV hosting-capacity result collapse to 0%.

## Root cause
The root cause is not the PDF export alone. The generated report showed that Baseline 0 already had `Vmin = 0.839 pu` and `Max TL = 187.6%`. This means the survey-derived household population was too coincident/heavy for the configured feeder before any EV charging was added.

The most likely modeling causes are:

- high summer HVAC coincidence from the legacy survey conversion,
- small transformer ratings in some zones, especially the 63 kVA transformer,
- synchronized DSM rebound in rule-based/MILP schedules without a local peak guard,
- cost fields being annual totals while the old PDF labels were not explicit.

## Implemented fixes

### 1. Feeder-aware base-load calibration
`run_scenario_core.m` now calibrates the behavior-driven base load before EV stress is added.

- EV charging power is **not** scaled.
- Calibration targets are configurable in `config/default_config.json`.
- The calibration factor is stored in scenario metadata through the normal run path.

### 2. DSM local peak guard
Rule-based and MILP scheduling now include a local household peak guard when no feeder limit is supplied. This reduces synchronized rebound peaks.

### 3. PDF report redesign
The PDF report now includes:

- a clean cover page,
- automatic results-review page,
- explicit annual-vs-monthly bill labels,
- improved plot axis scaling,
- warnings when baseline feasibility or hosting-capacity results are suspicious.

## Files changed

- `config/default_config.json`
- `src/scenarios/run_scenario_core.m`
- `src/dsm/rule_based_controller.m`
- `src/dsm/run_household_milp.m`
- `src/ui/app_helpers/app_pdf_report.m`
- `tests/test_pdf_report_and_results_sanity_patch.m`
- `tests/run_config_tests.m`

## Required action
Delete or archive old scenario results before re-running, because old reports are based on pre-calibration results:

```matlab
delete(fullfile('results','scenario_results.mat'))
main([], 'all_scenarios')
```

Then generate the PDF again from the Export page.

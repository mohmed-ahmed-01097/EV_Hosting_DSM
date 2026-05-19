# Result Storage Size Fix

## Problem

A full annual all-scenario run can create a very large `scenario_results.mat` file if every internal object is saved. The biggest contributors are:

- `pq_timeseries`: one full PQ struct for every simulation step and scenario.
- `schedules`: household/day controller objects, especially MILP schedules.
- `L_house_w`: full household-level time-series for every scenario.
- `S_series`: full three-phase bus complex-power time-series.
- `costs.price_series`: repeated tariff vectors that are not needed for thesis tables.

A file around 13 GB is not suitable for the normal thesis workflow. It is only reasonable for a short debug run, not for annual scenario storage.

## Fix

The default `config/default_config.json` now includes a `results` storage policy. The default is `storage_mode = lean`.

Lean mode saves:

- scenario metadata
- `pq_summary`
- bills and monthly energy tables
- comfort summary
- hosting capacity estimate
- feeder-level phase load `L_feeder_w` in single precision
- visualization-ready comparison fields

Lean mode removes from saved scenario structs:

- full `pq_timeseries`
- full household matrix `L_house_w`
- full complex bus-load series `S_series`
- controller schedule objects
- repeated price-series vectors

## Usage

Recommended thesis run:

```matlab
main([], 'all_scenarios')
```

The output should now be much smaller and faster to save.

For debugging only, edit `config/default_config.json`:

```json
"results": {
  "storage_mode": "full"
}
```

Use full mode only for a short date range, for example a single day or week.

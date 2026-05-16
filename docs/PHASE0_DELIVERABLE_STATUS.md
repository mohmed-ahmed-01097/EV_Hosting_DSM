# Phase 0 Deliverable Status

Status: implemented.

## Completed

- `src/io/data_loader.m`
  - Loads all required workbook sheets.
  - Applies known column aliases.
  - Validates required columns.
  - Validates OccupancyPMF probability sums.
  - Validates activity start-bin percentages.
  - Validates EV charger type domain.
  - Caches loaded tables to `data/survey/Household_Energy_Survey.mat`.

- `src/io/daytype_calendar.m`
  - Returns all required calendar vectors.
  - Applies Egypt weekend rule: Friday/Saturday.
  - Applies Egyptian season labels.
  - Uses Egyptian holiday ICS if available, otherwise deterministic fallback dates.
  - Flags approximate Ramadan window.

- `src/io/get_weather.m`
  - Uses correct Assiut coordinates.
  - Loads cache if available.
  - Attempts NASA POWER hourly temperature API.
  - Falls back to deterministic synthetic Assiut temperature when API is unavailable.
  - Writes weather cache to `data/weather/`.

- `tests/test_phase0_io.m`
  - Validates Phase 0 gate conditions.

- `tests/run_config_tests.m`
  - Runs config validation, survey schema validation, and Phase 0 IO validation.

## MATLAB validation command

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

## Next phase

```text
Phase 1 — Three-Phase Unbalanced Feeder Model
```

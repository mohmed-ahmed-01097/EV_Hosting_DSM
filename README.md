# EV_Hosting_DSM MATLAB Project

This package implements the first project deliverable and **Phase 0 — Configuration & IO Layer**.

Implemented checklist items:

- [x] All config JSON files created and validated
- [x] Survey workbook prepared as a single final Phase 0 workbook
- [x] Phase 0 IO functions implemented and testable

## Included

- `EV_Hosting_DSM.prj` MATLAB project entry file
- `config/default_config.json`
- `config/feeder_params.json`
- `config/scenario_configs/baseline0.json`
- `config/scenario_configs/scenario0.json` through `scenario6.json`
- `data/survey/Household_Energy_Survey.xlsx`
- `src/io/config_loader.m`
- `src/io/data_loader.m`
- `src/io/daytype_calendar.m`
- `src/io/get_weather.m`
- `src/io/validate_feeder_params.m`
- `tests/test_config_loader.m`
- `tests/test_survey_schema.m`
- `tests/test_phase0_io.m`
- `tests/run_config_tests.m`
- documentation under `docs/`

## How to open

1. Extract the ZIP.
2. Open MATLAB R2022b or newer.
3. Open `EV_Hosting_DSM.prj`.
4. If MATLAB does not recognize the `.prj`, run:

```matlab
cd EV_Hosting_DSM
run startup.m
run setup/create_or_refresh_project.m
```

## How to validate Phase 0

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

or:

```matlab
run_config_tests()
```

Expected final result:

```text
[run_config_tests] Step 1 + Phase 0 IO deliverables are valid. You can now start Phase 1 feeder modeling.
```

## How to run Phase 0 manually

```matlab
cd EV_Hosting_DSM
run startup.m
main()
```

This loads:

1. Configuration
2. Survey data
3. Egyptian day-type calendar
4. Assiut weather data or synthetic fallback

Then it stops before Phase 1 feeder modeling.

## Survey data

The project uses a single normalized survey workbook:

```text
data/survey/Household_Energy_Survey.xlsx
```

No legacy workbook is included. The workbook contains all required Phase 0 sheets:

```text
Household
Residents
OccupancyPMF
Activities
Appliances
HVAC_Thermal
EV
```

## Next step

The next implementation task is:

```text
Phase 1 — Three-Phase Unbalanced Feeder Model
```


## Phase 1 implemented

The package now includes the Phase 1 feeder model:

- `build_feeder_network.m`
- `bfs_power_flow.m`
- `compute_pq_indices.m`
- `assign_households.m`
- Phase 1 validation tests

Run validation from MATLAB:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

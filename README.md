# EV_Hosting_DSM MATLAB Project

This package implements the first deliverable checklist item:

- [x] All config JSON files created and validated

Included:

- `EV_Hosting_DSM.prj` MATLAB project entry file
- `config/default_config.json`
- `config/feeder_params.json`
- `config/scenario_configs/baseline0.json`
- `config/scenario_configs/scenario0.json` through `scenario6.json`
- fixed `src/io/config_loader.m`
- feeder parameter validator
- configuration validation tests

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

## How to validate Step 1

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

or:

```matlab
run_config_tests()
```

Expected result:

```text
[run_config_tests] Step 1 deliverable is valid: config JSON files created and validated.
```

## Survey data

The Phase 0-ready survey file is included here:

```text
data/survey/Household_Energy_Survey.xlsx
```

The config loader resolves this path, and the survey schema test validates that the workbook contains the required Phase 0 sheets and columns.

## Survey workbook readiness

The project includes a single Phase 0-ready normalized survey workbook at `data/survey/Household_Energy_Survey.xlsx`. Run `main([], 'validate')` to validate both the configuration files and the survey schema before implementing `data_loader.m`.

# Phase 0 — Configuration & IO Layer Implementation

This package implements the Phase 0 IO layer required by the thesis implementation contract.

## Implemented functions

```text
src/io/config_loader.m
src/io/data_loader.m
src/io/daytype_calendar.m
src/io/get_weather.m
src/main.m
```

## Validation gate

The Phase 0 completion gate is:

```text
data_loader(cfg) runs without error
daytype_calendar(cfg) returns correct vectors
get_weather(cfg) returns temperature data or graceful fallback
```

Run this in MATLAB R2022b+:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

or run only the Phase 0 IO test:

```matlab
test_phase0_io()
```

## data_loader.m

`data_loader(cfg)` loads the single normalized survey workbook:

```text
data/survey/Household_Energy_Survey.xlsx
```

It validates the required sheets and columns, checks the OccupancyPMF probability sums, checks activity start-bin percentages, validates EV charger type values, prints row counts, and writes a cache file:

```text
data/survey/Household_Energy_Survey.mat
```

The returned struct fields are:

```text
data.household
data.residents
data.occ_pmf
data.activities
data.appliances
data.hvac
data.ev
data.meta
```

## daytype_calendar.m

`daytype_calendar(cfg)` creates simulation-time vectors and Egyptian calendar labels:

```text
0 = weekday
1 = weekend
2 = holiday
```

Egypt weekend rule:

```text
Friday and Saturday
```

Season rule:

```text
summer = June to September
winter = December to February
spring = March to May
autumn = October to November
```

It also flags Ramadan using an approximate lunar-date shift from the 2025 reference date.

## get_weather.m

`get_weather(cfg)` first checks the cache under:

```text
data/weather/
```

If cache is missing, it attempts NASA POWER hourly temperature download for Assiut using:

```text
latitude  = 27.1809
longitude = 31.1837
```

If the API is unavailable, it generates a deterministic synthetic Assiut temperature profile with realistic winter lows and summer peaks, then caches the result.

## Tests added

```text
tests/test_phase0_io.m
```

`tests/run_config_tests.m` now runs:

```text
test_config_loader()
test_survey_schema()
test_phase0_io()
```

## Current project boundary

This package completes Phase 0 only. The next implementation step is Phase 1:

```text
Three-phase unbalanced feeder model
```

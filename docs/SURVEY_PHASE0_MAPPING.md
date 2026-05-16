# Survey Workbook Prepared for Phase 0

This project contains a single Phase 0-ready survey workbook at:

```text
EV_Hosting_DSM/data/survey/Household_Energy_Survey.xlsx
```

The workbook is the normalized, model-facing survey file that should be used by `data_loader(cfg)`. It contains all sheets and columns required by the Phase 0 implementation contract. No separate legacy/original workbook is included in this package.

## Why normalization was needed

The old survey data used wider and more descriptive survey-template names such as:

```text
Dwelling_Type(flat/house/duplex/other)
Frequency_Unit(per_day/per_week)
AC_Present(0/1)
EV_Present(0/1)
WD_pHome_h00 ... WD_pHome_h23
```

The prepared workbook normalizes those fields into the required model-facing schema while preserving useful source fields as extra columns where helpful.

## Required Phase 0 sheets now available

| Sheet | Status | Notes |
|---|---:|---|
| `Household` | Ready | Includes `Household_ID`, `Dwelling_Type`, `Floor_Area_m2`, `Num_Residents`, `Income_Level` |
| `Residents` | Ready | Converts age bands to numeric age midpoints and maps work/school status |
| `OccupancyPMF` | Ready | Converted from wide weekday/weekend home and sleep probability columns to long format |
| `Activities` | Ready | Normalized activity names and exact Phase 0 start-bin columns |
| `Appliances` | Ready | Adds `Standby_W`, `Is_Controllable`, `Flexibility_Window_hr`, `Preferred_Start_hr` |
| `HVAC_Thermal` | Ready | Adds `AC_Power_kW` with 1.75 kW default where AC exists |
| `EV` | Ready | Includes `Has_EV`, `EV_Battery_kWh`, and `Charger_Type` |

## Important derivations

### Occupancy probabilities

The source survey had home and sleep probabilities. Phase 0 needs three mutually exclusive states:

```text
P_Away       = 1 - pHome
P_Asleep     = min(pSleep, pHome)
P_Home_Awake = pHome - P_Asleep
```

Every row is normalized so:

```text
P_Away + P_Home_Awake + P_Asleep = 1.0
```

### Day type coding

```text
0 = weekday
1 = weekend
2 = holiday, reserved for Phase 0 calendar logic
```

The workbook currently includes weekday and weekend PMFs. During Phase 0, holidays can reuse weekend PMFs unless a separate holiday survey profile is later added.

### Appliance controllability defaults

The following appliances are flagged as controllable for the DSM controller:

```text
Washing_Machine
Dishwasher
Water_Heater
Iron
```

Default flexibility windows were added from the implementation plan:

```text
Washing_Machine: 3 hr
Dishwasher:      3 hr
Water_Heater:    1 hr
Iron:            2 hr
```

### EV data

The prepared workbook contains EV rows with normalized `Has_EV`, `EV_Battery_kWh`, and `Charger_Type` fields. Battery size and charger type were derived conservatively from the available EV charging information:

```text
short duration  -> fast charger, 40 kWh
medium duration -> fast charger, 60 kWh
long duration   -> slow charger, 75 kWh
```

A small deterministic subset is marked `v2g` so Scenario 5 and Scenario 6 have valid V2G-capable rows available, while the project config can still assign EV penetration rates independently.

## Validation

Run this in MATLAB:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

This validates both:

1. Config JSON files and feeder parameters.
2. Survey workbook sheet names, required columns, occupancy probability sums, activity bin sums, and EV charger type domain.

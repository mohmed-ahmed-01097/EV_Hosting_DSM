# Phase 2 - Behavior-Driven Load Model Implementation

This package implements the Phase 2 behavior-driven load model required by the master implementation prompt.

## Implemented modules

| File | Purpose |
|---|---|
| `src/models/simulate_occupancy.m` | Generates Away/Home-Awake/Asleep state sequences from OccupancyPMF rows. |
| `src/models/generate_activities.m` | Converts survey activity frequencies and timing bins into daily events. |
| `src/models/trigger_appliances.m` | Maps activities to appliance runs. |
| `src/models/run_appliance_profile.m` | Generates appliance finite-state power profiles. |
| `src/models/discretize_runs_to_power.m` | Converts appliance runs into dense power vectors. |
| `src/models/hvac_power_model.m` | Computes Egyptian summer/winter HVAC demand using outdoor temperature and occupancy. |
| `src/models/ev_model.m` | Generates EV availability, SOC metadata, charger limits, and harmonic spectrum. |
| `src/models/extract_flexibility.m` | Exposes controllable load windows for later DSM phases. |
| `src/models/simulate_household.m` | Orchestrates one household for one day. |
| `src/models/simulate_population.m` | Simulates all assigned households over the configured period with caching. |

## Validation tests

Added tests:

- `tests/test_simulate_occupancy.m`
- `tests/test_ev_model.m`
- `tests/test_simulate_household.m`
- `tests/test_phase2_load_model.m`

Run all implemented validations from MATLAB:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

## Notes

- EV charging energy is not injected into `simulate_household` yet. The EV object exposes availability and power limits; uncontrolled and optimized charging will be applied in scenario and DSM phases.
- HVAC is treated as fixed/non-controllable for Phase 2 to avoid comfort violations before the DSM comfort model is implemented.
- Population simulation is cached in `results/population_profiles.mat` using a lightweight configuration hash.

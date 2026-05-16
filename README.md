# EV_Hosting_DSM MATLAB Project

MATLAB project for the M.Sc. thesis implementation:

**AI-Driven Demand-Side Management for Enhancing EV Charging Hosting Capacity and Power Quality in a Radial Distribution Feeder**

Implemented status in this package:

- [x] First deliverable: config JSON files created and validated
- [x] Single final survey workbook prepared: `data/survey/Household_Energy_Survey.xlsx`
- [x] Phase 0 - Configuration and IO Layer
- [x] Phase 1 - Three-Phase Unbalanced Feeder Model
- [x] Phase 2 - Behavior-Driven Load Model
- [x] Phase 3 - Pricing Engine
- [x] Phase 4 - DSM Controller

## Validate the implemented phases

From MATLAB R2022b or newer:

```matlab
cd EV_Hosting_DSM
run startup.m
main([], 'validate')
```

This runs:

- `test_config_loader`
- `test_survey_schema`
- `test_phase0_io`
- `test_phase1_feeder`
- `test_bfs_power_flow`
- `test_pq_indices`
- `test_simulate_occupancy`
- `test_ev_model`
- `test_simulate_household`
- `test_phase2_load_model`
- `test_pricing`
- `test_phase3_pricing`
- `test_milp`
- `test_phase4_dsm`

## Run a smoke workflow

```matlab
cd EV_Hosting_DSM
run startup.m
main()
```

The smoke workflow loads config/survey/calendar/weather, builds the feeder, runs a BFS/PQ check, simulates one behavior-driven household day, computes tariffs, and runs one DSM household schedule.

## Important notes

- EV charging power is scheduled by the Phase 4 DSM layer and will be injected into feeder scenarios in Phase 5.
- HVAC is included as a fixed load component in Phase 2.
- Population simulation is available through `simulate_population` and caches output to `results/population_profiles.mat`.
- No legacy survey workbook is included. The single source workbook is `data/survey/Household_Energy_Survey.xlsx`.

## Next step

Phase 5 - Scenario execution layer.


## Phase 3 Implemented - Pricing Engine

This package implements all seven thesis pricing methods:

- Block tariff with Egyptian inclining marginal slab billing
- Flat tariff
- Time-of-Use (TOU)
- Real-Time Pricing (RTP)
- Seasonal pricing
- Critical Peak Pricing (CPP)
- Renewable Generation-Based Dynamic Pricing (RGDP)

Key files:

```text
src/pricing/select_pricing.m
src/pricing/build_pricing_context.m
src/pricing/pricing_flat.m
src/pricing/pricing_block.m
src/pricing/pricing_tou.m
src/pricing/pricing_rtp.m
src/pricing/pricing_seasonal.m
src/pricing/pricing_cpp.m
src/pricing/pricing_rgdp.m
src/pricing/compute_costs.m
tests/test_pricing.m
tests/test_phase3_pricing.m
```

Run validation with:

```matlab
main([], 'validate')
```


## Phase 4 Implemented - DSM Controller

This package implements the household DSM and feeder coordination layer:

- Household MILP problem builder
- `intlinprog`-based scheduler with deterministic fallback
- Rule-based appliance and EV scheduling
- V2G scheduler
- Comfort index calculation
- Feeder supervisor with BFS/PQ feedback loop

Key files:

```text
src/dsm/build_milp_problem.m
src/dsm/run_household_milp.m
src/dsm/rule_based_controller.m
src/dsm/v2g_scheduler.m
src/dsm/comfort_index.m
src/dsm/feeder_supervisor.m
tests/test_milp.m
tests/test_phase4_dsm.m
```

Run validation with:

```matlab
main([], 'validate')
```

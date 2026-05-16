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
- [x] Phase 5 - Scenario Execution Layer

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
- `test_phase5_scenarios`

## Run a smoke workflow

```matlab
cd EV_Hosting_DSM
run startup.m
main()
```

The smoke workflow loads config/survey/calendar/weather, builds the feeder, runs a BFS/PQ check, simulates one behavior-driven household day, computes tariffs, and runs one DSM household schedule. Phase 5 scenarios can be executed explicitly using the commands below.

## Important notes

- EV charging power is injected and scheduled in the Phase 5 scenario layer using Phase 4 controllers.
- HVAC is included as a fixed load component in Phase 2.
- Population simulation is available through `simulate_population` and caches output to `results/population_profiles.mat`.
- No legacy survey workbook is included. The single source workbook is `data/survey/Household_Energy_Survey.xlsx`.

## Run Phase 5 scenarios

```matlab
main([], scenario, 4)
main([], scenarios, [-1 1 4 6])
main([], all_scenarios)
```

Scenario outputs are saved to `results/scenario_results.mat`.

## Next step

Phase 6 - Visualization layer.


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


## Phase 5 Implemented - Scenario Execution Layer

This package implements Baseline 0 and Scenarios 0 through 6:

- Baseline 0: no EVs, no DSM
- Scenario 0: no EVs, rule-based DSM
- Scenario 1: uncontrolled EV integration
- Scenario 2: slow vs fast uncontrolled EV comparison
- Scenario 3: MILP-controlled EV only
- Scenario 4: MILP-controlled loads plus EV
- Scenario 5: MILP-controlled loads plus EV plus V2G
- Scenario 6: full hierarchical AI-DSM using the feeder supervisor

Key files:

```text
src/scenarios/run_baseline0.m
src/scenarios/run_scenario0.m
src/scenarios/run_scenario1.m
src/scenarios/run_scenario2.m
src/scenarios/run_scenario3.m
src/scenarios/run_scenario4.m
src/scenarios/run_scenario5.m
src/scenarios/run_scenario6.m
src/scenarios/run_all_scenarios.m
src/scenarios/run_scenario_core.m
tests/test_phase5_scenarios.m
```

Run validation with:

```matlab
main([], 'validate')
```

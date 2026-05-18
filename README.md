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
- [x] Phase 6 - Visualization Layer
- [x] Phase 7 - HouseholdTwin Class

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
- `test_phase6_visualization`
- `test_phase7_household_twin`

## Run a smoke workflow

```matlab
cd EV_Hosting_DSM
run startup.m
main()
```

The smoke workflow loads config/survey/calendar/weather, builds the feeder, runs a BFS/PQ check, simulates one behavior-driven household day, computes tariffs, and runs one DSM household schedule, and executes a HouseholdTwin smoke test. Phase 5 scenarios can be executed explicitly using the commands below. Phase 6 figures are generated automatically when multiple scenarios are run.

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

Phase 8 - Complete test-suite hardening and end-to-end validation.


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

## EV charge-window feasibility fix

This package includes an EV feasibility fix in `src/models/ev_model.m`. Randomly
generated EVs are conditioned so their initial SOC can reach the target SOC within
the available overnight charging window. This removes repeated population-simulation
warnings such as "Insufficient time to charge EV to target SOC" while preserving
stochastic arrival/departure behavior.

The population cache is versioned with `phase2_ev_feasible_v2`, so older cached
profiles are automatically regenerated.


## Phase 6 Implemented - Visualization Layer

This package implements the thesis visualization layer:

- Scenario comparison overview
- PQ index comparison
- 24-hour load profile comparison
- EV hosting capacity figure
- PNG export at 300 DPI
- EPS export for LaTeX/thesis workflows
- MATLAB FIG export for later editing

Key files:

```text
src/viz/plot_scenario_comparison.m
src/viz/plot_pq_indices.m
src/viz/plot_load_profiles.m
src/viz/plot_hosting_capacity.m
tests/test_phase6_visualization.m
```

Run scenarios and generate figures with:

```matlab
main([], 'all_scenarios')
```

Or explicitly request plots for selected scenarios:

```matlab
main([], 'scenarios', [-1 1 4 6], 'plot')
```

Figures are exported under:

```text
results/figures/png
results/figures/eps
results/figures
```

## Phase 6 Output Path Note

Visualization outputs use the dynamic project paths resolved by `config_loader()`. By default, figures are exported to:

```text
EV_Hosting_DSM/results/figures
```

The path is relative to the active project root, so the project can be moved to another folder or drive without editing MATLAB code.

## Phase 7 Implemented - HouseholdTwin Class

This package implements the configurable household digital twin interface:

- Stateful `HouseholdTwin` class
- Survey-derived household configuration
- Daily profile generation through the Phase 2 load model
- DSM flexibility-window API
- DSM command validation and acceptance/rejection logic
- Comfort-index protection with a default minimum CI of 0.30
- EV status access
- Short-horizon projected load output
- Smart-meter measurement update with bias correction

Key files:

```text
src/twin/HouseholdTwin.m
tests/test_phase7_household_twin.m
```

Example:

```matlab
twin = HouseholdTwin(1, assignment, data, cfg);
twin.generateDayProfile(cal_day, weather_day);
windows = twin.getFlexibilityWindows();
projection = twin.getProjectedLoad(8);
ev = twin.getEVStatus();
```

Run validation with:

```matlab
main([], 'validate')
```

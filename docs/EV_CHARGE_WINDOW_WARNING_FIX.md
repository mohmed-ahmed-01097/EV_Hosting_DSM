# EV Charge Window Warning Fix

## Problem

During full population simulation, `ev_model.m` could generate EV cases where the
random initial SOC was too low for the available overnight charge window. This was
most common for slow 3.7 kW chargers with 60-75 kWh batteries.

MATLAB warning example:

```text
Warning: Insufficient time to charge EV to target SOC (need 14.5 h, have 13.0 h).
```

The warning was physically understandable, but it created repeated noise during
`simulate_population` and scenario execution.

## Fix

`src/models/ev_model.m` now conditions the generated initial SOC so every present
EV has a feasible path to `soc_target` within its stochastic arrival/departure
window.

The model now computes:

```matlab
availableHr
maxGridEnergyWh
maxBatteryEnergyWh = maxGridEnergyWh * eta_c
socRequiredForFeasibility
```

If the raw sampled SOC is infeasible, the model raises it to the minimum feasible
SOC and records:

```matlab
ev.soc_initial_raw
ev.feasibility_adjusted
ev.min_charge_hr
ev.available_hr
ev.feasible_to_target
```

No warning is emitted for normal feasible conditioning.

## Cache Handling

`simulate_population.m` now includes the model version
`phase2_ev_feasible_v2` in its cache hash. Old `population_profiles.mat` files
created before this EV feasibility fix are automatically invalidated.

`main.m` now delegates Phase 5 cache loading to `simulate_population`, so stale
caches cannot bypass the versioned cache check.

## Validation

`tests/test_ev_model.m` now verifies that a slow charger EV target is feasible:

```matlab
evSlow.feasible_to_target == true
evSlow.energy_needed_wh <= evSlow.P_charge_max_w * evSlow.available_hr
```

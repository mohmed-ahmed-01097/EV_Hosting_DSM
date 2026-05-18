# Phase 7 Implementation - HouseholdTwin Class

## Scope

Phase 7 implements the configurable household digital twin specified in the master implementation prompt. The class represents one household as a stateful simulation and control object.

## Implemented capabilities

- Constructor from assignment, survey data, and configuration.
- Survey-derived household metadata extraction.
- Daily profile generation using `simulate_household`.
- DSM flexibility API exposing controllable appliance windows.
- DSM command validation and application.
- Comfort-index protection using `comfort_index`.
- Overlap rejection for conflicting controllable-load commands.
- EV status access.
- Short-horizon projected-load output.
- Measurement update from smart-meter readings with bias correction.

## Key file

```text
src/twin/HouseholdTwin.m
```

## Validation file

```text
tests/test_phase7_household_twin.m
```

## Example

```matlab
cfg = config_loader();
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

twin = HouseholdTwin(1, assignment, data, cfg);
twin.generateDayProfile(cal_day, weather_day);
windows = twin.getFlexibilityWindows();
projection = twin.getProjectedLoad(8);
ev = twin.getEVStatus();
```

## DSM command API

```matlab
cmd = struct('appliance','Washing_Machine','new_start',40);
[accepted, new_ci, reason] = twin.acceptDSMCommand(cmd);
```

The command is accepted only if it satisfies the appliance window, does not conflict with another controllable load interval, and keeps comfort index above the default `0.30` threshold.

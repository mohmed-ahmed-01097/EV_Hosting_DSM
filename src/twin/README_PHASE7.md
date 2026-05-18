# Phase 7 - HouseholdTwin

Implemented files:

```text
src/twin/HouseholdTwin.m
tests/test_phase7_household_twin.m
```

The `HouseholdTwin` class is a stateful per-household interface for the smart-meter control loop. It wraps the Phase 2 behavior-driven household profile and exposes a stable API for DSM coordination.

Main methods:

- `generateDayProfile(cal_day, weather_day)`
- `getFlexibilityWindows()`
- `acceptDSMCommand(cmd)`
- `getEVStatus()`
- `getProjectedLoad(steps_ahead)`
- `updateFromMeasurement(p_measured_w)`

Accepted DSM command format:

```matlab
cmd = struct('appliance', 'Washing_Machine', 'new_start', 40);
[accepted, ci, reason] = twin.acceptDSMCommand(cmd);
```

Command rejection rules:

- Appliance is not controllable or not scheduled today.
- New start is outside the flexibility window.
- New start would overlap another controllable appliance interval.
- Resulting comfort index is below the configured threshold, default `0.30`.

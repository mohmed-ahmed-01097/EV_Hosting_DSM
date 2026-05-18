# Phase 7 Comfort-Safe Command Test Fix

## Problem

`test_phase7_household_twin.m` could fail even when `HouseholdTwin.acceptDSMCommand()` behaved correctly.

The test selected the first conflict-free start step inside the flexibility window. For appliances with a narrow comfort allowance, such as `Water_Heater`, the earliest window step can be far enough from the preferred start that the computed comfort index falls below the configured acceptance threshold of `0.30`.

Example failure:

```text
FAIL: Valid command accepted: Rejected: comfort index 0.000 is below threshold 0.300.
```

This is not a class defect. It is the intended behavior of the smart-meter/twin control API: an in-window command may still be rejected if comfort would be too low.

## Fix

The helper function `choose_valid_start_without_overlap()` now sorts candidate start steps by distance from the preferred start and chooses the closest conflict-free step first.

This makes the “valid command accepted” test truly valid under both constraints:

1. the command is inside the allowed flexibility window, and
2. the command preserves the minimum comfort index.

## Files changed

```text
tests/test_phase7_household_twin.m
```

## Expected result

```text
PASS: Valid command accepted
PASS: Accepted command comfort index ...
```

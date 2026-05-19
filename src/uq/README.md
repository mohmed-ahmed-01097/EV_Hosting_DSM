# Phase 10 PART A UQ Utilities

This folder contains the uncertainty and robustness utilities required by BUG-06:

- `sensitivity_analysis.m` — one-at-a-time parameter sweep for EV penetration, comfort weight, HVAC setpoint, timestep, and V2G revenue fraction.
- `monte_carlo_runner.m` — repeated scenario runs with different random seeds.

These utilities are intentionally sequential and compiled-app safe.

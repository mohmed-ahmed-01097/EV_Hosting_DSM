# Phase 8 - Final Validation Test Suite

Phase 8 closes the validation layer for the project. The final `main([], 'validate')` path now runs the complete regression suite from the configuration layer through the HouseholdTwin layer, plus final inventory and export checks.

## Added files

- `tests/test_phase8_tests_inventory.m`
- `src/io/verify_known_bug_fixes.m`

## What Phase 8 validates

- Every required test file exists.
- `run_config_tests.m` calls every required test.
- The six known code-review bug fixes are verified through `verify_known_bug_fixes(cfg)`.
- The final deliverables checklist can be exported even before scenarios are run.

## Main command

```matlab
main([], 'validate')
```

This command now represents the final regression entry point for Step 1 and Phases 0-9.

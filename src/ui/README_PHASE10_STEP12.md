# PART B Step 12 — Scenarios View

Implemented the dashboard Scenarios view and sequential scenario execution path.

## User-facing features

- Scenario cards: Baseline 0, Scenario 0, Scenario 1, Scenario 2, Scenario 3, Scenario 4, Scenario 5, Scenario 6
- Card statuses: Not run, Running, Complete, Failed
- Scenario detail dropdown
- Run This, Run Selected, Stop, Reset
- Live progress label
- Scenario log text area
- Three-phase feeder-load preview from retained lean result field `L_feeder_w`
- Pop-out plot and Open Results Folder buttons

## Compiled-app behavior

No `parfeval`, no `parfor`. Scenario execution is sequential and uses `drawnow('limitrate')` inside progress callbacks.

## Test

```matlab
test_part_b_step12_scenarios_view()
```

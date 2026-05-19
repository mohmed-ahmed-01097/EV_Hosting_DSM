# Phase 10 PART B Step 11 — Core UI Views

## Scope

This step implements the first five dashboard views in `src/ui/EVHostingDSM_App.m`:

1. Dashboard
2. Configuration
3. Feeder Model
4. Load Model
5. Pricing

The remaining views — Scenarios, Results, Export, and Tests — remain placeholders for Steps 12–15.

## Implemented View Features

### Dashboard

- Four module status cards: Config, Survey, Weather, Population
- Feeder mini-map preview
- Quick actions: Run All Scenarios placeholder, Run Scenario 4 placeholder, Run All Tests, Open Results Folder
- Five KPI tiles
- Shared timestamped execution log

### Configuration

- Group navigation list
- EV penetration slider
- Charger type selector
- Slow/fast charger power fields
- V2G enable toggle
- V2G revenue/reserve fields
- Arrival/departure mean fields
- DSM controller selector
- Lambda comfort and comfort threshold controls
- Editable appliance flexibility table
- Save-to-memory and validation callbacks

### Feeder Model

- Feeder topology UIAxes
- Assignment summary table by transformer zone
- Reassignment action
- BFS smoke-test panel with P/Q inputs
- Vmin, VUF, transformer loading, and losses result log

### Load Model

- Household selector
- Day type and temperature controls
- Single-household simulation action
- 24-hour stacked load profile plot
- Occupancy heatmap
- Population simulation action with progress callback
- Live mean-load-per-zone bar chart

### Pricing

- Seven tariff method checkboxes
- 24-hour tariff curve plotting
- Block tariff bill calculator
- Block slab breakdown table
- Pricing pop-out support

## Validation

New test:

```matlab
test_part_b_step11_core_views()
```

This is a static source test, so `main([], 'validate')` remains non-interactive and does not open the UI.

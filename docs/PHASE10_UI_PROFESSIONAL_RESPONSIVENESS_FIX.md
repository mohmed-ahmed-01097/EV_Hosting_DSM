# Phase 10 UI Professional Responsiveness Fix

This patch addresses the UI review feedback after the first full App Designer-style build.

## Problems fixed

1. **Scenario execution freezes the UI for long periods**
   - Added finer `progress_cb` checkpoints inside household scheduling and power-flow loops.
   - Added `drawnow('limitrate')` in long scenario stages so UI controls, logs, and the clock can update.
   - Preserved compiled-app safety: no `parfeval`, no `parfor`, no background pool dependency.

2. **Bottom status time appears frozen**
   - Added a lightweight app timer that refreshes the clock/status line every second while idle.
   - During long calculations, the added `drawnow('limitrate')` calls allow the timer callback to execute.

3. **Plots look like cropped white images on a dark dashboard**
   - Added `style_app_axes.m`.
   - Standardized axes background, label colors, grid colors, fonts, and legend styling.
   - Applied the plot theme to feeder, load, pricing, scenario, and results axes.

4. **Configuration group list does not change the visible content**
   - Added a selected-group values table.
   - Clicking Simulation / EV Parameters / PQ Limits / DSM Controller / Pricing / HVAC now updates the table.
   - The original high-impact controls remain visible for fast editing.

5. **Previous scenario state disappears after reopening**
   - Startup now restores `results/scenario_results.mat` when it exists.
   - Scenario cards, dashboard KPIs, live scenario plot, and Results view are refreshed from saved lean results.
   - A lightweight `ui_app_state.mat` is also saved under `results/`.

## About parallel execution

For the compiled `.exe` target, the safe path is cooperative responsiveness using frequent progress callbacks and `drawnow('limitrate')`. MATLAB UI updates must run on the main MATLAB thread, and background workers cannot safely modify UI components directly. This patch therefore improves responsiveness without introducing compiled-app risks from `parfeval` or `parpool`.

For future desktop-only experimentation, a separate async runner can be added behind a config flag, but it should not be the default compiled `.exe` behavior.

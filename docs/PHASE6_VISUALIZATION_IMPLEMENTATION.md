# Phase 6 - Visualization Implementation

Phase 6 implements the publication-oriented visualization layer for the EV hosting capacity and DSM thesis project.

## Implemented files

```text
src/viz/plot_scenario_comparison.m
src/viz/plot_pq_indices.m
src/viz/plot_load_profiles.m
src/viz/plot_hosting_capacity.m
src/viz/viz_prepare_output_dirs.m
src/viz/viz_export_figure.m
src/viz/viz_normalize_results.m
src/viz/viz_result_metrics.m
tests/test_phase6_visualization.m
```

## Output folders

The visualization functions export figures to:

```text
results/figures/png/*.png
results/figures/eps/*.eps
results/figures/*.fig
```

PNG exports use 300 DPI for reports and presentations. EPS exports support LaTeX/thesis workflows.

## Main figures

### `plot_scenario_comparison`

Creates a 3x2 overview figure containing:

1. Mean and peak VUF with the VUF limit line.
2. EV hosting capacity screening result.
3. Average 24-hour feeder load profile.
4. Flat and block tariff bill comparison.
5. Comfort index versus PQ improvement.
6. Transformer loading heatmap from PQ time series.

### `plot_pq_indices`

Creates focused PQ comparison panels for:

- Peak VUF.
- Minimum voltage.
- Peak transformer loading.
- Feeder losses and violation counts.

### `plot_load_profiles`

Creates average 24-hour profile plots for:

- Total feeder load by scenario.
- Three-phase profile for the final/most advanced scenario.
- Peak feeder load comparison.
- Phase-load imbalance indicator.

### `plot_hosting_capacity`

Creates a hosting-capacity-focused figure showing:

- Maximum EV penetration without screened PQ violation.
- Peak VUF and minimum voltage stress indicators.

## MATLAB usage

After running scenarios:

```matlab
main([], 'all_scenarios')
```

Figures are generated automatically when multiple scenarios are executed. You can also call the plotting functions manually:

```matlab
load(fullfile(cfg.output_dir, 'scenario_results.mat'), 'all_results')
plot_scenario_comparison(all_results, cfg)
plot_pq_indices(all_results, cfg)
plot_load_profiles(all_results, cfg)
plot_hosting_capacity(all_results, cfg)
```

## Validation

Run:

```matlab
main([], 'validate')
```

The Phase 6 test uses synthetic Phase 5-like scenario results so it validates plotting/export behavior without running the full annual scenario workflow.

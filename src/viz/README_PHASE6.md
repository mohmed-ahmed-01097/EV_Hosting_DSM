# Phase 6 - Visualization Layer

Implemented publication-oriented visualization functions:

- `plot_scenario_comparison.m`
- `plot_pq_indices.m`
- `plot_load_profiles.m`
- `plot_hosting_capacity.m`

Support helpers:

- `viz_prepare_output_dirs.m`
- `viz_export_figure.m`
- `viz_normalize_results.m`
- `viz_result_metrics.m`

Figures are exported to:

```text
results/figures/png/*.png
results/figures/eps/*.eps
results/figures/*.fig
```

Each figure uses hidden MATLAB figures for batch validation and exports PNG at 300 DPI plus EPS for LaTeX/thesis workflows.

# Phase 6 Results Folder Fix

## Final Behavior

Phase 6 visualization outputs are not written to a temporary folder. They are written through the dynamic paths returned by `config_loader()`.

By default, `config/default_config.json` contains:

```json
"output_dir": "results"
```

`config_loader()` resolves this relative setting against the active project root at runtime. Therefore the output path becomes:

```text
<project_root>/results
<project_root>/results/figures
<project_root>/results/tables
```

The visualization helpers then export figures to:

```text
<project_root>/results/figures/png
<project_root>/results/figures/eps
<project_root>/results/figures/*.fig
```

## Updated Files

- `src/io/config_loader.m`
- `src/viz/viz_prepare_output_dirs.m`
- `tests/test_phase6_visualization.m`

## Validation

Run:

```matlab
main([], 'validate')
```

The Phase 6 validation asserts that the generated PNG path starts with `cfg.figs_dir`, which is dynamically resolved from the project root and `default_config.json`.

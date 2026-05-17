# Phase 6 Dynamic Output Path Fix

## Problem

The previous Phase 6 validation patch explicitly assigned:

```matlab
cfg.output_dir = fullfile(cfg.root_folder, 'results');
```

That kept figures inside the project, but it still overrode the configuration at test time.

## Fix

Phase 6 now uses the dynamic paths produced by `config_loader()`:

```matlab
cfg = config_loader();
% cfg.output_dir, cfg.figs_dir, and cfg.tables_dir are used directly.
```

`config_loader()` resolves relative paths from `default_config.json` against the active project root folder at runtime. Therefore, if the project is moved from one drive or PC to another, the output remains inside that project copy.

Default resolved output:

```text
<project_root>/results
<project_root>/results/figures
<project_root>/results/tables
```

Figure exports are created under:

```text
<project_root>/results/figures/png
<project_root>/results/figures/eps
<project_root>/results/figures/*.fig
```

## Updated Files

- `src/io/config_loader.m`
- `src/viz/viz_prepare_output_dirs.m`
- `tests/test_phase6_visualization.m`

## Notes

- No Windows drive path is hardcoded.
- Phase 6 validation uses the configured dynamic project output path.
- If `config/default_config.json` changes `output_dir`, Phase 6 follows that setting dynamically.

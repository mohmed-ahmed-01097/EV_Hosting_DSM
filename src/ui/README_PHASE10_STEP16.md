# Phase 10 PART B Step 16 — Compiled EXE Build

Step 16 adds the final compiled-application build path.

## Main files

```text
src/ui/build_exe.m
src/ui/launch_app.m
```

## Build

```matlab
run startup.m
build_exe()
```

## Dry-run validation

```matlab
build_exe('dry_run', true)
```

Dry-run creates:

```text
exe/build_manifest.json
exe/README_DISTRIBUTION.txt
```

without invoking MATLAB Compiler.

## Validation test

```matlab
test_part_b_step16_build_exe()
```

The validation test performs static checks only. It does not compile the executable, because MATLAB Compiler may not be installed on all machines.

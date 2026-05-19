# Phase 10 PART B Step 16 — Build EXE Script

This step finalizes the compiled-application build path for the EV Hosting DSM Simulator.

## Implemented files

- `src/ui/build_exe.m`
- `src/ui/launch_app.m`
- `tests/test_part_b_step16_build_exe.m`
- `src/ui/README_PHASE10_STEP16.md`

## Key decision

The compiled entry point is:

```matlab
src/ui/launch_app.m
```

The app class file is included as a dependency:

```matlab
src/ui/EVHostingDSM_App.m
```

This is safer than compiling the classdef file directly. `launch_app.m` is a normal MATLAB function and is therefore a clean executable startup entry point.

## Build command

From the project root:

```matlab
run startup.m
build_exe()
```

To validate the build manifest without compiling:

```matlab
build_exe('dry_run', true)
```

## Output

The build script writes:

```text
exe/build_manifest.json
exe/README_DISTRIBUTION.txt
exe/EVHostingDSM_Simulator.exe
```

The `.exe` is only produced when MATLAB Compiler is available.

## Bundled files

The compiler manifest includes:

```text
src/
config/
data/survey/Household_Energy_Survey.xlsx
data/weather/
```

## Runtime output folders

In compiled mode, the app writes results to the user-writable folder:

```text
userpath/EV_DSM_Results
```

The app configuration path is documented as:

```text
userpath/EV_DSM_config.json
```

## Distribution rule

Distribute the entire generated `exe/` folder, not only the `.exe` file. Users also need the MATLAB Runtime that matches the MATLAB release used to compile the app.

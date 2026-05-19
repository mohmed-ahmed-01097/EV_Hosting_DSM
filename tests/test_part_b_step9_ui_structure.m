function test_part_b_step9_ui_structure()
% TEST_PART_B_STEP9_UI_STRUCTURE Validate Phase 10 PART B Step 9 UI scaffold.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL assertions for UI folder/helper structure.
%
% Example:
%   test_part_b_step9_ui_structure()

fprintf('\n[test_part_b_step9_ui_structure] Starting PART B Step 9 UI scaffold validation...\n');

thisFile = mfilename('fullpath');
testsDir = fileparts(thisFile);
rootDir = fileparts(testsDir);
addpath(genpath(fullfile(rootDir, 'src')));

requiredFiles = { ...
    fullfile(rootDir, 'src', 'ui', 'launch_app.m'), ...
    fullfile(rootDir, 'src', 'ui', 'build_exe.m'), ...
    fullfile(rootDir, 'src', 'ui', 'README_PHASE10_STEP9.md'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'get_root_dir.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_theme.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_log.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_kpi_gauges.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_feeder_plot.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_load_profile_plot.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_scenario_comparison.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_popout_plot.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_export_helper.m'), ...
    fullfile(rootDir, 'src', 'ui', 'app_helpers', 'run_scenarios_sequential.m') ...
};

for i = 1:numel(requiredFiles)
    assert_pass(isfile(requiredFiles{i}), sprintf('Exists: %s', local_path(rootDir, requiredFiles{i})));
end

rootFromHelper = get_root_dir();
assert_pass(ischar(rootFromHelper) || isstring(rootFromHelper), 'get_root_dir returns a path string');
assert_pass(isfolder(rootFromHelper), sprintf('get_root_dir folder exists: %s', char(rootFromHelper)));

theme = app_theme();
assert_pass(isstruct(theme) && isfield(theme, 'colors') && isfield(theme, 'nav'), ...
    'app_theme returns colors and navigation metadata');
assert_pass(numel(theme.nav.labels) == 9, sprintf('app_theme contains 9 navigation labels: %d', numel(theme.nav.labels)));

logLines = app_log({}, 'Step 9 log smoke test', 5);
assert_pass(iscell(logLines) && numel(logLines) == 1, 'app_log appends one line to a cell log');

g = app_kpi_gauges([], struct('vuf_pct', 1.2, 'v_min_pu', 0.94), struct());
assert_pass(isstruct(g) && isfield(g, 'values') && numel(g.values) == 6, ...
    'app_kpi_gauges returns six KPI values in metadata mode');

T = app_scenario_comparison({struct('scenario_id', 1, 'description', 'Smoke', ...
    'pq_summary', struct('mean_vuf_pct', 1.1))}, 'mean_vuf_pct', []);
assert_pass(istable(T) && height(T) == 1, 'app_scenario_comparison returns one-row summary table');

fprintf('[test_part_b_step9_ui_structure] Complete. PART B Step 9 UI scaffold is valid.\n');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step9_ui_structure:assertionFailed', message);
end
end

function p = local_path(rootDir, fullPath)
p = strrep(fullPath, [rootDir filesep], '');
end

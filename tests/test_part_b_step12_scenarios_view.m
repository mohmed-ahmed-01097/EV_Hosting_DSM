function test_part_b_step12_scenarios_view()
% TEST_PART_B_STEP12_SCENARIOS_VIEW Validate PART B Step 12 Scenarios UI.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation results.
%
% Example:
%   test_part_b_step12_scenarios_view()
%
% Notes:
%   Static source checks only. This keeps main([], 'validate') non-interactive.

fprintf('\n[test_part_b_step12_scenarios_view] Starting PART B Step 12 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
runnerPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'run_scenarios_sequential.m');

assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(runnerPath), 'run_scenarios_sequential.m exists');

src = fileread(appPath);
runnerSrc = fileread(runnerPath);

% Scenarios view construction
assert_contains(src, 'function createScenariosView(app)', 'Scenarios view builder exists');
assert_contains(src, 'Scenario Cards', 'Scenario cards panel exists');
assert_contains(src, 'Active Scenario Detail', 'Active scenario detail panel exists');
assert_contains(src, 'Live Execution', 'Live execution panel exists');
assert_contains(src, 'ScenarioLiveAxes', 'Scenario live plot axes exists');
assert_contains(src, 'ScenarioLog', 'Scenario log text area exists');

% Scenario actions
assert_contains(src, 'function onRunThisScenario(app)', 'Run This callback exists');
assert_contains(src, 'function onRunCheckedScenarios(app)', 'Run Selected callback exists');
assert_contains(src, 'function onRunSelectedScenarios(app, scenarioIds)', 'Sequential run method exists');
assert_contains(src, 'function onStopScenarios(app)', 'Stop callback exists');
assert_contains(src, 'function onResetScenarios(app)', 'Reset callback exists');
assert_contains(src, 'function scenarioProgressCallback(app, sid, pct, msg)', 'Scenario progress callback exists');
assert_contains(src, 'drawnow(''limitrate'')', 'drawnow limitrate retained for compiled responsiveness');

% Scenario dispatch and result storage
assert_contains(src, 'run_baseline0(app.cfg', 'Baseline dispatch exists');
assert_contains(src, 'str2func(sprintf(''run_scenario%d'', sid))', 'Scenario dispatch exists');
assert_contains(src, 'scenario_results.mat', 'Scenario results save target exists');
assert_contains(src, 'L_feeder_w', 'Lean result live plot uses retained L_feeder_w');
assert_contains(src, 'scenarioResultIndex(sid)', 'Scenario ID mapping helper used');

% External helper remains available for scripts/tests
assert_contains(runnerSrc, 'function allResults = run_scenarios_sequential(ctx, scenarioIds, progress_cb)', 'Sequential helper signature exists');
assert_contains(runnerSrc, 'No parfeval/parfor is used', 'Sequential helper documents compiled-safe execution');
assert_contains(runnerSrc, 'drawnow(''limitrate'')', 'Sequential helper uses drawnow limitrate');
assert_contains(runnerSrc, 'run_baseline0(ctx.cfg', 'Sequential helper dispatches baseline');
assert_contains(runnerSrc, 'str2func(sprintf(''run_scenario%d'', sid))', 'Sequential helper dispatches scenarios');

fprintf('[test_part_b_step12_scenarios_view] Complete. PART B Step 12 Scenarios UI is implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step12_scenarios_view:assertionFailed', '%s', message);
end
end

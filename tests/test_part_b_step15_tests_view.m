function test_part_b_step15_tests_view()
% TEST_PART_B_STEP15_TESTS_VIEW Validate PART B Step 15 Tests UI.
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
%   test_part_b_step15_tests_view()
%
% Notes:
%   Static source checks only. This keeps main([], 'validate') non-interactive.

fprintf('\n[test_part_b_step15_tests_view] Starting PART B Step 15 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
runnerPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_test_runner.m');
namesPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'appDefaultTestNames.m');

assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(runnerPath), 'app_test_runner.m exists');
assert_pass(isfile(namesPath), 'appDefaultTestNames.m exists');

src = fileread(appPath);
runnerSrc = fileread(runnerPath);
namesSrc = fileread(namesPath);

assert_contains(src, 'function createTestsView(app)', 'Tests view builder exists');
assert_contains(src, 'Test Controls', 'Test controls card exists');
assert_contains(src, 'Validation Test Matrix', 'Validation test matrix card exists');
assert_contains(src, 'DETAIL', 'Detail panel exists');
assert_contains(src, 'Run All Tests', 'Run All Tests button exists');
assert_contains(src, 'Run Selected', 'Run Selected button exists');
assert_contains(src, 'Clear Results', 'Clear Results button exists');
assert_contains(src, 'Save Test Report', 'Save Test Report button exists');
assert_contains(src, 'TestsTable', 'Tests table property/control exists');
assert_contains(src, 'TestsDetailText', 'Tests detail text area exists');
assert_contains(src, 'TestsSummaryLabel', 'Tests summary label exists');
assert_contains(src, 'TestsProgressLabel', 'Tests progress label exists');
assert_contains(src, 'function onRunAllUiTests(app)', 'Run all tests callback exists');
assert_contains(src, 'function onRunSelectedUiTests(app)', 'Run selected tests callback exists');
assert_contains(src, 'function runUiTests(app, includeAll)', 'Sequential UI test runner method exists');
assert_contains(src, 'function onClearUiTests(app)', 'Clear tests callback exists');
assert_contains(src, 'function onSaveUiTestReport(app)', 'Save test report callback exists');
assert_contains(src, 'ui_test_report.csv', 'UI test report CSV path exists');
assert_contains(src, 'elseif viewId == 9', 'Switching to Tests view refreshes tests view');
assert_contains(src, 'drawnow(''limitrate'')', 'Tests view uses drawnow limiter for responsiveness');

assert_contains(runnerSrc, 'function result = app_test_runner(testName)', 'Helper app_test_runner function exists');
assert_contains(runnerSrc, 'switch testName', 'Helper uses explicit switch dispatch');
assert_contains(runnerSrc, 'test_config_loader();', 'Helper can run config loader test');
assert_contains(runnerSrc, 'test_phase5_scenarios();', 'Helper can run scenario test');
assert_contains(runnerSrc, 'test_part_b_step14_export_view();', 'Helper includes latest previous UI test');
assert_contains(runnerSrc, 'Compiled-app safe', 'Helper documents compiled-app-safe execution');

assert_contains(namesSrc, 'function names = appDefaultTestNames()', 'Default test list helper exists');
assert_contains(namesSrc, 'test_part_b_step14_export_view', 'Default list includes Step 14 validation');
assert_contains(namesSrc, 'test_phase9_main_export', 'Default list includes Phase 9 validation');

fprintf('[test_part_b_step15_tests_view] Complete. PART B Step 15 Tests UI is implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step15_tests_view:assertionFailed', '%s', message);
end
end

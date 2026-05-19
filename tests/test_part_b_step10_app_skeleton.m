function test_part_b_step10_app_skeleton()
% TEST_PART_B_STEP10_APP_SKELETON Validate PART B Step 10 app skeleton files.
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
%   test_part_b_step10_app_skeleton()
%
% Notes:
%   This test intentionally does not instantiate the UI, so main([], 'validate')
%   remains non-interactive and safe for automated validation.

fprintf('\n[test_part_b_step10_app_skeleton] Starting PART B Step 10 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
launchPath = fullfile(rootDir, 'src', 'ui', 'launch_app.m');
buildPath = fullfile(rootDir, 'src', 'ui', 'build_exe.m');

assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(launchPath), 'launch_app.m exists');
assert_pass(isfile(buildPath), 'build_exe.m exists');

src = fileread(appPath);
assert_contains(src, 'classdef EVHostingDSM_App < matlab.apps.AppBase', 'App class inherits matlab.apps.AppBase');
assert_contains(src, 'function app = EVHostingDSM_App()', 'Constructor exists');
assert_contains(src, 'function createComponents(app)', 'createComponents method exists');
assert_contains(src, 'function runStartup(app)', 'runStartup method exists');
assert_contains(src, 'function switchView(app, viewId)', 'switchView method exists');
assert_contains(src, 'function updateStatus(app, msg, level)', 'updateStatus method exists');
assert_contains(src, 'function log(app, msg)', 'log method exists');
assert_contains(src, 'function setLamp(app, lampName, isOk)', 'setLamp method exists');
assert_contains(src, 'DashboardPanel', 'DashboardPanel property exists');
assert_contains(src, 'ConfigPanel', 'ConfigPanel property exists');
assert_contains(src, 'FeederPanel', 'FeederPanel property exists');
assert_contains(src, 'LoadPanel', 'LoadPanel property exists');
assert_contains(src, 'PricingPanel', 'PricingPanel property exists');
assert_contains(src, 'ScenariosPanel', 'ScenariosPanel property exists');
assert_contains(src, 'ResultsPanel', 'ResultsPanel property exists');
assert_contains(src, 'ExportPanel', 'ExportPanel property exists');
assert_contains(src, 'TestsPanel', 'TestsPanel property exists');
assert_contains(src, 'drawnow(''limitrate'')', 'Compiled-safe drawnow limitrate calls exist');

launchSrc = fileread(launchPath);
assert_contains(launchSrc, 'EVHostingDSM_App();', 'launch_app constructs EVHostingDSM_App');
assert_pass(~contains(launchSrc, 'not implemented yet'), 'launch_app no longer reports Step 10 as missing');

buildSrc = fileread(buildPath);
assert_contains(buildSrc, 'EVHostingDSM_App.m', 'build_exe supports programmatic AppBase app file');
assert_contains(buildSrc, 'StandaloneApplicationOptions', 'build_exe uses MATLAB Compiler options');

fprintf('[test_part_b_step10_app_skeleton] Complete. PART B Step 10 app skeleton is present.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step10_app_skeleton:assertionFailed', '%s', message);
end
end

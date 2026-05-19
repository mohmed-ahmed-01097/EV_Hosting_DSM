function test_part_b_step16_build_exe()
% TEST_PART_B_STEP16_BUILD_EXE Validate PART B Step 16 build script.
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
%   test_part_b_step16_build_exe()
%
% Notes:
%   Static and dry-run checks only. This test does not compile the .exe
%   because MATLAB Compiler may not be installed on every development PC.

fprintf('\n[test_part_b_step16_build_exe] Starting PART B Step 16 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
buildPath = fullfile(rootDir, 'src', 'ui', 'build_exe.m');
launchPath = fullfile(rootDir, 'src', 'ui', 'launch_app.m');
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
helperPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'get_root_dir.m');
docPath = fullfile(rootDir, 'docs', 'PHASE10_PART_B_STEP16_BUILD_EXE.md');
readmePath = fullfile(rootDir, 'src', 'ui', 'README_PHASE10_STEP16.md');

assert_pass(isfile(buildPath), 'build_exe.m exists');
assert_pass(isfile(launchPath), 'launch_app.m exists');
assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(helperPath), 'get_root_dir.m exists');
assert_pass(isfile(docPath), 'Step 16 documentation exists');
assert_pass(isfile(readmePath), 'Step 16 UI README exists');

buildSrc = fileread(buildPath);
launchSrc = fileread(launchPath);
helperSrc = fileread(helperPath);

assert_contains(buildSrc, 'launch_app.m', 'Build entry point is launch_app.m');
assert_contains(buildSrc, 'EVHostingDSM_App.m', 'Build verifies app class file');
assert_contains(buildSrc, 'compiler.build.StandaloneApplicationOptions', 'Build supports compiler.build API');
assert_contains(buildSrc, 'compiler.build.standaloneApplication', 'Build invokes standalone compiler API');
assert_contains(buildSrc, 'mcc(args{:})', 'Build includes mcc fallback');
assert_contains(buildSrc, 'AdditionalFiles', 'Build bundles additional files');
assert_contains(buildSrc, 'Household_Energy_Survey.xlsx', 'Build bundles survey workbook');
assert_contains(buildSrc, 'data'', ''weather', 'Build bundles weather cache folder');
assert_contains(buildSrc, 'build_manifest.json', 'Build writes build manifest');
assert_contains(buildSrc, 'README_DISTRIBUTION.txt', 'Build writes distribution README');
assert_contains(buildSrc, 'dry_run', 'Build supports dry-run validation');
assert_contains(buildSrc, 'EV_DSM_Results', 'Build documents deployed results folder');
assert_contains(buildSrc, 'EV_DSM_config.json', 'Build documents deployed config file');

assert_contains(launchSrc, 'get_root_dir()', 'Launch uses compiled-safe root resolver');
assert_contains(launchSrc, 'EVHostingDSM_App()', 'Launch creates app instance');
assert_contains(launchSrc, 'addpath(genpath(srcDir))', 'Launch adds src recursively when available');
assert_contains(launchSrc, 'compiled executable entry point', 'Launch documents executable entry usage');

assert_contains(helperSrc, 'isdeployed', 'Root helper handles deployed mode');
assert_contains(helperSrc, 'ctfroot', 'Root helper uses ctfroot when deployed');

% Dry-run is intentionally not executed here to avoid writing into the exe
% folder during routine main([], ''validate'') runs. The build script itself
% supports: build_exe(''dry_run'', true).

fprintf('[test_part_b_step16_build_exe] Complete. PART B Step 16 build script is implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step16_build_exe:assertionFailed', '%s', message);
end
end

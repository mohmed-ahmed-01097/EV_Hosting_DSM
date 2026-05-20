function test_part_b_ui_table_config_state_patch()
% TEST_PART_B_UI_TABLE_CONFIG_STATE_PATCH Static verification for UI table style,
% dynamic config controls, and persisted test state metadata.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation lines.
%
% Example:
%   test_part_b_ui_table_config_state_patch()

fprintf('\n[test_part_b_ui_table_config_state_patch] Starting UI patch validation...\n');
rootDir = fileparts(fileparts(mfilename('fullpath')));
appFile = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
styleFile = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'style_app_table.m');
assert_pass(isfile(appFile), 'EVHostingDSM_App.m exists');
assert_pass(isfile(styleFile), 'style_app_table.m exists');

appText = fileread(appFile);
assert_pass(contains(appText, 'style_app_table(app.TestsTable'), 'Tests table uses dark table styling');
assert_pass(contains(appText, 'style_app_table(app.ResultsCompareTable'), 'Results tables use dark table styling');
assert_pass(contains(appText, 'ConfigDynamicPanel'), 'Config dynamic editor panel exists');
assert_pass(contains(appText, 'rebuildConfigDynamicControls'), 'Config group list rebuilds text/slider controls');
assert_pass(contains(appText, 'LastRunAt'), 'UI test report stores LastRunAt timestamp');
assert_pass(contains(appText, 'loadSavedTestTable'), 'UI reloads saved test report on reopen');
assert_pass(count(string(appText), 'createComponents(app);') == 1, 'Duplicate createComponents call removed');

fprintf('[test_part_b_ui_table_config_state_patch] Complete. UI table/config/state patch is present.\n');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_ui_table_config_state_patch:assertion', message);
end
end

function test_part_b_ui_professional_patch()
% TEST_PART_B_UI_PROFESSIONAL_PATCH Verify UI responsiveness/professional patch files.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL checks.
%
% Example:
%   test_part_b_ui_professional_patch()

fprintf('\n[test_part_b_ui_professional_patch] Starting checks...\n');
root = fileparts(fileparts(mfilename('fullpath')));

mustExist = {
    fullfile(root, 'src', 'ui', 'app_helpers', 'style_app_axes.m')
    fullfile(root, 'src', 'ui', 'app_helpers', 'app_theme.m')
    fullfile(root, 'src', 'ui', 'EVHostingDSM_App.m')
    fullfile(root, 'src', 'scenarios', 'run_scenario_core.m')
};

for k = 1:numel(mustExist)
    assert_pass(isfile(mustExist{k}), sprintf('File exists: %s', mustExist{k}));
end

appText = fileread(fullfile(root, 'src', 'ui', 'EVHostingDSM_App.m'));
assert_pass(contains(appText, 'ClockTimer'), 'App has clock timer property');
assert_pass(contains(appText, 'startClockTimer'), 'App starts the status clock timer');
assert_pass(contains(appText, 'loadSavedUiState'), 'App restores saved lean scenario state');
assert_pass(contains(appText, 'updateConfigGroupView'), 'Config group list updates a selected-group table');
assert_pass(contains(appText, 'styleAllAxes'), 'App applies professional axes styling');

coreText = fileread(fullfile(root, 'src', 'scenarios', 'run_scenario_core.m'));
assert_pass(contains(coreText, 'power flow step'), 'Scenario core reports progress inside power-flow loop');
assert_pass(contains(coreText, 'scheduling day'), 'Scenario core reports progress inside scheduling loop');
assert_pass(contains(coreText, "drawnow('limitrate')"), 'Scenario core yields to UI with drawnow');

fprintf('[test_part_b_ui_professional_patch] Complete.\n');
end

function assert_pass(condition, msg)
if condition
    fprintf('  PASS: %s\n', msg);
else
    fprintf('  FAIL: %s\n', msg);
    error('test_part_b_ui_professional_patch:fail', msg);
end
end

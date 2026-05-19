function test_part_b_step11_core_views()
% TEST_PART_B_STEP11_CORE_VIEWS Validate PART B Step 11 core UI views.
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
%   test_part_b_step11_core_views()
%
% Notes:
%   This test intentionally uses static source checks only. It does not
%   instantiate the UI, keeping main([], 'validate') non-interactive.

fprintf('\n[test_part_b_step11_core_views] Starting PART B Step 11 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
popoutPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_popout_plot.m');

assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(popoutPath), 'app_popout_plot.m exists');

src = fileread(appPath);

% View creation methods
assert_contains(src, 'function createDashboardView(app)', 'Dashboard view builder exists');
assert_contains(src, 'function createConfigView(app)', 'Config view builder exists');
assert_contains(src, 'function createFeederView(app)', 'Feeder view builder exists');
assert_contains(src, 'function createLoadView(app)', 'Load view builder exists');
assert_contains(src, 'function createPricingView(app)', 'Pricing view builder exists');

% Dashboard details
assert_contains(src, 'Feeder Mini-Map Preview', 'Dashboard includes feeder mini-map card');
assert_contains(src, 'Quick Actions', 'Dashboard includes quick actions card');
assert_contains(src, 'DashboardKpiLabels', 'Dashboard includes KPI labels');
assert_contains(src, 'Open Results Folder', 'Dashboard includes results folder action');

% Config details
assert_contains(src, 'ConfigGroupList', 'Config view includes group navigation');
assert_contains(src, 'ConfigEvPenSlider', 'Config view includes EV penetration slider');
assert_contains(src, 'ConfigFlexTable', 'Config view includes editable appliance flexibility table');
assert_contains(src, 'onSaveConfig(app)', 'Config save callback exists');
assert_contains(src, 'onValidateConfig(app)', 'Config validation callback exists');

% Feeder details
assert_contains(src, 'FeederAxes', 'Feeder view includes topology axes');
assert_contains(src, 'FeederAssignmentTable', 'Feeder view includes assignment table');
assert_contains(src, 'onRunBfsSmoke(app)', 'Feeder BFS smoke-test callback exists');
assert_contains(src, 'bfs_power_flow(app.net', 'Feeder callback calls BFS power flow');

% Load details
assert_contains(src, 'LoadHouseholdSpinner', 'Load view includes household selector');
assert_contains(src, 'onSimulateSingleHousehold(app)', 'Load view includes single-household simulation callback');
assert_contains(src, 'simulate_household(', 'Load callback calls simulate_household');
assert_contains(src, 'simulate_population(', 'Load population action calls simulate_population');
assert_contains(src, 'populationProgressCallback(app', 'Load population progress callback exists');

% Pricing details
assert_contains(src, 'PricingMethodChecks', 'Pricing view includes tariff method checkboxes');
assert_contains(src, 'onPlotTariffs(app)', 'Pricing plot callback exists');
assert_contains(src, 'onCalculateBlockBill(app)', 'Block tariff calculator callback exists');
assert_contains(src, 'pricing_block(app.cfg', 'Block tariff calculator calls pricing_block');
assert_contains(src, 'select_pricing(methods{k}', 'Tariff plot calls select_pricing');

% Compiled-safe responsiveness retained
assert_contains(src, 'drawnow(''limitrate'')', 'drawnow limitrate retained for compiled-safe responsiveness');

popoutSrc = fileread(popoutPath);
assert_contains(popoutSrc, 'case ''pricing_curves''', 'Pop-out helper supports pricing curves');

fprintf('[test_part_b_step11_core_views] Complete. PART B Step 11 core UI views are implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step11_core_views:assertionFailed', '%s', message);
end
end

function test_part_b_step13_results_view()
% TEST_PART_B_STEP13_RESULTS_VIEW Validate PART B Step 13 Results UI.
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
%   test_part_b_step13_results_view()
%
% Notes:
%   Static source checks only. This keeps main([], 'validate') non-interactive.

fprintf('\n[test_part_b_step13_results_view] Starting PART B Step 13 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');

src = fileread(appPath);

% Results view construction
assert_contains(src, 'function createResultsView(app)', 'Results view builder exists');
assert_contains(src, 'PQ Dashboard', 'PQ Dashboard sub-view exists');
assert_contains(src, 'Comparison', 'Comparison sub-view exists');
assert_contains(src, 'Hosting', 'Hosting sub-view exists');
assert_contains(src, 'Cost', 'Cost sub-view exists');
assert_contains(src, 'Twin', 'Twin Inspector sub-view exists');
assert_contains(src, 'UQ', 'UQ sub-view exists');
assert_contains(src, 'ResultsSubButtons', 'Results sub-view navigation buttons exist');
assert_contains(src, 'switchResultsSubView(app, subId)', 'Results sub-view switching callback exists');

% Lean-result compatible refresh methods
assert_contains(src, 'function refreshResultsView(app)', 'Results refresh method exists');
assert_contains(src, 'function [results, labels, ids] = getUiResults(app)', 'In-memory/MAT result loading helper exists');
assert_contains(src, 'function refreshPqDashboard(app, results, labels, ids)', 'PQ dashboard refresh exists');
assert_contains(src, 'function refreshComparisonResults(app, results, labels)', 'Comparison refresh exists');
assert_contains(src, 'function refreshHostingResults(app, results, labels)', 'Hosting refresh exists');
assert_contains(src, 'function refreshCostResults(app, results, labels)', 'Cost refresh exists');
assert_contains(src, 'L_feeder_w', 'Results view uses lean retained L_feeder_w');
assert_contains(src, 'resultMetric(r, ''mean_vuf_pct'')', 'Results view extracts mean VUF from pq_summary');
assert_contains(src, 'resultBills(r, tariff)', 'Results view extracts tariff bills from costs');

% Digital twin inspector and UQ
assert_contains(src, 'function onReloadResultsTwin(app)', 'Twin reload callback exists');
assert_contains(src, 'HouseholdTwin(hIdx', 'Twin inspector instantiates HouseholdTwin');
assert_contains(src, 'acceptDSMCommand(cmd)', 'Twin command callback uses acceptDSMCommand');
assert_contains(src, 'function onPreviewUq(app)', 'UQ preview callback exists');
assert_contains(src, 'ResultsUqTable', 'UQ statistics table exists');

% Pop-out and scenario integration
assert_contains(src, 'function onPopoutResults(app, plotType)', 'Results pop-out helper exists');
assert_contains(src, 'refreshResultsView(app);', 'Scenario completion refreshes results view');
assert_contains(src, 'if viewId == 7', 'Switching to Results view triggers refresh');

fprintf('[test_part_b_step13_results_view] Complete. PART B Step 13 Results UI is implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step13_results_view:assertionFailed', '%s', message);
end
end

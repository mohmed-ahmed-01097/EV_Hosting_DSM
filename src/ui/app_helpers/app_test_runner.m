function result = app_test_runner(testName)
% APP_TEST_RUNNER Run one supported validation test for the UI Tests view.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   testName (char/string): Test function name from appDefaultTestNames().
%
% Outputs:
%   result (struct): status, time_s, message, detail, error_id.
%
% Example:
%   result = app_test_runner('test_config_loader');
%
% Notes:
%   Compiled-app safe: sequential execution, no parfeval, no parfor.
%   Dispatch is explicit by switch-case, avoiding eval/feval.

if isstring(testName), testName = char(testName); end
validateattributes(testName, {'char'}, {'nonempty'});

result = struct();
result.test_name = testName;
result.status = 'FAIL';
result.time_s = NaN;
result.message = 'Not run';
result.detail = {sprintf('Test: %s', testName)};
result.error_id = '';

ticId = tic;
try
    % --- Section 1: Explicit test dispatch ---
    switch testName
        case 'test_config_loader'
            test_config_loader();
        case 'test_survey_schema'
            test_survey_schema();
        case 'test_phase0_io'
            test_phase0_io();
        case 'test_phase1_feeder'
            test_phase1_feeder();
        case 'test_bfs_power_flow'
            test_bfs_power_flow();
        case 'test_pq_indices'
            test_pq_indices();
        case 'test_simulate_occupancy'
            test_simulate_occupancy();
        case 'test_simulate_household'
            test_simulate_household();
        case 'test_ev_model'
            test_ev_model();
        case 'test_phase2_load_model'
            test_phase2_load_model();
        case 'test_pricing'
            test_pricing();
        case 'test_phase3_pricing'
            test_phase3_pricing();
        case 'test_milp'
            test_milp();
        case 'test_phase4_dsm'
            test_phase4_dsm();
        case 'test_phase5_scenarios'
            test_phase5_scenarios();
        case 'test_phase6_visualization'
            test_phase6_visualization();
        case 'test_phase7_household_twin'
            test_phase7_household_twin();
        case 'test_phase8_tests_inventory'
            test_phase8_tests_inventory();
        case 'test_phase9_main_export'
            test_phase9_main_export();
        case 'test_part_a_bug_fixes'
            test_part_a_bug_fixes();
        case 'test_part_b_step9_ui_structure'
            test_part_b_step9_ui_structure();
        case 'test_part_b_step10_app_skeleton'
            test_part_b_step10_app_skeleton();
        case 'test_part_b_step11_core_views'
            test_part_b_step11_core_views();
        case 'test_part_b_step12_scenarios_view'
            test_part_b_step12_scenarios_view();
        case 'test_part_b_step13_results_view'
            test_part_b_step13_results_view();
        case 'test_part_b_step14_export_view'
            test_part_b_step14_export_view();
        otherwise
            error('app_test_runner:unknownTest', 'Unknown or unsupported test: %s', testName);
    end

    % --- Section 2: PASS result ---
    result.status = 'PASS';
    result.time_s = toc(ticId);
    result.message = sprintf('PASS in %.2f s', result.time_s);
    result.detail = { ...
        sprintf('Test: %s', testName), ...
        'Status: PASS', ...
        sprintf('Runtime: %.2f s', result.time_s), ...
        'The detailed PASS lines were printed to the MATLAB Command Window.'};
catch ME
    % --- Section 3: FAIL result ---
    result.status = 'FAIL';
    result.time_s = toc(ticId);
    result.message = ME.message;
    result.error_id = ME.identifier;
    result.detail = { ...
        sprintf('Test: %s', testName), ...
        'Status: FAIL', ...
        sprintf('Runtime: %.2f s', result.time_s), ...
        sprintf('Error ID: %s', ME.identifier), ...
        sprintf('Message: %s', ME.message)};
end
end

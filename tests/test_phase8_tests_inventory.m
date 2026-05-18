function test_phase8_tests_inventory()
% TEST_PHASE8_TESTS_INVENTORY Validate final test-suite coverage and bug-fix checks.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None.
%
% Outputs:
%   Prints PASS/FAIL validation results.
%
% Example:
%   test_phase8_tests_inventory()

fprintf('\n[test_phase8_tests_inventory] Starting Phase 8 validation-suite inventory...\n');

cfg = config_loader();
report = verify_known_bug_fixes(cfg);
assert_pass(report.all_passed, sprintf('Known bug-fix verification passed: %d/%d', report.pass_count, numel(report.items)));

requiredTests = {
    'test_config_loader.m'
    'test_survey_schema.m'
    'test_phase0_io.m'
    'test_phase1_feeder.m'
    'test_bfs_power_flow.m'
    'test_pq_indices.m'
    'test_simulate_occupancy.m'
    'test_ev_model.m'
    'test_simulate_household.m'
    'test_phase2_load_model.m'
    'test_pricing.m'
    'test_phase3_pricing.m'
    'test_milp.m'
    'test_phase4_dsm.m'
    'test_phase5_scenarios.m'
    'test_phase6_visualization.m'
    'test_phase7_household_twin.m'
    'test_phase8_tests_inventory.m'
    'test_phase9_main_export.m'
};

testsDir = fileparts(mfilename('fullpath'));
for i = 1:numel(requiredTests)
    p = fullfile(testsDir, requiredTests{i});
    assert_pass(isfile(p), sprintf('Required test exists: %s', requiredTests{i}));
end

runnerPath = fullfile(testsDir, 'run_config_tests.m');
runnerText = fileread(runnerPath);
for i = 1:numel(requiredTests)
    [~, fn] = fileparts(requiredTests{i});
    assert_pass(contains(runnerText, [fn '(']), sprintf('run_config_tests calls %s', fn));
end

checklist = export_results_tables({}, cfg);
assert_pass(isfile(checklist.deliverables_checklist), 'Deliverables checklist CSV is exportable without scenario results');

fprintf('[test_phase8_tests_inventory] Complete. Phase 8 validation-suite inventory passed.\n');
end

function assert_pass(condition, message)
% ASSERT_PASS Print PASS/FAIL and throw on failure.
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase8_tests_inventory:assertionFailed', '%s', message);
end
end

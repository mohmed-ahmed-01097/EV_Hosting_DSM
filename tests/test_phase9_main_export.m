function test_phase9_main_export()
% TEST_PHASE9_MAIN_EXPORT Validate final main/export deliverables on synthetic results.
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
%   test_phase9_main_export()

fprintf('\n[test_phase9_main_export] Starting Phase 9 main/export validation...\n');

cfg = config_loader();
all_results = build_export_test_results(cfg);
info = export_results_tables(all_results, cfg);

assert_pass(isfile(info.scenario_summary), 'scenario_summary.csv exported');
assert_pass(isfile(info.cost_summary), 'scenario_cost_summary.csv exported');
assert_pass(isfile(info.comfort_summary), 'scenario_comfort_summary.csv exported');
assert_pass(isfile(info.violations), 'scenario_violations.csv exported');
assert_pass(isfile(info.deliverables_checklist), 'deliverables_checklist.csv exported');
assert_pass(info.num_scenarios == 3, sprintf('Exported scenario rows = %d', info.num_scenarios));
assert_pass(info.num_cost_rows >= 6, sprintf('Exported cost rows = %d', info.num_cost_rows));

mainText = fileread(fullfile(cfg.root_folder, 'src', 'main.m'));
assert_pass(contains(mainText, 'export_results_tables'), 'main.m calls export_results_tables after scenario execution');
assert_pass(contains(mainText, 'all_scenarios'), 'main.m supports all_scenarios mode');
assert_pass(contains(mainText, 'validate'), 'main.m supports validate mode');

summaryTable = readtable(info.scenario_summary);
assert_pass(all(ismember({'scenario_id','max_vuf_pct','min_voltage_pu','max_loading_pct'}, summaryTable.Properties.VariableNames)), ...
    'scenario_summary.csv has thesis metric columns');

fprintf('[test_phase9_main_export] Complete. Phase 9 main/export validation passed.\n');
end

function all_results = build_export_test_results(cfg)
% BUILD_EXPORT_TEST_RESULTS Create compact scenario results for export tests.
ids = [-1 1 6];
desc = {'Baseline 0', 'Uncontrolled EV integration', 'Full hierarchical AI-DSM'};
all_results = cell(1, numel(ids));
for i = 1:numel(ids)
    H = 4;
    T = 24 * 60 / cfg.simulation.dt_min;
    r = struct();
    r.scenario_id = ids(i);
    r.description = desc{i};
    r.pq_summary = struct();
    r.pq_summary.mean_vuf_pct = 0.6 + 0.4 * i;
    r.pq_summary.max_vuf_pct = 1.0 + 0.8 * i;
    r.pq_summary.min_voltage_pu = 0.99 - 0.02 * i;
    r.pq_summary.max_loading_pct = 70 + 10 * i;
    r.pq_summary.max_iuf_pct = 2 + i;
    r.pq_summary.max_ncr_pct = 10 + i;
    r.pq_summary.mean_loss_kw = 1.0 + 0.2 * i;
    r.pq_summary.mean_loss_kvar = 0.8 + 0.1 * i;
    r.pq_summary.violation_count = max(0, i - 2);
    r.pq_summary.violation_steps = 1:r.pq_summary.violation_count;
    r.pq_summary.non_converged_steps = [];
    r.pq_summary.has_violations = r.pq_summary.violation_count > 0;
    r.costs = struct();
    r.costs.bill_total = struct();
    r.costs.bill_total.Flat = (70 + 5*i) * ones(H, 1);
    r.costs.bill_total.Block = (80 + 7*i) * ones(H, 1);
    r.costs.energy_monthly_kwh = (120 + 10*i) * ones(H, 1);
    r.hosting_capacity_pct = 10 + 10 * i;
    r.comfort_summary = struct('mean', min(1, 0.6 + 0.08*i), 'min', 0.5, 'max', 0.95, 'count', H, 'note', 'synthetic');
    r.L_house_w = 500 * ones(T, H) + 20*i;
    r.runtime_s = i;
    r.metadata = struct('dt_min', cfg.simulation.dt_min, 'created_on', datestr(now, 31));
    all_results{i} = r;
end
end

function assert_pass(condition, message)
% ASSERT_PASS Print PASS/FAIL and throw on failure.
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase9_main_export:assertionFailed', '%s', message);
end
end

function test_pdf_report_and_results_sanity_patch()
% TEST_PDF_REPORT_AND_RESULTS_SANITY_PATCH Verify PDF layout/report and calibration patch.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   PASS/FAIL assertions for the report and calibration patch.

fprintf('\n[test_pdf_report_and_results_sanity_patch] Starting PDF/results sanity patch validation...\n');

cfg = config_loader([]);
assert_pass(isfield(cfg, 'calibration'), 'Configuration has calibration block');
assert_pass(cfg.calibration.enable_feeder_load_calibration == true, 'Feeder load calibration enabled by default');
assert_pass(cfg.calibration.target_baseline_vmin_pu >= 0.90, 'Calibration target Vmin is realistic');

coreText = fileread(fullfile(cfg.root_folder, 'src', 'scenarios', 'run_scenario_core.m'));
assert_pass(contains(coreText, 'apply_feeder_load_calibration_if_needed'), 'Scenario core applies feeder load calibration');
assert_pass(contains(coreText, 'p_original_total_w'), 'Scenario core preserves original daily profile for peak guard');

r = make_synthetic_result(-1, 'Baseline 0 synthetic', 0.4, 1.1, 0.96, 78, 25, 2400, 0.9);
r2 = make_synthetic_result(1, 'Scenario 1 synthetic', 0.7, 2.2, 0.92, 105, 15, 3200, NaN);
opts = struct();
opts.output_dir = fullfile(cfg.output_dir, 'test_pdf_patch');
opts.name = 'test_pdf_results_sanity_patch';
opts.author = 'Mohammed Ahmed';
opts.report_date = '2026-05';
opts.selected_figures = {'vuf_comparison','hosting_capacity','monthly_bill_box','bus_voltage_map'};
if exist(opts.output_dir, 'dir') ~= 7, mkdir(opts.output_dir); end
outFile = app_pdf_report({r; r2}, cfg, opts);
assert_pass(isfile(outFile), ['Generated PDF report exists: ', outFile]);
info = dir(outFile);
assert_pass(info.bytes > 10000, sprintf('Generated PDF report size is nontrivial: %.1f kB', info.bytes/1024));

pdfText = fileread(fullfile(cfg.root_folder, 'src', 'ui', 'app_helpers', 'app_pdf_report.m'));
assert_pass(contains(pdfText, 'Automatic Results Review'), 'PDF report includes automatic results review page');
assert_pass(contains(pdfText, 'Annual Block'), 'PDF report labels annual block cost explicitly');
assert_pass(contains(pdfText, 'Monthly Block'), 'PDF report labels monthly average block cost explicitly');

fprintf('[test_pdf_report_and_results_sanity_patch] Complete. Patch validation passed.\n');
end

function r = make_synthetic_result(sid, desc, meanVuf, maxVuf, vmin, maxTl, hosting, blockBill, ci)
r = struct();
r.scenario_id = sid;
r.description = desc;
r.pq_summary = struct();
r.pq_summary.mean_vuf_pct = meanVuf;
r.pq_summary.max_vuf_pct = maxVuf;
r.pq_summary.min_voltage_pu = vmin;
r.pq_summary.max_loading_pct = maxTl;
r.pq_summary.mean_loss_kw = 2.3;
r.hosting_capacity_pct = hosting;
r.comfort_summary = struct('mean', ci, 'min', ci, 'max', ci, 'count', 1);
r.L_feeder_w = single(repmat([10000 9500 9000], 96, 1));
r.costs = struct();
r.costs.bill_total = struct();
methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
for k = 1:numel(methods)
    r.costs.bill_total.(methods{k}) = blockBill * (0.45 + 0.10*k) * ones(3,1);
end
r.costs.month_labels = arrayfun(@(m) sprintf('2025-%02d', m), 1:12, 'UniformOutput', false);
r.metadata = struct('storage_mode', 'lean');
end

function assert_pass(cond, msg)
if cond
    fprintf('  PASS: %s\n', msg);
else
    fprintf('  FAIL: %s\n', msg);
    error('test_pdf_report_and_results_sanity_patch:assertion', msg);
end
end

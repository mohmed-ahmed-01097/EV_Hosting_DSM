function test_part_b_pdf_export_report()
% TEST_PART_B_PDF_EXPORT_REPORT Validate full PDF report export helper.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL status.
%
% Example:
%   test_part_b_pdf_export_report()

fprintf('\n[test_part_b_pdf_export_report] Starting PDF report export validation...\n');

cfg = config_loader([]);
outDir = fullfile(cfg.output_dir, 'ui_pdf_report_test');
if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
opts = struct();
opts.output_dir = outDir;
opts.name = 'ui_pdf_report_test';
opts.author = 'Mohammed Ahmed';
opts.report_date = datestr(now, 'yyyy-mm-dd');
opts.selected_figures = {'vuf_comparison','hosting_capacity','monthly_bill_box','bus_voltage_map'};

r1 = makeSyntheticResult(-1, 'Baseline 0', 0.55, 0.95, 70, 0, 0.95, 420);
r2 = makeSyntheticResult(1, 'Scenario 1 uncontrolled EV', 2.40, 0.89, 110, 20, NaN, 610);
r3 = makeSyntheticResult(4, 'Scenario 4 MILP loads plus EV', 1.70, 0.92, 86, 35, 0.76, 515);
results = {r1; r2; r3};

pdfPath = app_pdf_report(results, cfg, opts);
assert_pass(isfile(pdfPath), ['PDF file created: ', pdfPath]);
info = dir(pdfPath);
assert_pass(info.bytes > 1000, sprintf('PDF file is non-empty: %.1f kB', info.bytes/1024));

helperPath = app_export_helper('pdf_report', results, cfg, opts);
assert_pass(isfile(helperPath), 'app_export_helper pdf_report dispatch works');

fprintf('[test_part_b_pdf_export_report] Complete. PDF export report validation passed.\n');
end

function r = makeSyntheticResult(id, description, meanVuf, minV, maxTl, hosting, ci, blockBill)
r = struct();
r.scenario_id = id;
r.description = description;
r.pq_summary = struct();
r.pq_summary.mean_vuf_pct = meanVuf;
r.pq_summary.max_vuf_pct = meanVuf * 1.45;
r.pq_summary.min_voltage_pu = minV;
r.pq_summary.max_loading_pct = maxTl;
r.pq_summary.total_losses_kw = 5 + 0.1 * maxTl;
r.hosting_capacity_pct = hosting;
r.comfort_summary = struct('mean_ci', ci, 'min_ci', max(0, ci - 0.1));
r.costs = struct();
r.costs.bill_total = struct();
r.costs.bill_total.Block = blockBill + (0:9)';
r.costs.bill_total.Flat = blockBill*0.95 + (0:9)';
r.costs.bill_total.TOU = blockBill*0.90 + (0:9)';
r.costs.bill_total.RTP = blockBill*0.88 + (0:9)';
r.costs.bill_total.Seasonal = blockBill*0.92 + (0:9)';
r.costs.bill_total.CPP = blockBill*1.05 + (0:9)';
r.costs.bill_total.RGDP = blockBill*0.86 + (0:9)';
r.L_feeder_w = [linspace(1000, 3000, 96)', linspace(900, 2600, 96)', linspace(800, 2400, 96)'];
end

function assert_pass(cond, msg)
if cond
    fprintf('  PASS: %s\n', msg);
else
    fprintf('  FAIL: %s\n', msg);
    error('test_part_b_pdf_export_report:assertionFailed', msg);
end
end

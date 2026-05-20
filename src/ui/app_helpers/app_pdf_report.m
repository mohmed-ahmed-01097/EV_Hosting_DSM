function outFile = app_pdf_report(results, cfg, opts)
% APP_PDF_REPORT Generate a modern, thesis-ready scenario PDF report.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   results - cell/struct array of scenario result structs.
%   cfg     - project configuration struct.
%   opts    - options struct: output_dir, name, author, report_date,
%             selected_figures.
%
% Outputs:
%   outFile - generated PDF path.

if nargin < 3 || isempty(opts), opts = struct(); end
if nargin < 2 || isempty(cfg), cfg = struct(); end
if nargin < 1, results = {}; end

items = normalize_results_pdf(results);
if isempty(items)
    error('app_pdf_report:noResults', 'No scenario results available for PDF report. Run scenarios first.');
end

outRoot = get_report_root(cfg, opts);
reportDir = fullfile(outRoot, 'reports');
if exist(reportDir, 'dir') ~= 7, mkdir(reportDir); end

reportName = get_opt_pdf(opts, 'name', ['ev_dsm_full_report_', datestr(now, 'yyyymmdd_HHMMSS')]);
outFile = fullfile(reportDir, [sanitize_filename(reportName), '.pdf']);
if isfile(outFile), delete(outFile); end

authorName = get_opt_pdf(opts, 'author', 'Mohammed Ahmed');
reportDate = get_opt_pdf(opts, 'report_date', datestr(now, 'yyyy-mm-dd'));
selectedFigures = get_opt_pdf(opts, 'selected_figures', {'vuf_comparison','hosting_capacity','load_profiles','monthly_bill_box','bus_voltage_map'});
if ischar(selectedFigures) || isstring(selectedFigures), selectedFigures = cellstr(selectedFigures); end

append = false;
page = make_pdf_page('cover');
draw_cover_page(page, cfg, items, authorName, reportDate);
append_pdf_page(page, outFile, append); append = true; close(page);

page = make_pdf_page('quality_review');
draw_quality_review_page(page, cfg, items);
append_pdf_page(page, outFile, append); close(page);

page = make_pdf_page('configuration');
draw_config_page(page, cfg);
append_pdf_page(page, outFile, append); close(page);

page = make_pdf_page('scenario_summary');
draw_scenario_summary_page(page, cfg, items);
append_pdf_page(page, outFile, append); close(page);

page = make_pdf_page('cost_summary');
draw_cost_summary_page(page, items);
append_pdf_page(page, outFile, append); close(page);

for k = 1:numel(selectedFigures)
    figKey = lower(char(string(selectedFigures{k})));
    page = make_pdf_page(['plot_', figKey]);
    draw_plot_page(page, figKey, items, cfg);
    append_pdf_page(page, outFile, append); close(page);
end

page = make_pdf_page('appendix');
draw_appendix_page(page, cfg, items);
append_pdf_page(page, outFile, append); close(page);

fprintf('[app_pdf_report] Generated PDF report: %s\n', outFile);
end

function fig = make_pdf_page(name)
fig = figure('Visible', 'off', 'Color', 'w', 'Name', name, 'NumberTitle', 'off', ...
    'Units', 'pixels', 'Position', [100 100 1120 790], 'PaperOrientation', 'landscape');
end

function append_pdf_page(fig, outFile, append)
try
    exportgraphics(fig, outFile, 'ContentType', 'vector', 'Append', append);
catch
    warning('app_pdf_report:appendFallback', 'PDF append failed. Falling back to print for this page.');
    print(fig, outFile, '-dpdf', '-bestfit');
end
end

function [ax, c] = page_canvas(fig, titleText, subtitleText)
c.bg = [1 1 1];
c.dark = [0.07 0.09 0.18];
c.panel = [0.95 0.965 0.985];
c.panel2 = [0.90 0.93 0.965];
c.accent = [0.00 0.50 0.66];
c.green = [0.13 0.55 0.34];
c.yellow = [0.90 0.62 0.10];
c.red = [0.75 0.16 0.16];
c.text = [0.10 0.12 0.18];
c.muted = [0.38 0.43 0.52];
ax = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off');
xlim(ax, [0 1]); ylim(ax, [0 1]); hold(ax, 'on');
rectangle(ax, 'Position', [0 0.91 1 0.09], 'FaceColor', c.dark, 'EdgeColor', 'none');
text(ax, 0.035, 0.955, titleText, 'FontSize', 20, 'FontWeight', 'bold', ...
    'Color', 'w', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
text(ax, 0.035, 0.925, subtitleText, 'FontSize', 9.5, 'Color', [0.80 0.86 0.93], ...
    'VerticalAlignment', 'middle', 'Interpreter', 'none');
text(ax, 0.965, 0.955, datestr(now, 'yyyy-mm-dd HH:MM'), 'HorizontalAlignment', 'right', ...
    'FontSize', 9, 'Color', [0.80 0.86 0.93]);
end

function draw_cover_page(fig, cfg, items, authorName, reportDate)
[ax, c] = page_canvas(fig, 'EV Hosting DSM Simulator', 'Full scenario report - configuration, scenario KPIs, costs, and plots');
rectangle(ax, 'Position', [0.06 0.18 0.88 0.64], 'FaceColor', c.panel, 'EdgeColor', [0.78 0.82 0.88]);
text(ax, 0.10, 0.72, 'AI-Driven DSM for EV Hosting Capacity and Power Quality', ...
    'FontSize', 24, 'FontWeight', 'bold', 'Color', c.text, 'Interpreter', 'none');
text(ax, 0.10, 0.66, 'Radial LV distribution feeder - Assiut, Egypt', ...
    'FontSize', 14, 'Color', c.muted, 'Interpreter', 'none');

meta = {
    'Author', authorName;
    'Report date', reportDate;
    'Generated on', datestr(now, 31);
    'Scenario results', num2str(numel(items));
    'Storage mode', get_nested_string(cfg, {'results','storage_mode'}, 'unknown');
    'Simulation period', sprintf('%s to %s', get_nested_string(cfg, {'simulation','start_date'}, '?'), get_nested_string(cfg, {'simulation','end_date'}, '?'));
    'Time step', [get_nested_string(cfg, {'simulation','dt_min'}, '?'), ' min'];
    'EV penetration', [num2str(100*get_nested_number(cfg, {'ev','penetration_rate'}, NaN), '%.1f'), ' %']
    };
draw_kv_block(ax, 0.10, 0.55, 0.42, 0.32, meta, 'Report metadata');

b0 = find_baseline(items);
if ~isempty(b0)
    cards = {
        'Baseline Vmin', fmt_num(result_metric_pdf(b0, 'min_voltage_pu'), '%.3f pu');
        'Baseline max TL', fmt_num(result_metric_pdf(b0, 'max_loading_pct'), '%.1f %%');
        'Baseline peak VUF', fmt_num(result_metric_pdf(b0, 'max_vuf_pct'), '%.2f %%');
        'Storage policy', get_nested_string(cfg, {'results','storage_mode'}, 'lean')
        };
else
    cards = {'Status','No baseline result found'; 'Storage policy', get_nested_string(cfg, {'results','storage_mode'}, 'lean')};
end
draw_metric_cards(ax, 0.56, 0.55, 0.34, 0.32, cards, c);

text(ax, 0.10, 0.12, 'Note: the report uses lean scenario results. Full household and per-step debug traces are intentionally not required.', ...
    'FontSize', 10, 'Color', c.muted, 'Interpreter', 'none');
end

function draw_quality_review_page(fig, cfg, items)
[ax, c] = page_canvas(fig, 'Automatic Results Review', 'Sanity checks and likely root-cause indicators before thesis interpretation');
flags = build_quality_flags(cfg, items);
summary = flags(:, 1:3);
draw_table(ax, 0.05, 0.78, 0.90, 0.055, {'Check','Status','Finding'}, summary, 'Result sanity checks', 8);

text(ax, 0.06, 0.25, 'Recommended action:', 'FontSize', 12, 'FontWeight', 'bold', 'Color', c.text);
rec = {
    '1. If the no-EV baseline violates voltage/loading limits, rerun scenarios after feeder load calibration.'
    '2. Interpret bill_total values as annual totals unless the table explicitly states monthly average.'
    '3. If hosting capacity is 0% for all scenarios, the baseline is already infeasible or the hosting screen is too strict.'
    '4. Use representative mode for UI previews, then run final thesis cases from main([], ''all_scenarios'').' };
for i = 1:numel(rec)
    text(ax, 0.07, 0.215 - 0.035*(i-1), rec{i}, 'FontSize', 10, 'Color', c.muted, 'Interpreter', 'none');
end
end

function draw_config_page(fig, cfg)
[ax, ~] = page_canvas(fig, 'Used Configuration', 'Main simulation, EV, DSM, pricing, calibration, HVAC, and PQ settings used for the report');
simPairs = {
    'Project', get_nested_string(cfg, {'project_name'}, 'EV_Hosting_DSM');
    'Location', [get_nested_string(cfg, {'location','city'}, 'Assiut'), ', ', get_nested_string(cfg, {'location','country'}, 'Egypt')];
    'Start date', get_nested_string(cfg, {'simulation','start_date'}, '?');
    'End date', get_nested_string(cfg, {'simulation','end_date'}, '?');
    'dt_min', get_nested_string(cfg, {'simulation','dt_min'}, '?');
    'Mode', get_nested_string(cfg, {'simulation','mode'}, '?');
    'Households', get_nested_string(cfg, {'feeder','num_households'}, '?');
    'Transformer zones', get_nested_string(cfg, {'feeder','num_transformer_zones'}, '?')
    };
evPairs = {
    'EV penetration', [num2str(100*get_nested_number(cfg, {'ev','penetration_rate'}, NaN), '%.1f'), ' %'];
    'Charger type', get_nested_string(cfg, {'ev','charger_type'}, '?');
    'Slow charger', [get_nested_string(cfg, {'ev','slow_kw'}, '?'), ' kW'];
    'Fast charger', [get_nested_string(cfg, {'ev','fast_kw'}, '?'), ' kW'];
    'V2G enabled', get_nested_string(cfg, {'ev','v2g_enabled'}, '?');
    'V2G revenue fraction', get_nested_string(cfg, {'ev','v2g_revenue_fraction'}, '?');
    'SOC minimum', [get_nested_string(cfg, {'ev','soc_min_pct'}, '?'), ' %'];
    'SOC target', [get_nested_string(cfg, {'ev','soc_target_pct'}, '?'), ' %']
    };
dsmPairs = {
    'Controller', get_nested_string(cfg, {'dsm','controller'}, '?');
    'Horizon steps', get_nested_string(cfg, {'dsm','scheduling_horizon_steps'}, '?');
    'Coordination iterations', get_nested_string(cfg, {'dsm','max_coordination_iterations'}, '?');
    'lambda comfort', get_nested_string(cfg, {'dsm','lambda_comfort'}, '?');
    'Comfort CI threshold', get_nested_string(cfg, {'dsm','comfort_ci_threshold'}, '?');
    'Local peak guard', get_nested_string(cfg, {'dsm','local_peak_limit_multiplier'}, '?');
    'Main pricing method', get_nested_string(cfg, {'pricing','main_method'}, '?');
    'Block slabs', value_to_short_string(get_nested_value(cfg, {'pricing','block_slabs_kwh'}, []))
    };
pqPairs = {
    'VUF limit', [get_nested_string(cfg, {'pq_limits','vuf_max_pct'}, '?'), ' %'];
    'Voltage min', [get_nested_string(cfg, {'pq_limits','voltage_min_pu'}, '?'), ' pu'];
    'Voltage max', [get_nested_string(cfg, {'pq_limits','voltage_max_pu'}, '?'), ' pu'];
    'THDv limit', [get_nested_string(cfg, {'pq_limits','thdv_max_pct'}, '?'), ' %'];
    'THDi limit', [get_nested_string(cfg, {'pq_limits','thdi_max_pct'}, '?'), ' %'];
    'NCR limit', [get_nested_string(cfg, {'pq_limits','ncr_max_pct'}, '?'), ' %'];
    'Transformer loading limit', [get_nested_string(cfg, {'pq_limits','transformer_loading_max_pct'}, '?'), ' %'];
    'HVAC summer setpoint', [get_nested_string(cfg, {'hvac','summer_setpoint_c'}, '?'), ' C']
    };
calPairs = {
    'Load calibration enabled', get_nested_string(cfg, {'calibration','enable_feeder_load_calibration'}, 'false');
    'Target baseline TL', [get_nested_string(cfg, {'calibration','target_baseline_loading_pct'}, '?'), ' %'];
    'Target baseline Vmin', [get_nested_string(cfg, {'calibration','target_baseline_vmin_pu'}, '?'), ' pu'];
    'Minimum scale', get_nested_string(cfg, {'calibration','min_load_scale'}, '?');
    'Sample steps', get_nested_string(cfg, {'calibration','sample_steps'}, '?')
    };

draw_kv_block(ax, 0.05, 0.80, 0.28, 0.30, simPairs, 'Simulation and feeder');
draw_kv_block(ax, 0.37, 0.80, 0.28, 0.30, evPairs, 'EV configuration');
draw_kv_block(ax, 0.69, 0.80, 0.26, 0.30, pqPairs, 'PQ and HVAC limits');
draw_kv_block(ax, 0.05, 0.43, 0.42, 0.30, dsmPairs, 'DSM and pricing');
draw_kv_block(ax, 0.53, 0.43, 0.42, 0.30, calPairs, 'Calibration');
end

function draw_scenario_summary_page(fig, cfg, items)
[ax, c] = page_canvas(fig, 'Scenario Results Summary', 'Power-quality, hosting-capacity, annual cost, and monthly-average bill KPIs');
cells = scenario_kpi_cells(items, cfg);
draw_table(ax, 0.035, 0.79, 0.93, 0.043, cells(1,:), cells(2:end,:), 'Scenario KPI matrix', 12);
text(ax, 0.05, 0.18, 'Interpretation guide:', 'FontSize', 12, 'FontWeight', 'bold', 'Color', c.text);
notes = {
    'Peak VUF should be checked against the configured VUF limit, not only mean VUF.'
    'Vmin should remain above the configured voltage minimum.'
    'Max TL above 100% means transformer thermal overload.'
    'Annual Block EGP/HH is total yearly bill per household; Monthly Block EGP/HH is annual divided by billing periods.'
    };
for i = 1:numel(notes)
    text(ax, 0.06, 0.15 - 0.033*(i-1), ['- ', notes{i}], 'FontSize', 9.5, 'Color', c.muted, 'Interpreter', 'none');
end
end

function draw_cost_summary_page(fig, items)
[ax, ~] = page_canvas(fig, 'Cost and Comfort Summary', 'Annual electricity bill, average monthly bill, tariff comparison, and user comfort');
headers = {'Scenario','Annual Block','Monthly Block','Annual Flat','Annual TOU','Mean CI','Min CI'};
data = cell(numel(items), numel(headers));
for i = 1:numel(items)
    r = items{i}; nM = result_num_periods_pdf(r);
    blockAnnual = mean(result_bills_pdf(r, 'Block'), 'omitnan');
    data{i,1} = result_label_pdf(r, i);
    data{i,2} = fmt_num(blockAnnual, '%.1f');
    data{i,3} = fmt_num(blockAnnual / max(nM,1), '%.1f');
    data{i,4} = fmt_num(mean(result_bills_pdf(r, 'Flat'), 'omitnan'), '%.1f');
    data{i,5} = fmt_num(mean(result_bills_pdf(r, 'TOU'), 'omitnan'), '%.1f');
    data{i,6} = fmt_num(result_comfort_pdf(r, 'mean'), '%.3f');
    data{i,7} = fmt_num(result_comfort_pdf(r, 'min'), '%.3f');
end
draw_table(ax, 0.06, 0.79, 0.86, 0.045, headers, data, 'Cost and comfort table - EGP per household', 12);

ax2 = axes(fig, 'Position', [0.12 0.12 0.76 0.34], 'Color', 'w');
labels = cellfun(@(r) result_label_pdf(r, 1), items, 'UniformOutput', false);
vals = cellfun(@(r) mean(result_bills_pdf(r, 'Block'), 'omitnan'), items) / 1000;
bar(ax2, categorical(labels), vals, 'FaceColor', [0.00 0.50 0.66]);
ylabel(ax2, 'Annual Block Bill [kEGP/HH]'); title(ax2, 'Block-tariff annual bill comparison');
grid(ax2, 'on'); style_pdf_axes(ax2); ax2.YAxis.Exponent = 0;
end

function draw_plot_page(fig, figKey, items, cfg)
[~, ~] = page_canvas(fig, ['Plot - ', strrep(figKey, '_', ' ')], 'Generated from retained lean scenario-result fields');
ax = axes(fig, 'Position', [0.10 0.14 0.82 0.68], 'Color', 'w');
hold(ax, 'on');
labels = cellfun(@(r) result_label_pdf(r, 1), items, 'UniformOutput', false);
switch figKey
    case {'vuf_comparison','scenario_comparison'}
        vals = cellfun(@(r) result_metric_pdf(r, 'mean_vuf_pct'), items);
        bar(ax, categorical(labels), vals, 'FaceColor', [0.00 0.50 0.66]);
        ylabel(ax, 'Mean VUF [%]'); title(ax, 'Voltage unbalance comparison');
        lim = get_nested_number(cfg, {'pq_limits','vuf_max_pct'}, 2);
        try, yline(ax, lim, '--r', 'VUF limit', 'LineWidth', 1.1); catch, end
        finiteVals = vals(isfinite(vals)); if isempty(finiteVals), finiteVals = 0; end
        ylim(ax, [0 max([lim*1.15, max(finiteVals)*1.20, 1])]);
    case 'hosting_capacity'
        vals = cellfun(@(r) result_metric_pdf(r, 'hosting_capacity_pct'), items);
        vals(~isfinite(vals)) = 0;
        bar(ax, categorical(labels), vals, 'FaceColor', [0.13 0.55 0.34]);
        ylabel(ax, 'EV Hosting Capacity [%]'); title(ax, 'Hosting capacity by scenario');
        finiteVals = vals(isfinite(vals)); if isempty(finiteVals), finiteVals = 0; end
        ymax = max(50, ceil(max(finiteVals)*1.2/5)*5);
        ylim(ax, [0 ymax]);
        if max(finiteVals) <= 0
            text(ax, 0.5, 0.88, 'All scenarios show 0% hosting in the saved results. Check baseline feasibility/calibration.', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.75 0.16 0.16]);
        end
    case 'load_profiles'
        r = first_with_field_pdf(items, 'L_feeder_w');
        if isempty(r)
            text(ax, 0.1, 0.5, 'No retained L_feeder_w data available.', 'Units', 'normalized'); axis(ax, 'off'); return;
        end
        L = double(r.L_feeder_w); n = min(size(L,1), 96); x = (0:n-1) * 24 / max(n,1);
        plot(ax, x, L(1:n,:) / 1000, 'LineWidth', 1.4);
        xlabel(ax, 'Hour'); ylabel(ax, 'Power [kW]'); title(ax, 'Representative daily three-phase feeder load');
        legend(ax, {'Phase A','Phase B','Phase C'}, 'Location', 'best');
        xlim(ax, [0 24]);
    case {'monthly_bill_box','cost_box'}
        methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
        vals = nan(numel(items), numel(methods));
        for i = 1:numel(items)
            for m = 1:numel(methods)
                vals(i,m) = mean(result_bills_pdf(items{i}, methods{m}), 'omitnan') / 1000;
            end
        end
        bar(ax, vals); ax.XTick = 1:numel(labels); ax.XTickLabel = labels;
        ylabel(ax, 'Annual Bill [kEGP/HH]'); title(ax, 'Tariff annual cost comparison');
        legend(ax, methods, 'Location', 'eastoutside'); ax.YAxis.Exponent = 0;
    case {'bus_voltage_map','pq_timeseries'}
        vals = cellfun(@(r) result_metric_pdf(r, 'min_voltage_pu'), items);
        bar(ax, categorical(labels), vals, 'FaceColor', [0.70 0.42 0.12]);
        ylabel(ax, 'Minimum Voltage [pu]'); title(ax, 'Minimum voltage by scenario');
        lim = get_nested_number(cfg, {'pq_limits','voltage_min_pu'}, 0.90);
        try, yline(ax, lim, '--r', 'Voltage limit', 'LineWidth', 1.1); catch, end
        finiteVals = vals(isfinite(vals)); if isempty(finiteVals), finiteVals = lim; end
        ylim(ax, [max(0.70, min(finiteVals)-0.05) 1.02]);
    case 'tariff_slab_migration'
        vals = cellfun(@(r) mean(result_bills_pdf(r, 'Block'), 'omitnan'), items) / 1000;
        bar(ax, categorical(labels), vals, 'FaceColor', [0.40 0.22 0.65]);
        ylabel(ax, 'Annual Block Bill [kEGP/HH]'); title(ax, 'Approximate tariff impact by scenario'); ax.YAxis.Exponent = 0;
    otherwise
        vals = cellfun(@(r) result_metric_pdf(r, 'mean_vuf_pct'), items);
        bar(ax, categorical(labels), vals, 'FaceColor', [0.00 0.50 0.66]);
        ylabel(ax, 'Metric'); title(ax, strrep(figKey, '_', ' '));
end
grid(ax, 'on'); style_pdf_axes(ax);
end

function draw_appendix_page(fig, cfg, items)
[ax, ~] = page_canvas(fig, 'Report Appendix', 'Files, storage policy, and scenario descriptions');
lines = {};
lines{end+1} = ['Output directory: ', get_nested_string(cfg, {'output_dir'}, '?')];
lines{end+1} = ['Figures directory: ', get_nested_string(cfg, {'figs_dir'}, '?')];
lines{end+1} = ['Tables directory: ', get_nested_string(cfg, {'tables_dir'}, '?')];
lines{end+1} = ['Results storage mode: ', get_nested_string(cfg, {'results','storage_mode'}, 'unknown')];
lines{end+1} = ' ';
lines{end+1} = 'Scenario descriptions:';
for i = 1:numel(items)
    desc = '?';
    try, desc = char(string(items{i}.description)); catch, end
    lines{end+1} = sprintf('%s - %s', result_label_pdf(items{i}, i), desc); %#ok<AGROW>
end
text(ax, 0.06, 0.80, lines, 'FontName', 'Consolas', 'FontSize', 10, 'Color', [0.1 0.12 0.18], ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');
end

function draw_metric_cards(ax, x, y, w, h, cards, c)
n = size(cards,1); cols = 2; rows = ceil(n/cols);
cardW = (w - 0.025) / cols; cardH = (h - 0.025*(rows-1)) / rows;
for i = 1:n
    col = mod(i-1, cols); row = floor((i-1)/cols);
    xx = x + col*(cardW+0.025); yy = y - row*(cardH+0.025) - cardH;
    rectangle(ax, 'Position', [xx yy cardW cardH], 'FaceColor', [1 1 1], 'EdgeColor', [0.78 0.82 0.88]);
    text(ax, xx+0.018, yy+cardH*0.62, cards{i,1}, 'FontSize', 9, 'FontWeight', 'bold', 'Color', c.muted, 'Interpreter', 'none');
    text(ax, xx+0.018, yy+cardH*0.30, cards{i,2}, 'FontSize', 14, 'FontWeight', 'bold', 'Color', c.accent, 'Interpreter', 'none');
end
end

function draw_kv_block(ax, x, y, w, h, pairs, titleText)
rectangle(ax, 'Position', [x y-h w h], 'FaceColor', [0.95 0.965 0.985], 'EdgeColor', [0.78 0.82 0.88]);
text(ax, x+0.018, y-0.035, titleText, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.07 0.09 0.18], 'Interpreter', 'none');
lineH = min(0.028, (h-0.075) / max(1, size(pairs,1)));
for i = 1:size(pairs,1)
    yy = y - 0.070 - (i-1)*lineH;
    text(ax, x+0.022, yy, char(string(pairs{i,1})), 'FontSize', 9.2, 'Color', [0.38 0.43 0.52], 'Interpreter', 'none');
    text(ax, x+w-0.022, yy, char(string(pairs{i,2})), 'FontSize', 9.2, 'Color', [0.10 0.12 0.18], ...
        'HorizontalAlignment', 'right', 'Interpreter', 'none');
end
end

function draw_table(ax, x, y, w, rowH, headers, data, titleText, maxRows)
if nargin < 9, maxRows = 12; end
nCols = numel(headers); nRows = min(size(data,1), maxRows); colW = w / nCols;
text(ax, x, y+0.035, titleText, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.07 0.09 0.18], 'Interpreter', 'none');
rectangle(ax, 'Position', [x y-rowH w rowH], 'FaceColor', [0.07 0.09 0.18], 'EdgeColor', [0.07 0.09 0.18]);
for c = 1:nCols
    text(ax, x+(c-0.5)*colW, y-rowH/2, char(string(headers{c})), 'Color', 'w', 'FontSize', 8.4, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
end
for r = 1:nRows
    yy = y - (r+1)*rowH;
    if mod(r,2)==1, fc = [0.98 0.985 0.995]; else, fc = [0.93 0.95 0.975]; end
    rectangle(ax, 'Position', [x yy w rowH], 'FaceColor', fc, 'EdgeColor', [0.82 0.85 0.90]);
    for c = 1:nCols
        text(ax, x+(c-0.5)*colW, yy+rowH/2, char(string(data{r,c})), 'Color', [0.10 0.12 0.18], 'FontSize', 8.0, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
    end
end
if size(data,1) > maxRows
    text(ax, x+w, y-(nRows+2)*rowH, sprintf('+ %d more rows in CSV exports', size(data,1)-maxRows), ...
        'HorizontalAlignment', 'right', 'FontSize', 8.5, 'Color', [0.38 0.43 0.52]);
end
end

function style_pdf_axes(ax)
ax.FontName = 'Arial'; ax.FontSize = 9.5;
ax.XColor = [0.12 0.14 0.18]; ax.YColor = [0.12 0.14 0.18];
ax.GridColor = [0.78 0.81 0.86]; ax.GridAlpha = 0.45;
box(ax, 'off');
end

function flags = build_quality_flags(cfg, items)
flags = cell(0,4);
b0 = find_baseline(items);
if isempty(b0)
    flags(end+1,:) = {'Baseline result','WARN','No baseline B0 result found','Run Baseline 0'};
else
    vmin = result_metric_pdf(b0, 'min_voltage_pu'); tl = result_metric_pdf(b0, 'max_loading_pct'); vuf = result_metric_pdf(b0, 'max_vuf_pct');
    vlim = get_nested_number(cfg, {'pq_limits','voltage_min_pu'}, 0.90); tlim = get_nested_number(cfg, {'pq_limits','transformer_loading_max_pct'}, 100); ulimit = get_nested_number(cfg, {'pq_limits','vuf_max_pct'}, 2);
    if isfinite(vmin) && vmin < vlim
        flags(end+1,:) = {'Baseline voltage','FAIL',sprintf('B0 Vmin %.3f pu is below %.3f pu', vmin, vlim),'Enable calibration and rerun'};
    else
        flags(end+1,:) = {'Baseline voltage','PASS',sprintf('B0 Vmin %.3f pu', vmin),'OK'};
    end
    if isfinite(tl) && tl > tlim
        flags(end+1,:) = {'Baseline loading','FAIL',sprintf('B0 max TL %.1f%% exceeds %.1f%%', tl, tlim),'Enable calibration and rerun'};
    else
        flags(end+1,:) = {'Baseline loading','PASS',sprintf('B0 max TL %.1f%%', tl),'OK'};
    end
    if isfinite(vuf) && vuf > ulimit
        flags(end+1,:) = {'Baseline VUF','WARN',sprintf('B0 peak VUF %.2f%% exceeds %.2f%%', vuf, ulimit),'Check phase assignment'};
    else
        flags(end+1,:) = {'Baseline VUF','PASS',sprintf('B0 peak VUF %.2f%%', vuf),'OK'};
    end
end
hostVals = cellfun(@(r) result_metric_pdf(r, 'hosting_capacity_pct'), items);
if all(~isfinite(hostVals) | hostVals <= 0)
    flags(end+1,:) = {'Hosting capacity','FAIL','All scenarios report 0% hosting','Baseline infeasible or hosting screen too strict'};
else
    flags(end+1,:) = {'Hosting capacity','PASS',sprintf('Max hosting %.1f%%', max(hostVals,[],'omitnan')),'OK'};
end
flags(end+1,:) = {'Bill units','INFO','costs.bill_total stores annual total across billing periods','Report shows annual and monthly average'};
end

function cells = scenario_kpi_cells(items, cfg)
headers = {'Scenario','Mean VUF %','Peak VUF %','Vmin pu','Max TL %','Hosting %','Annual Block','Monthly Block'};
cells = cell(numel(items)+1, numel(headers)); cells(1,:) = headers;
for i = 1:numel(items)
    r = items{i}; nM = result_num_periods_pdf(r);
    blockAnnual = mean(result_bills_pdf(r, 'Block'), 'omitnan');
    cells{i+1,1} = result_label_pdf(r, i);
    cells{i+1,2} = fmt_num(result_metric_pdf(r, 'mean_vuf_pct'), '%.3f');
    cells{i+1,3} = fmt_num(result_metric_pdf(r, 'max_vuf_pct'), '%.3f');
    cells{i+1,4} = fmt_num(result_metric_pdf(r, 'min_voltage_pu'), '%.3f');
    cells{i+1,5} = fmt_num(result_metric_pdf(r, 'max_loading_pct'), '%.1f');
    cells{i+1,6} = fmt_num(result_metric_pdf(r, 'hosting_capacity_pct'), '%.1f');
    cells{i+1,7} = fmt_num(blockAnnual, '%.1f');
    cells{i+1,8} = fmt_num(blockAnnual / max(nM,1), '%.1f');
end
if isempty(cfg) %#ok<INUSD>
end
end

function items = normalize_results_pdf(results)
if isempty(results), items = {}; return; end
if iscell(results)
    items = results(:);
elseif isstruct(results) && numel(results) > 1
    items = arrayfun(@(r) r, results(:), 'UniformOutput', false);
elseif isstruct(results)
    if isfield(results, 'slow') && isfield(results, 'fast')
        items = {results.slow; results.fast};
    else
        items = {results};
    end
else
    items = {};
end
flat = {};
for k = 1:numel(items)
    r = items{k};
    if isempty(r), continue; end
    if isstruct(r) && isfield(r, 'slow') && isfield(r, 'fast')
        flat{end+1,1} = r.slow; %#ok<AGROW>
        flat{end+1,1} = r.fast; %#ok<AGROW>
    else
        flat{end+1,1} = r; %#ok<AGROW>
    end
end
items = flat;
end

function r = find_baseline(items)
r = [];
for i = 1:numel(items)
    try
        if isequal(items{i}.scenario_id, -1)
            r = items{i}; return;
        end
    catch
    end
end
end

function label = result_label_pdf(r, fallback)
sid = NaN;
try, sid = r.scenario_id; catch, end
if isequal(sid, -1)
    label = 'B0';
elseif isfinite(sid)
    label = sprintf('S%g', sid);
else
    label = sprintf('R%d', fallback);
end
end

function v = result_metric_pdf(r, key)
v = NaN;
try
    if strcmpi(key, 'hosting_capacity_pct') && isfield(r, 'hosting_capacity_pct')
        v = mean(double(r.hosting_capacity_pct(:)), 'omitnan'); return;
    end
    if isfield(r, 'pq_summary')
        if isfield(r.pq_summary, key)
            x = r.pq_summary.(key); v = mean(double(x(:)), 'omitnan'); return;
        end
        aliases = metric_aliases(key);
        for a = 1:numel(aliases)
            if isfield(r.pq_summary, aliases{a})
                x = r.pq_summary.(aliases{a}); v = mean(double(x(:)), 'omitnan'); return;
            end
        end
    end
catch
end
end

function aliases = metric_aliases(key)
switch lower(key)
    case 'max_vuf_pct', aliases = {'peak_vuf_pct','VUF_max_pct'};
    case 'mean_vuf_pct', aliases = {'avg_vuf_pct','VUF_mean_pct'};
    case 'min_voltage_pu', aliases = {'v_min_pu','V_min_pu'};
    case 'max_loading_pct', aliases = {'peak_loading_pct','max_tl_pct','TL_max_pct'};
    otherwise, aliases = {};
end
end

function bills = result_bills_pdf(r, method)
bills = NaN;
try
    if isfield(r, 'costs') && isfield(r.costs, 'bill_total') && isfield(r.costs.bill_total, method)
        bills = double(r.costs.bill_total.(method)(:));
    end
catch
end
end

function n = result_num_periods_pdf(r)
n = 12;
try
    if isfield(r, 'costs') && isfield(r.costs, 'month_labels')
        n = max(1, numel(r.costs.month_labels));
    elseif isfield(r, 'costs') && isfield(r.costs, 'energy_monthly_kwh')
        n = max(1, size(r.costs.energy_monthly_kwh, 2));
    end
catch
    n = 12;
end
end

function v = result_comfort_pdf(r, mode)
v = NaN;
try
    if ~isfield(r, 'comfort_summary'), return; end
    c = r.comfort_summary;
    switch lower(mode)
        case 'mean'
            if isfield(c, 'mean_ci'), v = mean(double(c.mean_ci(:)), 'omitnan');
            elseif isfield(c, 'mean'), v = mean(double(c.mean(:)), 'omitnan'); end
        case 'min'
            if isfield(c, 'min_ci'), v = mean(double(c.min_ci(:)), 'omitnan');
            elseif isfield(c, 'min'), v = mean(double(c.min(:)), 'omitnan'); end
    end
catch
end
end

function r = first_with_field_pdf(items, fieldName)
r = [];
for k = 1:numel(items)
    if isstruct(items{k}) && isfield(items{k}, fieldName)
        r = items{k}; return;
    end
end
end

function root = get_report_root(cfg, opts)
if isstruct(opts) && isfield(opts, 'output_dir') && ~isempty(opts.output_dir)
    root = opts.output_dir;
elseif isstruct(cfg) && isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    root = cfg.output_dir;
else
    root = fullfile(get_root_dir(), 'results');
end
end

function val = get_nested_value(s, path, default)
val = default;
try
    v = s;
    for k = 1:numel(path)
        if isstruct(v) && isfield(v, path{k})
            v = v.(path{k});
        else
            return;
        end
    end
    val = v;
catch
    val = default;
end
end

function s = get_nested_string(st, path, default)
v = get_nested_value(st, path, default);
s = value_to_short_string(v);
end

function n = get_nested_number(st, path, default)
v = get_nested_value(st, path, default);
if isnumeric(v) && isscalar(v), n = v; else, n = default; end
end

function s = value_to_short_string(v)
try
    if islogical(v), s = mat2str(v);
    elseif isnumeric(v), s = mat2str(v, 4);
    elseif ischar(v), s = v;
    elseif isstring(v), s = char(v);
    elseif iscell(v), s = strjoin(cellfun(@value_to_short_string, v(:)', 'UniformOutput', false), ', ');
    else, s = char(string(v)); end
catch
    s = '?';
end
if numel(s) > 70, s = [s(1:67), '...']; end
end

function s = fmt_num(v, fmt)
if isempty(v) || ~isfinite(v), s = '--'; else, s = sprintf(fmt, v); end
end

function name = sanitize_filename(name)
name = regexprep(char(string(name)), '[^a-zA-Z0-9_\-]', '_');
if isempty(name), name = 'ev_dsm_report'; end
end

function v = get_opt_pdf(opts, name, default)
if isstruct(opts) && isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end

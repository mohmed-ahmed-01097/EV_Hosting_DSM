function out = app_export_helper(exportType, data, cfg, opts)
% APP_EXPORT_HELPER Export figures, CSV tables, and LaTeX report assets.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   exportType - Export mode:
%                'figure_png', 'figure_eps', 'table_csv', 'latex_report', 'pdf_report',
%                'figures_selected', or 'tables_selected'
%   data       - Figure handle, table, scenario results, or report struct
%   cfg        - Project configuration struct
%   opts       - Options struct. Common fields:
%                .name, .output_dir, .dpi, .formats, .selected_figures,
%                .selected_tables, .author, .report_date
%
% Outputs:
%   out        - Exported file path, path list, or metadata struct.
%
% Example:
%   app_export_helper('figures_selected', all_results, cfg, ...
%       struct('selected_figures', {{'vuf_comparison','hosting_capacity'}}, ...
%              'formats', {{'png','eps'}}));

if nargin < 4 || isempty(opts), opts = struct(); end
if nargin < 3 || isempty(cfg),  cfg = struct();  end
if nargin < 2, data = []; end
if nargin < 1 || isempty(exportType), exportType = 'table_csv'; end

ensure_output_dirs(cfg);
name = get_opt(opts, 'name', ['export_', datestr(now, 'yyyymmdd_HHMMSS')]);
dpi  = get_opt(opts, 'dpi', 300);

switch lower(char(string(exportType)))
    case 'figure_png'
        outDir = get_fig_dir(cfg, opts, 'png');
        out = fullfile(outDir, [name, '.png']);
        export_figure(data, out, dpi, 'png');

    case 'figure_eps'
        outDir = get_fig_dir(cfg, opts, 'eps');
        out = fullfile(outDir, [name, '.eps']);
        export_figure(data, out, dpi, 'eps');

    case 'table_csv'
        outDir = get_table_dir(cfg, opts);
        out = fullfile(outDir, [name, '.csv']);
        export_table(data, out);

    case 'latex_report'
        outDir = get_results_dir(cfg, opts);
        out = fullfile(outDir, [name, '.tex']);
        export_latex_report(data, out, opts);

    case 'pdf_report'
        out = app_pdf_report(data, cfg, opts);

    case 'figures_selected'
        out = export_selected_figures(data, cfg, opts);

    case 'tables_selected'
        out = export_selected_tables(data, cfg, opts);

    otherwise
        error('app_export_helper:unknownType', 'Unknown export type: %s', exportType);
end
end

function ensure_output_dirs(cfg)
% ENSURE_OUTPUT_DIRS Create result export directories when possible.
try
    dirs = {get_results_dir(cfg, struct()), get_fig_dir(cfg, struct(), ''), ...
        get_fig_dir(cfg, struct(), 'png'), get_fig_dir(cfg, struct(), 'eps'), ...
        get_table_dir(cfg, struct())};
    for k = 1:numel(dirs)
        if exist(dirs{k}, 'dir') ~= 7, mkdir(dirs{k}); end
    end
catch
end
end

function out = export_selected_figures(results, cfg, opts)
% EXPORT_SELECTED_FIGURES Create selected thesis figures from lean results.
selected = get_opt(opts, 'selected_figures', {'vuf_comparison','hosting_capacity'});
formats  = get_opt(opts, 'formats', {'png'});
dpi      = get_opt(opts, 'dpi', 300);
if ischar(selected) || isstring(selected), selected = cellstr(selected); end
if ischar(formats)  || isstring(formats),  formats  = cellstr(formats);  end
items = normalize_results(results);
paths = {};
for i = 1:numel(selected)
    figKey = lower(char(string(selected{i})));
    fig = figure('Visible', 'off', 'Color', 'w', 'Name', figKey, 'NumberTitle', 'off');
    ax = axes(fig);
    try
        draw_export_figure(ax, figKey, items, cfg);
        for f = 1:numel(formats)
            fmt = lower(char(string(formats{f})));
            if strcmp(fmt, 'svg')
                outDir = get_fig_dir(cfg, opts, 'svg'); ext = '.svg';
            elseif strcmp(fmt, 'eps')
                outDir = get_fig_dir(cfg, opts, 'eps'); ext = '.eps';
            else
                outDir = get_fig_dir(cfg, opts, 'png'); ext = '.png'; fmt = 'png';
            end
            if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
            outFile = fullfile(outDir, [figKey, ext]);
            export_figure(fig, outFile, dpi, fmt);
            paths{end+1,1} = outFile; %#ok<AGROW>
        end
    catch ME
        warning('app_export_helper:figureFailed', '%s failed: %s', figKey, ME.message);
    end
    if isvalid(fig), close(fig); end
end
out = struct('figure_paths', {paths}, 'count', numel(paths));
end

function draw_export_figure(ax, figKey, items, cfg)
% DRAW_EXPORT_FIGURE Render one lean-results-compatible figure.
labels = result_labels(items);
switch figKey
    case {'vuf_comparison','scenario_comparison'}
        vals = cellfun(@(r) result_metric(r, 'mean_vuf_pct'), items);
        bar(ax, categorical(labels), vals); ylabel(ax, 'Mean VUF [%]');
        title(ax, 'VUF Comparison'); grid(ax, 'on');
        add_limit_line(ax, cfg, 'vuf');
    case 'hosting_capacity'
        vals = cellfun(@(r) result_metric(r, 'hosting_capacity_pct'), items);
        bar(ax, categorical(labels), vals); ylabel(ax, 'EV Hosting Capacity [%]');
        title(ax, 'Hosting Capacity by Scenario'); grid(ax, 'on');
    case 'load_profiles'
        r = first_result_with_field(items, 'L_feeder_w');
        if isempty(r)
            text(ax, 0.1, 0.5, 'No retained L_feeder_w data available.'); axis(ax, 'off'); return;
        end
        L = double(r.L_feeder_w);
        n = min(size(L,1), 96);
        plot(ax, (1:n), L(1:n,:) / 1000, 'LineWidth', 1.2);
        xlabel(ax, 'Step'); ylabel(ax, 'Power [kW]'); title(ax, '24-hour Three-Phase Feeder Load');
        legend(ax, {'Phase A','Phase B','Phase C'}, 'Location', 'best'); grid(ax, 'on');
    case {'monthly_bill_box','cost_box'}
        methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
        vals = nan(numel(items), numel(methods));
        for i = 1:numel(items)
            for m = 1:numel(methods)
                bills = result_bills(items{i}, methods{m});
                vals(i,m) = mean(bills, 'omitnan');
            end
        end
        bar(ax, vals); xlabel(ax, 'Scenario'); ylabel(ax, 'Mean Bill [EGP]');
        title(ax, 'Monthly Bill Comparison'); grid(ax, 'on'); legend(ax, methods, 'Location', 'bestoutside');
        ax.XTick = 1:numel(labels); ax.XTickLabel = labels;
    case 'tariff_slab_migration'
        slabCounts = zeros(numel(items), 6);
        for i = 1:numel(items)
            bills = result_bills(items{i}, 'Block');
            if isempty(bills), continue; end
            % Approximate slab index from bill level when monthly kWh is not retained.
            slabCounts(i,:) = approximate_slab_counts(bills);
        end
        bar(ax, slabCounts, 'stacked'); xlabel(ax, 'Scenario'); ylabel(ax, 'Households');
        title(ax, 'Approximate Block-Tariff Slab Migration'); grid(ax, 'on');
        legend(ax, {'S1','S2','S3','S4','S5','S6'}, 'Location', 'bestoutside');
        ax.XTick = 1:numel(labels); ax.XTickLabel = labels;
    case {'bus_voltage_map','pq_timeseries'}
        vals = cellfun(@(r) result_metric(r, 'min_voltage_pu'), items);
        bar(ax, categorical(labels), vals); ylabel(ax, 'Minimum Voltage [pu]');
        title(ax, 'Scenario Minimum Voltage'); grid(ax, 'on');
        try, yline(ax, cfg.pq_limits.voltage_min_pu, '--', 'Voltage limit'); catch, end
    otherwise
        vals = cellfun(@(r) result_metric(r, 'mean_vuf_pct'), items);
        bar(ax, categorical(labels), vals); ylabel(ax, figKey); title(ax, strrep(figKey, '_', ' ')); grid(ax, 'on');
end
end

function add_limit_line(ax, cfg, kind)
try
    switch kind
        case 'vuf'
            yline(ax, cfg.pq_limits.vuf_max_pct, '--', '2% limit');
    end
catch
end
end

function out = export_selected_tables(results, cfg, opts)
% EXPORT_SELECTED_TABLES Export thesis CSV tables using existing exporter.
selected = get_opt(opts, 'selected_tables', {'scenario_summary','cost_summary','comfort_summary','violations'});
if ischar(selected) || isstring(selected), selected = cellstr(selected); end
if isempty(results)
    results = {};
end
info = export_results_tables(results, cfg);
allPaths = struct_to_paths(info);
keep = {};
for i = 1:numel(selected)
    key = lower(char(string(selected{i})));
    if isfield(info, key)
        keep{end+1,1} = info.(key); %#ok<AGROW>
    elseif any(strcmpi(key, {'all','selected'}))
        keep = allPaths;
        break;
    end
end
if isempty(keep), keep = allPaths; end
out = struct('table_paths', {keep}, 'count', numel(keep), 'export_info', info);
end

function paths = struct_to_paths(info)
paths = {};
if ~isstruct(info), return; end
names = fieldnames(info);
for k = 1:numel(names)
    v = info.(names{k});
    if ischar(v) || isstring(v)
        s = char(string(v));
        if endsWith(s, '.csv', 'IgnoreCase', true)
            paths{end+1,1} = s; %#ok<AGROW>
        end
    end
end
end

function export_figure(fig, outFile, dpi, fmt)
% EXPORT_FIGURE Robust figure export helper.
if isempty(fig) || ~ishandle(fig)
    fig = gcf;
end
try
    if strcmpi(fmt, 'eps')
        print(fig, outFile, '-depsc', ['-r', num2str(dpi)]);
    elseif strcmpi(fmt, 'svg')
        print(fig, outFile, '-dsvg', ['-r', num2str(dpi)]);
    else
        exportgraphics(fig, outFile, 'Resolution', dpi);
    end
catch
    if strcmpi(fmt, 'eps')
        print(fig, outFile, '-depsc', ['-r', num2str(dpi)]);
    elseif strcmpi(fmt, 'svg')
        print(fig, outFile, '-dsvg', ['-r', num2str(dpi)]);
    else
        print(fig, outFile, '-dpng', ['-r', num2str(dpi)]);
    end
end
end

function export_table(data, outFile)
% EXPORT_TABLE Robust table/struct/matrix/text CSV export.
if istable(data)
    writetable(data, outFile);
elseif isstruct(data)
    try
        writetable(struct2table(data), outFile);
    catch
        fid = fopen(outFile, 'w'); cleaner = onCleanup(@() fclose(fid));
        fprintf(fid, '%s\n', evalc('disp(data)'));
    end
elseif isnumeric(data)
    writematrix(data, outFile);
else
    fid = fopen(outFile, 'w'); cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', char(string(data)));
end
end

function export_latex_report(data, outFile, opts)
% EXPORT_LATEX_REPORT Write a thesis-ready LaTeX include file.
fid = fopen(outFile, 'w');
if fid < 0, error('app_export_helper:openFailed', 'Could not open file: %s', outFile); end
cleaner = onCleanup(@() fclose(fid));
authorName = get_opt(opts, 'author', 'Mohammed Ahmed');
reportDate = get_opt(opts, 'report_date', datestr(now, 'yyyy-mm-dd'));
fprintf(fid, '%% EV Hosting DSM UI Export Report\n');
fprintf(fid, '%% Generated: %s\n\n', datestr(now));
fprintf(fid, '\\section*{EV Hosting DSM Results Export}\n');
fprintf(fid, '\\textbf{Author:} %s\\\\\n', latex_escape(authorName));
fprintf(fid, '\\textbf{Date:} %s\\\\\n\n', latex_escape(reportDate));
figs = get_report_paths(data, 'figure_paths');
tables = get_report_paths(data, 'table_paths');
if ~isempty(figs)
    fprintf(fid, '\\subsection*{Figures}\n');
    for i = 1:numel(figs)
        [~, base, ext] = fileparts(figs{i});
        if any(strcmpi(ext, {'.png','.eps','.pdf','.jpg','.jpeg'}))
            fprintf(fid, '\\begin{figure}[htbp]\n');
            fprintf(fid, '\\centering\n');
            fprintf(fid, '\\includegraphics[width=0.95\\linewidth]{%s}\n', latex_escape(figs{i}));
            fprintf(fid, '\\caption{%s}\n', latex_escape(strrep(base, '_', ' ')));
            fprintf(fid, '\\end{figure}\n\n');
        end
    end
end
if ~isempty(tables)
    fprintf(fid, '\\subsection*{Tables}\n');
    for i = 1:numel(tables)
        [~, base, ~] = fileparts(tables{i});
        fprintf(fid, '\\paragraph{%s} CSV file: \\texttt{%s}\\\n\n', ...
            latex_escape(strrep(base, '_', ' ')), latex_escape(tables{i}));
    end
end
if isempty(figs) && isempty(tables)
    fprintf(fid, 'No selected export paths were provided.\\\n\n');
end
end

function paths = get_report_paths(data, fieldName)
paths = {};
try
    if isstruct(data) && isfield(data, fieldName)
        paths = data.(fieldName);
    elseif isstruct(data) && isfield(data, 'exports') && isfield(data.exports, fieldName)
        paths = data.exports.(fieldName);
    end
catch
end
if ischar(paths) || isstring(paths), paths = cellstr(paths); end
end

function outDir = get_results_dir(cfg, opts)
if isfield(opts, 'output_dir') && ~isempty(opts.output_dir)
    outDir = opts.output_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    outDir = cfg.output_dir;
else
    outDir = fullfile(get_root_dir(), 'results');
end
end

function outDir = get_fig_dir(cfg, opts, subfolder)
base = '';
if isfield(opts, 'figures_dir') && ~isempty(opts.figures_dir)
    base = opts.figures_dir;
elseif isfield(opts, 'output_dir') && ~isempty(opts.output_dir)
    base = fullfile(opts.output_dir, 'figures');
elseif isfield(cfg, 'figs_dir') && ~isempty(cfg.figs_dir)
    base = cfg.figs_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    base = fullfile(cfg.output_dir, 'figures');
else
    base = fullfile(get_root_dir(), 'results', 'figures');
end
if nargin >= 3 && ~isempty(subfolder)
    outDir = fullfile(base, subfolder);
else
    outDir = base;
end
end

function outDir = get_table_dir(cfg, opts)
if isfield(opts, 'tables_dir') && ~isempty(opts.tables_dir)
    outDir = opts.tables_dir;
elseif isfield(opts, 'output_dir') && ~isempty(opts.output_dir)
    outDir = fullfile(opts.output_dir, 'tables');
elseif isfield(cfg, 'tables_dir') && ~isempty(cfg.tables_dir)
    outDir = cfg.tables_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    outDir = fullfile(cfg.output_dir, 'tables');
else
    outDir = fullfile(get_root_dir(), 'results', 'tables');
end
end

function items = normalize_results(results)
if isempty(results)
    items = {};
elseif iscell(results)
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
items = items(~cellfun(@isempty, items));
end

function labels = result_labels(items)
labels = cell(1, numel(items));
for k = 1:numel(items)
    r = items{k};
    sid = NaN;
    try, sid = r.scenario_id; catch, end
    if isequal(sid, -1)
        labels{k} = 'B0';
    elseif isfinite(sid)
        labels{k} = sprintf('S%g', sid);
    else
        labels{k} = sprintf('R%d', k);
    end
end
end

function r = first_result_with_field(items, fieldName)
r = [];
for k = 1:numel(items)
    if isstruct(items{k}) && isfield(items{k}, fieldName)
        r = items{k}; return;
    end
end
end

function v = result_metric(r, key)
v = NaN;
try
    if strcmpi(key, 'hosting_capacity_pct') && isfield(r, 'hosting_capacity_pct')
        v = mean(double(r.hosting_capacity_pct(:)), 'omitnan'); return;
    end
    if strcmpi(key, 'mean_ci') && isfield(r, 'comfort_summary')
        if isfield(r.comfort_summary, 'mean_ci')
            v = mean(double(r.comfort_summary.mean_ci(:)), 'omitnan'); return;
        elseif isfield(r.comfort_summary, 'mean')
            v = mean(double(r.comfort_summary.mean(:)), 'omitnan'); return;
        end
    end
    if isfield(r, 'pq_summary') && isfield(r.pq_summary, key)
        x = r.pq_summary.(key); v = mean(double(x(:)), 'omitnan'); return;
    end
catch
end
end

function bills = result_bills(r, method)
bills = NaN;
try
    if isfield(r, 'costs') && isfield(r.costs, 'bill_total') && isfield(r.costs.bill_total, method)
        bills = double(r.costs.bill_total.(method)(:));
    end
catch
end
end

function counts = approximate_slab_counts(bills)
counts = zeros(1,6);
if isempty(bills), return; end
edges = [0 15 45 120 300 800 Inf];
for i = 1:numel(bills)
    idx = find(bills(i) >= edges(1:end-1) & bills(i) < edges(2:end), 1, 'first');
    if isempty(idx), idx = 6; end
    counts(idx) = counts(idx) + 1;
end
end

function s = latex_escape(s)
s = char(string(s));
repl = {'\','\textbackslash{}'; '_','\_'; '%','\%'; '&','\&'; '#','\#'; '$','\$'; '{','\{'; '}','\}'};
for k = 1:size(repl,1)
    s = strrep(s, repl{k,1}, repl{k,2});
end
end

function v = get_opt(opts, name, default)
if isstruct(opts) && isfield(opts, name)
    v = opts.(name);
else
    v = default;
end
end

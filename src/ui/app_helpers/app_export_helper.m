function out = app_export_helper(exportType, data, cfg, opts)
% APP_EXPORT_HELPER Export figures, tables, and LaTeX snippets from the UI.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   exportType - 'figure_png', 'figure_eps', 'table_csv', or 'latex_report'
%   data       - figure handle, table, struct, or cell data
%   cfg        - configuration struct
%   opts       - struct with optional fields: name, output_dir, dpi
%
% Outputs:
%   out        - exported file path or struct with paths
%
% Example:
%   app_export_helper('figure_png', gcf, cfg, struct('name','vuf_plot'));

if nargin < 4 || isempty(opts)
    opts = struct();
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end
if nargin < 2
    data = [];
end
if nargin < 1 || isempty(exportType)
    exportType = 'table_csv';
end

outDir = get_output_dir(cfg, opts);
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

name = get_opt(opts, 'name', ['export_', datestr(now, 'yyyymmdd_HHMMSS')]);
dpi  = get_opt(opts, 'dpi', 300);

switch lower(char(string(exportType)))
    case 'figure_png'
        out = fullfile(outDir, [name, '.png']);
        export_figure(data, out, dpi, 'png');
    case 'figure_eps'
        out = fullfile(outDir, [name, '.eps']);
        export_figure(data, out, dpi, 'eps');
    case 'table_csv'
        out = fullfile(outDir, [name, '.csv']);
        export_table(data, out);
    case 'latex_report'
        out = fullfile(outDir, [name, '.tex']);
        export_latex_report(data, out);
    otherwise
        error('app_export_helper:unknownType', 'Unknown export type: %s', exportType);
end
end

function outDir = get_output_dir(cfg, opts)
if isfield(opts, 'output_dir') && ~isempty(opts.output_dir)
    outDir = opts.output_dir;
elseif isfield(cfg, 'figs_dir') && ~isempty(cfg.figs_dir)
    outDir = cfg.figs_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    outDir = fullfile(cfg.output_dir, 'figures');
else
    outDir = fullfile(get_root_dir(), 'results', 'figures');
end
end

function export_figure(fig, outFile, dpi, fmt)
if isempty(fig) || ~ishandle(fig)
    fig = gcf;
end
try
    exportgraphics(fig, outFile, 'Resolution', dpi);
catch
    if strcmpi(fmt, 'eps')
        print(fig, outFile, '-depsc', ['-r', num2str(dpi)]);
    else
        print(fig, outFile, '-dpng', ['-r', num2str(dpi)]);
    end
end
end

function export_table(data, outFile)
if istable(data)
    writetable(data, outFile);
elseif isstruct(data)
    writetable(struct2table(data), outFile);
elseif isnumeric(data)
    writematrix(data, outFile);
else
    fid = fopen(outFile, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', char(string(data)));
end
end

function export_latex_report(data, outFile)
fid = fopen(outFile, 'w');
if fid < 0
    error('app_export_helper:openFailed', 'Could not open file: %s', outFile);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%% EV Hosting DSM UI Export Report\n');
fprintf(fid, '%% Generated: %s\n\n', datestr(now));
fprintf(fid, '\\section*{EV Hosting DSM Results}\n');
if istable(data)
    fprintf(fid, 'Exported table rows: %d.\\n\n', height(data));
elseif iscell(data)
    for i = 1:numel(data)
        fprintf(fid, 'Item %d: %s\\n\n', i, char(string(data{i})));
    end
else
    fprintf(fid, '%s\\n\n', char(string(evalc('disp(data)'))));
end
end

function v = get_opt(opts, name, default)
if isstruct(opts) && isfield(opts, name)
    v = opts.(name);
else
    v = default;
end
end

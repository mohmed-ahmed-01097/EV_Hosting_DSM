function files = viz_export_figure(fig, cfg, base_name)
% VIZ_EXPORT_FIGURE Export a MATLAB figure as PNG, EPS, and FIG.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   fig       (matlab.ui.Figure): Figure handle to export.
%   cfg       (struct): Project configuration with output folders.
%   base_name (char/string): Base file name without extension.
%
% Outputs:
%   files (struct): Exported file paths:
%       .png - 300 DPI PNG path
%       .eps - EPS path for LaTeX/vector workflows
%       .fig - MATLAB figure path
%
% Example:
%   files = viz_export_figure(gcf, cfg, 'scenario_comparison');

% --- Section 1: Validate inputs ---
if nargin < 1 || isempty(fig) || ~ishandle(fig)
    fig = gcf;
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end
if nargin < 3 || isempty(base_name)
    base_name = 'figure_export';
end
if isstring(base_name)
    base_name = char(base_name);
end
base_name = regexprep(base_name, '[^a-zA-Z0-9_\-]', '_');

dirs = viz_prepare_output_dirs(cfg);
files = struct();
files.png = fullfile(dirs.png, [base_name '.png']);
files.eps = fullfile(dirs.eps, [base_name '.eps']);
files.fig = fullfile(dirs.figures, [base_name '.fig']);

% --- Section 2: Apply publication defaults ---
set(fig, 'Color', 'w');
try
    set(findall(fig, '-property', 'FontSize'), 'FontSize', 11);
    set(findall(fig, '-property', 'LineWidth'), 'LineWidth', 1.1);
catch
    % Cosmetic settings should not block validation.
end

% --- Section 3: Export files ---
try
    exportgraphics(fig, files.png, 'Resolution', 300);
catch
    print(fig, files.png, '-dpng', '-r300');
end

try
    exportgraphics(fig, files.eps, 'ContentType', 'vector');
catch
    print(fig, files.eps, '-depsc', '-painters', '-r300');
end

try
    savefig(fig, files.fig);
catch
    warning('viz_export_figure:savefig', 'Could not save MATLAB FIG file: %s', files.fig);
end

fprintf('[viz_export_figure] Saved %s and %s\n', files.png, files.eps);
end

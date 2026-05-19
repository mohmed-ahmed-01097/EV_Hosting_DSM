function fig = app_popout_plot(plotType, data, cfg)
% APP_POPOUT_PLOT Create a standalone figure for a UI preview plot.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   plotType - char/string: 'load_profile', 'comparison', 'feeder_topo', or custom
%   data     - plot data struct/cell
%   cfg      - configuration struct, optional
%
% Outputs:
%   fig      - standalone figure handle
%
% Example:
%   app_popout_plot('comparison', all_results, cfg);

if nargin < 1 || isempty(plotType)
    plotType = 'plot';
end
if nargin < 2
    data = [];
end
if nargin < 3
    cfg = struct();
end

fig = figure('Name', char(string(plotType)), ...
    'NumberTitle', 'off', ...
    'Color', [1, 1, 1], ...
    'Position', [100, 100, 950, 620]);
ax = axes(fig);

switch lower(char(string(plotType)))
    case 'load_profile'
        app_load_profile_plot(data, cfg, ax);
    case 'comparison'
        app_scenario_comparison(data, 'mean_vuf_pct', ax);
    case 'feeder_topo'
        if isstruct(data) && isfield(data, 'net')
            assignment = struct();
            if isfield(data, 'assignment')
                assignment = data.assignment;
            end
            app_feeder_plot(data.net, assignment, ax);
        else
            title(ax, 'Feeder topology data unavailable');
        end
    otherwise
        plot(ax, 0, 0, 'o');
        grid(ax, 'on');
        title(ax, char(string(plotType)), 'Interpreter', 'none');
end

try
    fig.ToolBar = 'figure';
catch
end
end

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
    case 'pricing_curves'
        plot_pricing_curves(data, cfg, ax);
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

function plot_pricing_curves(data, cfg, ax)
% PLOT_PRICING_CURVES Lightweight tariff plot for pop-out windows.
if isstruct(data) && isfield(data, 'cfg')
    cfg = data.cfg;
end
if ~isstruct(cfg) || ~isfield(cfg, 'simulation')
    title(ax, 'Pricing configuration unavailable');
    return;
end
methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
tvec = (0:(24*60/cfg.simulation.dt_min)-1)' * cfg.simulation.dt_min;
hours = tvec / 60;
hold(ax, 'on');
for k = 1:numel(methods)
    p = select_pricing(methods{k}, cfg, tvec, 250, []);
    if isstruct(p) && isfield(p, 'price_series')
        y = p.price_series;
    else
        y = p(:);
    end
    plot(ax, hours, y, 'LineWidth', 1.3, 'DisplayName', methods{k});
end
grid(ax, 'on');
xlabel(ax, 'Hour');
ylabel(ax, 'EGP/kWh');
title(ax, '24-hour Tariff Curves');
legend(ax, 'Location', 'best');
xlim(ax, [0 24]);
hold(ax, 'off');
end

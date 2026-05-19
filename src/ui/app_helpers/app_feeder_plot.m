function app_feeder_plot(net, assignment, ax)
% APP_FEEDER_PLOT Render a compact radial feeder topology on UIAxes or axes.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   net        - feeder network struct from build_feeder_network
%   assignment - assignment struct from assign_households, optional
%   ax         - target axes or UIAxes. If omitted, a new figure is created.
%
% Outputs:
%   None
%
% Example:
%   net = build_feeder_network(cfg);
%   app_feeder_plot(net, assignment);

if nargin < 2
    assignment = struct();
end
if nargin < 3 || isempty(ax)
    fig = figure('Name', 'Feeder Topology', 'Color', 'w');
    ax = axes(fig);
end

cla(ax);
hold(ax, 'on');
axis(ax, 'equal');
grid(ax, 'on');
box(ax, 'on');

if ~isstruct(net) || ~isfield(net, 'n_buses')
    title(ax, 'Feeder topology unavailable');
    hold(ax, 'off');
    return;
end

coords = compute_bus_coordinates(net);
zoneColors = lines(max(5, get_field(net, 'n_transformers', 5)));

% Draw branches.
for br = 1:get_field(net, 'n_branches', 0)
    fromIdx = net.branch_from(br);
    toIdx = net.branch_to(br);
    if fromIdx == 0
        zone = safe_zone(net, br);
        p1 = [-0.8, -zone];
    else
        p1 = coords(fromIdx, :);
    end
    p2 = coords(toIdx, :);
    zone = safe_zone(net, br);
    plot(ax, [p1(1), p2(1)], [p1(2), p2(2)], '-', ...
        'Color', zoneColors(zone, :), 'LineWidth', 2.0);
end

% Draw buses.
for b = 1:net.n_buses
    zone = safe_bus_zone(net, b);
    hhCount = count_households_on_bus(assignment, b);
    markerSize = 7 + min(hhCount, 12);
    plot(ax, coords(b,1), coords(b,2), 'o', ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', zoneColors(zone, :), ...
        'MarkerEdgeColor', [0.05, 0.05, 0.05]);
    text(ax, coords(b,1)+0.04, coords(b,2)+0.04, bus_label(net, b), ...
        'FontSize', 8, 'Interpreter', 'none');
end

% Draw transformer markers.
for z = 1:get_field(net, 'n_transformers', 5)
    plot(ax, -0.8, -z, 's', 'MarkerSize', 12, ...
        'MarkerFaceColor', zoneColors(z,:), 'MarkerEdgeColor', 'k');
    text(ax, -1.25, -z, sprintf('T%d', z), 'FontWeight', 'bold');
end

xlabel(ax, 'Feeder distance (schematic)');
ylabel(ax, 'Transformer zone');
title(ax, 'LV Radial Feeder Topology');
hold(ax, 'off');
end

function coords = compute_bus_coordinates(net)
coords = zeros(net.n_buses, 2);
zoneCount = zeros(1, max(5, get_field(net, 'n_transformers', 5)));
for b = 1:net.n_buses
    zone = safe_bus_zone(net, b);
    zoneCount(zone) = zoneCount(zone) + 1;
    coords(b,:) = [zoneCount(zone) * 1.1, -zone];
end
end

function zone = safe_zone(net, br)
zone = 1;
try
    zone = net.branch_transformer_zone(br);
catch
end
zone = max(1, min(zone, max(1, get_field(net, 'n_transformers', 5))));
end

function zone = safe_bus_zone(net, b)
zone = 1;
try
    zone = net.transformer_id(b);
catch
end
zone = max(1, min(zone, max(1, get_field(net, 'n_transformers', 5))));
end

function n = count_households_on_bus(assignment, b)
n = 0;
try
    n = sum(assignment.bus_id(:) == b);
catch
end
end

function s = bus_label(net, b)
try
    s = net.bus_names{b};
catch
    s = sprintf('Bus %d', b);
end
end

function v = get_field(s, name, default)
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end

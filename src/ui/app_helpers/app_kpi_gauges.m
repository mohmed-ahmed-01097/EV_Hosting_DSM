function gauges = app_kpi_gauges(parent, kpi, cfg)
% APP_KPI_GAUGES Create or summarize six KPI gauge widgets.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   parent - UI container. If empty, no UI is created and metadata is returned.
%   kpi    - struct with KPI values. Supported fields:
%            vuf_pct, v_min_pu, tl_pct, ncr_pct, thdv_pct, losses_kw
%   cfg    - configuration struct with pq_limits, optional
%
% Outputs:
%   gauges - struct with created gauge handles and KPI metadata
%
% Example:
%   gauges = app_kpi_gauges([], struct('vuf_pct',1.2), cfg);

if nargin < 1
    parent = [];
end
if nargin < 2 || isempty(kpi)
    kpi = struct();
end
if nargin < 3
    cfg = struct();
end

theme = app_theme();

values = [ ...
    get_field(kpi, 'vuf_pct', NaN), ...
    get_field(kpi, 'v_min_pu', NaN), ...
    get_field(kpi, 'tl_pct', NaN), ...
    get_field(kpi, 'ncr_pct', NaN), ...
    get_field(kpi, 'thdv_pct', NaN), ...
    get_field(kpi, 'losses_kw', NaN) ...
];

limits = default_limits(cfg);
labels = theme.kpi.names;
units  = theme.kpi.units;

gauges.values = values;
gauges.limits = limits;
gauges.labels = labels;
gauges.units  = units;
gauges.handles = gobjects(1, numel(labels));

if isempty(parent) || ~isvalid_parent(parent)
    return;
end

for i = 1:numel(labels)
    x = 15 + (i-1) * 125;
    y = 15;
    try
        g = uigauge(parent, 'semicircular', 'Position', [x, y, 110, 85]);
        if strcmp(labels{i}, 'V_min')
            g.Limits = [0.80, 1.05];
            g.Value = finite_or(values(i), 1.0);
        else
            g.Limits = [0, max(limits(i) * 1.5, 1)];
            g.Value = finite_or(values(i), 0);
        end
        g.Label = sprintf('%s\n%.3g %s', labels{i}, finite_or(values(i), 0), units{i});
        g.ScaleColors = {theme.colors.success, theme.colors.warning, theme.colors.danger};
        if strcmp(labels{i}, 'V_min')
            g.ScaleColorLimits = [0.80, limits(i); limits(i), 0.95; 0.95, 1.05];
        else
            g.ScaleColorLimits = [0, limits(i)*0.8; limits(i)*0.8, limits(i); limits(i), limits(i)*1.5];
        end
        gauges.handles(i) = g;
    catch
        % Allow helper to remain testable without a live App Designer figure.
    end
end
end

function limits = default_limits(cfg)
limits = [2.0, 0.90, 100.0, 30.0, 8.0, 50.0];
try
    limits(1) = cfg.pq_limits.vuf_max_pct;
    limits(2) = cfg.pq_limits.voltage_min_pu;
    limits(3) = cfg.pq_limits.transformer_loading_max_pct;
    limits(4) = cfg.pq_limits.ncr_max_pct;
    limits(5) = cfg.pq_limits.thdv_max_pct;
catch
end
end

function v = get_field(s, name, default)
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end

function tf = isvalid_parent(parent)
tf = isobject(parent);
try
    tf = tf && isvalid(parent);
catch
end
end

function y = finite_or(x, fallback)
if isempty(x) || ~isnumeric(x) || ~isfinite(x)
    y = fallback;
else
    y = x;
end
end

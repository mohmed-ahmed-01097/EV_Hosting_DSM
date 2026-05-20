function app_load_profile_plot(profile, cfg, ax)
% APP_LOAD_PROFILE_PLOT Plot a 24-hour stacked household load profile.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   profile - struct with p_fixed_w, p_controllable_w, p_hvac_w, optional p_ev_w
%             or numeric vector/matrix in watts
%   cfg     - configuration struct, optional
%   ax      - target axes or UIAxes. If omitted, a new figure is created.
%
% Outputs:
%   None
%
% Example:
%   app_load_profile_plot(hh.daily_profile, cfg, app.LoadAxes);

if nargin < 2 || isempty(cfg)
    cfg = struct();
end
if nargin < 3 || isempty(ax)
    fig = figure('Name', 'Load Profile', 'Color', 'w');
    ax = axes(fig);
end

[pMat, labels, dtMin] = normalize_profile(profile, cfg);
steps = size(pMat, 1);
hours = (0:steps-1)' * dtMin / 60;

cla(ax);
style_app_axes(ax);
if isempty(pMat)
    title(ax, 'Load profile unavailable');
    return;
end

area(ax, hours, pMat / 1000, 'LineStyle', 'none', 'FaceAlpha', 0.86);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Hour of day');
ylabel(ax, 'Power [kW]');
title(ax, '24-hour Household Load Profile');
xlim(ax, [0, max(24, max(hours))]);
legend(ax, labels, 'Location', 'northoutside', 'Orientation', 'horizontal');
style_app_axes(ax);
end

function [pMat, labels, dtMin] = normalize_profile(profile, cfg)
dtMin = 15;
try
    dtMin = cfg.simulation.dt_min;
catch
end

if isnumeric(profile)
    pMat = profile;
    if isvector(pMat)
        pMat = pMat(:);
    end
    labels = compose('Series %d', 1:size(pMat,2));
    labels = cellstr(labels);
    return;
end

if ~isstruct(profile)
    pMat = [];
    labels = {};
    return;
end

fields = {'p_fixed_w', 'p_controllable_w', 'p_hvac_w', 'p_ev_w'};
labels = {'Fixed', 'Controllable', 'HVAC', 'EV'};
cols = {};
keepLabels = {};
for i = 1:numel(fields)
    if isfield(profile, fields{i})
        v = profile.(fields{i});
        if isnumeric(v) && ~isempty(v)
            cols{end+1} = max(0, v(:)); %#ok<AGROW>
            keepLabels{end+1} = labels{i}; %#ok<AGROW>
        end
    end
end

if isempty(cols) && isfield(profile, 'p_total_w')
    cols = {max(0, profile.p_total_w(:))};
    keepLabels = {'Total'};
end

if isempty(cols)
    pMat = [];
    labels = {};
else
    minLen = min(cellfun(@numel, cols));
    pMat = zeros(minLen, numel(cols));
    for i = 1:numel(cols)
        pMat(:,i) = cols{i}(1:minLen);
    end
    labels = keepLabels;
end
end

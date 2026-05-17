function out = plot_scenario_comparison(all_results, cfg)
% PLOT_SCENARIO_COMPARISON Create publication-quality scenario comparison figure.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results: Cell array or struct array returned by Phase 5 scenario runners.
%   cfg (struct): Project configuration. Uses cfg.pq_limits and output folders.
%
% Outputs:
%   out (struct): Exported figure file paths and extracted plotting metrics.
%
% Example:
%   load(fullfile(cfg.output_dir, 'scenario_results.mat'), 'all_results');
%   out = plot_scenario_comparison(all_results, cfg);
%
% Figure panels:
%   1. Mean/peak VUF comparison with 2% limit line.
%   2. Hosting capacity screening result.
%   3. 24-hour average three-phase feeder profile.
%   4. Tariff bill comparison for Flat and Block tariffs.
%   5. Comfort index versus PQ improvement.
%   6. Transformer loading heatmap from available PQ time series.

% --- Section 1: Prepare data ---
if nargin < 2, cfg = struct(); end
results = viz_normalize_results(all_results);
M = viz_result_metrics(results);
N = numel(results);

fig = figure('Name', 'Phase 6 - Scenario Comparison', 'Visible', 'off', ...
    'Units', 'pixels', 'Position', [100 100 1500 1050], 'Color', 'w');
tl = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'EV Hosting Capacity DSM - Scenario Comparison', 'FontWeight', 'bold');

x = 1:N;
labels = M.labels;

% --- Section 2: VUF mean and peak ---
nexttile(tl);
b = bar(x, [M.mean_vuf_pct(:), M.max_vuf_pct(:)], 'grouped'); %#ok<NASGU>
hold on;
vufLimit = get_limit(cfg, 'vuf_max_pct', 2.0);
yline(vufLimit, '--', sprintf('Limit %.1f%%', vufLimit), 'LabelHorizontalAlignment', 'left');
grid on;
ylabel('VUF [%]');
title('Voltage Unbalance Factor');
legend({'Mean VUF', 'Peak VUF'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 3: Hosting capacity ---
nexttile(tl);
bar(x, M.hosting_capacity_pct(:));
grid on;
ylabel('Hosting capacity [% EV]');
title('EV Hosting Capacity Screening');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 4: Average 24-hour load profile ---
nexttile(tl);
plot_average_load_profiles(results, cfg);
title('Average 24-hour Three-phase Feeder Load');

% --- Section 5: Tariff bill comparison ---
nexttile(tl);
bar(x, [M.flat_bill_mean(:), M.block_bill_mean(:)], 'grouped');
grid on;
ylabel('Mean bill [EGP]');
title('Tariff Cost Comparison');
legend({'Flat', 'Block'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 6: Comfort versus PQ improvement ---
nexttile(tl);
baselineVuf = first_finite(M.max_vuf_pct, 0);
pqImprovement = baselineVuf - M.max_vuf_pct;
scatter(pqImprovement, M.comfort_mean, 60, 'filled');
grid on;
xlabel('Peak VUF improvement versus first scenario [percentage points]');
ylabel('Mean comfort index');
title('Comfort vs PQ Improvement');
for i = 1:N
    if isfinite(pqImprovement(i)) && isfinite(M.comfort_mean(i))
        text(pqImprovement(i), M.comfort_mean(i), sprintf(' S%g', M.ids(i)), 'FontSize', 9);
    end
end
ylim([0 1.05]);

% --- Section 7: Transformer loading heatmap ---
nexttile(tl);
[heatData, heatLabel] = transformer_loading_heatmap_data(results);
if isempty(heatData)
    text(0.1, 0.5, 'Transformer loading time series not available', 'FontSize', 11);
    axis off;
else
    imagesc(heatData);
    colorbar;
    xlabel('Sampled time step');
    ylabel('Transformer zone');
    title(sprintf('Transformer Loading Heatmap - %s', heatLabel));
end

% --- Section 8: Export ---
files = viz_export_figure(fig, cfg, 'scenario_comparison');
out = struct('files', files, 'metrics', M);
close(fig);
end

function plot_average_load_profiles(results, cfg)
% PLOT_AVERAGE_LOAD_PROFILES Plot selected average phase profiles.
maxCurves = min(numel(results), 4);
stepsPerDay = 96;
if isfield(cfg, 'simulation') && isfield(cfg.simulation, 'dt_min')
    stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
end
timeHour = (0:stepsPerDay-1)' * 24 / stepsPerDay;
hold on;
for i = 1:maxCurves
    r = results{i};
    if ~isfield(r, 'L_feeder_w') || isempty(r.L_feeder_w)
        continue;
    end
    P = double(r.L_feeder_w);
    n = floor(size(P, 1) / stepsPerDay);
    if n < 1
        y = sum(P, 2) / 1000;
        x = linspace(0, 24, numel(y))';
    else
        P = P(1:n*stepsPerDay, :);
        P = reshape(P, stepsPerDay, n, size(P, 2));
        y = mean(sum(P, 3), 2) / 1000;
        x = timeHour;
    end
    plot(x, y, 'DisplayName', compact_label(r));
end
grid on;
xlabel('Hour of day');
ylabel('Total feeder load [kW]');
xlim([0 24]);
legend('Location', 'northoutside', 'Orientation', 'horizontal');
end

function [heatData, heatLabel] = transformer_loading_heatmap_data(results)
% TRANSFORMER_LOADING_HEATMAP_DATA Extract TL_pct matrix from last result with PQ cells.
heatData = [];
heatLabel = '';
for i = numel(results):-1:1
    r = results{i};
    if ~isfield(r, 'pq_timeseries') || isempty(r.pq_timeseries)
        continue;
    end
    pqCells = r.pq_timeseries(:);
    good = cellfun(@(p) isstruct(p) && isfield(p, 'TL_pct'), pqCells);
    pqCells = pqCells(good);
    if isempty(pqCells), continue; end
    maxSamples = min(numel(pqCells), 240);
    sampleIdx = unique(round(linspace(1, numel(pqCells), maxSamples)));
    tl = [];
    for k = 1:numel(sampleIdx)
        v = double(pqCells{sampleIdx(k)}.TL_pct(:));
        if isempty(tl)
            tl = nan(numel(v), numel(sampleIdx));
        end
        tl(:, k) = v;
    end
    heatData = tl;
    heatLabel = compact_label(r);
    return;
end
end

function y = first_finite(v, defaultValue)
% FIRST_FINITE First finite value from vector.
v = v(isfinite(v));
if isempty(v), y = defaultValue; else, y = v(1); end
end

function limit = get_limit(cfg, name, defaultValue)
% GET_LIMIT Read a PQ limit.
limit = defaultValue;
if isstruct(cfg) && isfield(cfg, 'pq_limits') && isfield(cfg.pq_limits, name)
    limit = cfg.pq_limits.(name);
end
end

function s = compact_label(r)
% COMPACT_LABEL Compact scenario label.
if isfield(r, 'scenario_id')
    if r.scenario_id == -1
        s = 'B0';
    else
        s = sprintf('S%g', r.scenario_id);
    end
else
    s = 'Scenario';
end
end

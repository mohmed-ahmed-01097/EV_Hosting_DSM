function out = plot_load_profiles(all_results, cfg)
% PLOT_LOAD_PROFILES Plot average 24-hour feeder load profiles by scenario.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results: Phase 5 scenario results containing L_feeder_w.
%   cfg (struct): Project configuration with dt_min and output folders.
%
% Outputs:
%   out (struct): Exported file paths and profile data used for plotting.
%
% Example:
%   out = plot_load_profiles(all_results, cfg);

% --- Section 1: Prepare data ---
if nargin < 2, cfg = struct(); end
results = viz_normalize_results(all_results);
stepsPerDay = 96;
if isfield(cfg, 'simulation') && isfield(cfg.simulation, 'dt_min')
    stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
end
timeHour = (0:stepsPerDay-1)' * 24 / stepsPerDay;

fig = figure('Name', 'Phase 6 - Load Profiles', 'Visible', 'off', ...
    'Units', 'pixels', 'Position', [100 100 1500 900], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Average 24-hour Load Profiles', 'FontWeight', 'bold');

profileData = struct();
profileData.labels = {};
profileData.total_kw = zeros(stepsPerDay, 0);
profileData.phase_kw = zeros(stepsPerDay, 3, 0);

% --- Section 2: Total feeder profile ---
nexttile(tl);
hold on;
for i = 1:numel(results)
    r = results{i};
    [phaseKw, totalKw, ok] = average_day_profile(r, stepsPerDay);
    if ~ok, continue; end
    plot(timeHour, totalKw, 'LineWidth', 1.2, 'DisplayName', compact_label(r));
    profileData.labels{end+1} = compact_label(r); %#ok<AGROW>
    profileData.total_kw(:, end+1) = totalKw; %#ok<AGROW>
    profileData.phase_kw(:, :, end+1) = phaseKw; %#ok<AGROW>
end
grid on;
xlabel('Hour of day');
ylabel('Total feeder load [kW]');
title('Total Feeder Load');
xlim([0 24]);
legend('Location', 'northoutside', 'Orientation', 'horizontal');

% --- Section 3: Phase profiles for last scenario ---
nexttile(tl);
rLast = results{end};
[phaseKw, ~, ok] = average_day_profile(rLast, stepsPerDay);
if ok
    plot(timeHour, phaseKw(:, 1), 'LineWidth', 1.2, 'DisplayName', 'Phase A'); hold on;
    plot(timeHour, phaseKw(:, 2), 'LineWidth', 1.2, 'DisplayName', 'Phase B');
    plot(timeHour, phaseKw(:, 3), 'LineWidth', 1.2, 'DisplayName', 'Phase C');
    grid on;
    xlabel('Hour of day'); ylabel('Phase load [kW]');
    title(sprintf('Phase Profiles - %s', compact_label(rLast)));
    xlim([0 24]);
    legend('Location', 'northoutside', 'Orientation', 'horizontal');
else
    text(0.1, 0.5, 'No L\_feeder\_w data available.'); axis off;
end

% --- Section 4: Peak load by scenario ---
nexttile(tl);
M = viz_result_metrics(results);
peakKw = nan(1, numel(results));
for i = 1:numel(results)
    if isfield(results{i}, 'L_feeder_w') && ~isempty(results{i}.L_feeder_w)
        peakKw(i) = max(sum(double(results{i}.L_feeder_w), 2)) / 1000;
    end
end
bar(1:numel(results), peakKw(:));
grid on;
ylabel('Peak feeder load [kW]');
title('Peak Load Comparison');
set(gca, 'XTick', 1:numel(results), 'XTickLabel', M.labels, 'XTickLabelRotation', 30);

% --- Section 5: Phase imbalance from feeder load ---
nexttile(tl);
imbalancePct = nan(1, numel(results));
for i = 1:numel(results)
    if isfield(results{i}, 'L_feeder_w') && ~isempty(results{i}.L_feeder_w)
        P = double(results{i}.L_feeder_w) / 1000;
        meanPhase = mean(P, 2);
        dev = max(abs(P - meanPhase), [], 2) ./ max(meanPhase, eps) * 100;
        imbalancePct(i) = max(dev);
    end
end
bar(1:numel(results), imbalancePct(:));
grid on;
ylabel('Peak phase-load deviation [%]');
title('Phase Load Imbalance Indicator');
set(gca, 'XTick', 1:numel(results), 'XTickLabel', M.labels, 'XTickLabelRotation', 30);

% --- Section 6: Export ---
files = viz_export_figure(fig, cfg, 'load_profiles');
out = struct('files', files, 'profile_data', profileData);
close(fig);
end

function [phaseKw, totalKw, ok] = average_day_profile(r, stepsPerDay)
% AVERAGE_DAY_PROFILE Average L_feeder_w into one daily profile.
ok = false;
phaseKw = nan(stepsPerDay, 3);
totalKw = nan(stepsPerDay, 1);
if ~isfield(r, 'L_feeder_w') || isempty(r.L_feeder_w)
    return;
end
P = double(r.L_feeder_w);
if size(P, 2) < 3
    P(:, end+1:3) = 0;
elseif size(P, 2) > 3
    P = P(:, 1:3);
end
if size(P, 1) < stepsPerDay
    P(end+1:stepsPerDay, :) = repmat(P(end, :), stepsPerDay - size(P, 1), 1);
end
nDays = floor(size(P, 1) / stepsPerDay);
if nDays < 1, return; end
P = P(1:nDays*stepsPerDay, :);
P = reshape(P, stepsPerDay, nDays, 3);
phaseKw = squeeze(mean(P, 2)) / 1000;
totalKw = sum(phaseKw, 2);
ok = true;
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

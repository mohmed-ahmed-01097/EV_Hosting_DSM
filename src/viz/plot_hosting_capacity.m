function out = plot_hosting_capacity(all_results, cfg)
% PLOT_HOSTING_CAPACITY Plot EV hosting capacity versus PQ stress.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results: Phase 5 scenario results.
%   cfg (struct): Project configuration with PQ limits and output folders.
%
% Outputs:
%   out (struct): Exported file paths and extracted metrics.
%
% Example:
%   out = plot_hosting_capacity(all_results, cfg);

% --- Section 1: Prepare metrics ---
if nargin < 2, cfg = struct(); end
M = viz_result_metrics(all_results);
N = numel(M.ids);
x = 1:N;
labels = M.labels;

fig = figure('Name', 'Phase 6 - Hosting Capacity', 'Visible', 'off', ...
    'Units', 'pixels', 'Position', [100 100 1300 800], 'Color', 'w');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'EV Hosting Capacity and PQ Constraints', 'FontWeight', 'bold');

% --- Section 2: Hosting capacity bar ---
nexttile(tl);
bar(x, M.hosting_capacity_pct(:));
grid on;
ylabel('Hosting capacity [% EV]');
title('Maximum EV Penetration Without Screened PQ Violation');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 25);

% --- Section 3: PQ stress at achieved scenario ---
nexttile(tl);
yyaxis left;
plot(x, M.max_vuf_pct, '-o', 'LineWidth', 1.3, 'MarkerSize', 6);
hold on;
yline(get_limit(cfg, 'vuf_max_pct', 2.0), '--', 'VUF limit');
ylabel('Peak VUF [%]');
yyaxis right;
plot(x, M.min_voltage_pu, '-s', 'LineWidth', 1.3, 'MarkerSize', 6);
yline(get_limit(cfg, 'voltage_min_pu', 0.90), '--', 'Voltage lower limit');
ylabel('Minimum voltage [pu]');
grid on;
title('PQ Stress Indicators');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 25);
legend({'Peak VUF', 'VUF limit', 'Vmin', 'Voltage limit'}, 'Location', 'northoutside', 'Orientation', 'horizontal');

% --- Section 4: Export ---
files = viz_export_figure(fig, cfg, 'hosting_capacity');
out = struct('files', files, 'metrics', M);
close(fig);
end

function limit = get_limit(cfg, name, defaultValue)
% GET_LIMIT Read PQ limit from cfg.
limit = defaultValue;
if isstruct(cfg) && isfield(cfg, 'pq_limits') && isfield(cfg.pq_limits, name)
    limit = cfg.pq_limits.(name);
end
end

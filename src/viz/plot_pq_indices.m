function out = plot_pq_indices(all_results, cfg)
% PLOT_PQ_INDICES Plot core power-quality indices across scenarios.
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
%   out = plot_pq_indices(all_results, cfg);

% --- Section 1: Prepare data ---
if nargin < 2, cfg = struct(); end
M = viz_result_metrics(all_results);
N = numel(M.ids);
x = 1:N;
labels = M.labels;

fig = figure('Name', 'Phase 6 - PQ Indices', 'Visible', 'off', ...
    'Units', 'pixels', 'Position', [100 100 1400 900], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Power Quality Indices Across Scenarios', 'FontWeight', 'bold');

% --- Section 2: Peak VUF ---
nexttile(tl);
bar(x, M.max_vuf_pct(:));
hold on;
yline(get_limit(cfg, 'vuf_max_pct', 2.0), '--', 'VUF limit');
grid on;
ylabel('Peak VUF [%]');
title('Voltage Unbalance');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 3: Minimum voltage ---
nexttile(tl);
bar(x, M.min_voltage_pu(:));
hold on;
yline(get_limit(cfg, 'voltage_min_pu', 0.90), '--', 'Lower limit');
yline(get_limit(cfg, 'voltage_max_pu', 1.10), '--', 'Upper limit');
grid on;
ylabel('Minimum voltage [pu]');
title('End-of-feeder Voltage Health');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 4: Transformer loading ---
nexttile(tl);
bar(x, M.max_loading_pct(:));
hold on;
yline(get_limit(cfg, 'transformer_loading_max_pct', 100.0), '--', 'Loading limit');
grid on;
ylabel('Peak transformer loading [%]');
title('Transformer Loading');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);

% --- Section 5: Losses and violations ---
nexttile(tl);
yyaxis left;
bar(x - 0.18, M.mean_loss_kw(:), 0.35);
ylabel('Mean feeder loss [kW]');
yyaxis right;
bar(x + 0.18, M.violation_count(:), 0.35);
ylabel('Violation steps [count]');
grid on;
title('Losses and Constraint Violations');
set(gca, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 30);
legend({'Mean loss', 'Violation steps'}, 'Location', 'northoutside', 'Orientation', 'horizontal');

% --- Section 6: Export ---
files = viz_export_figure(fig, cfg, 'pq_indices');
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

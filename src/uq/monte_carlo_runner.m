function mc = monte_carlo_runner(cfg, data, net, assignment, cal_struct, weather, n_runs, scenario_id)
% MONTE_CARLO_RUNNER Run N stochastic replications of one scenario.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg, data, net, assignment, cal_struct, weather - project structs.
%   n_runs (double, optional): number of Monte Carlo runs, default 30.
%   scenario_id (double, optional): scenario ID, default 4.
%
% Outputs:
%   mc (struct): KPI samples and summary statistics.
%
% Example:
%   mc = monte_carlo_runner(cfg,data,net,assignment,cal,weather,10,4);
if nargin < 7 || isempty(n_runs)
    n_runs = 30;
end
if nargin < 8 || isempty(scenario_id)
    scenario_id = 4;
end

kpiNames = {'mean_VUF_pct','peak_VUF_pct','V_min_pu','max_TL_pct', ...
    'hosting_cap_pct','mean_CI','mean_bill_EGP','losses_kW'};
kpiMat = nan(n_runs, numel(kpiNames));
runFn = str2func(sprintf('run_scenario%d', scenario_id));
tStart = tic;

for r = 1:n_runs
    fprintf('[monte_carlo_runner] Run %d/%d...\n', r, n_runs);
    try
        cfgR = cfg;
        cfgR.seed = cfg.seed + r * 137;
        rng(cfgR.seed, 'twister');
        assignR = assign_households(cfgR, data, net);
        popR = simulate_population(cfgR, data, assignR, net, cal_struct, weather);
        rOut = runFn(cfgR, data, net, assignR, popR, cal_struct, weather);
        kpiMat(r, :) = extract_kpis_mc(rOut);
    catch ME
        warning('monte_carlo_runner:runFailed', 'Run %d failed: %s', r, ME.message);
    end
end

mc = struct();
mc.n_runs = n_runs;
mc.scenario_id = scenario_id;
mc.kpis = kpiMat;
mc.kpi_names = kpiNames;
mc.stats.mean = mean(kpiMat, 1, 'omitnan');
mc.stats.std = std(kpiMat, 0, 1, 'omitnan');
mc.stats.p5 = prctile(kpiMat, 5);
mc.stats.p25 = prctile(kpiMat, 25);
mc.stats.p50 = prctile(kpiMat, 50);
mc.stats.p75 = prctile(kpiMat, 75);
mc.stats.p95 = prctile(kpiMat, 95);
mc.runtime_s = toc(tStart);

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end
outFile = fullfile(cfg.output_dir, sprintf('mc_s%d_N%d.mat', scenario_id, n_runs));
save(outFile, 'mc', '-v7.3');
fprintf('[monte_carlo_runner] Done: %d runs in %.1f s.\n', n_runs, mc.runtime_s);
end

function kpi = extract_kpis_mc(r)
% EXTRACT_KPIS_MC Extract KPI row robustly from scenario result.
kpi = nan(1, 8);
if ~isstruct(r)
    return;
end
kpi(1) = nested_mean(r, {'pq_summary','mean_vuf_pct'});
kpi(2) = nested_mean(r, {'pq_summary','max_vuf_pct'});
kpi(3) = nested_mean(r, {'pq_summary','min_voltage_pu'});
kpi(4) = nested_mean(r, {'pq_summary','max_loading_pct'});
kpi(5) = nested_mean(r, {'hosting_capacity_pct'});
kpi(6) = first_finite([nested_mean(r, {'comfort_summary','mean'}), nested_mean(r, {'comfort_summary','mean_ci'})]);
kpi(7) = nested_mean(r, {'costs','bill_total','Block'});
kpi(8) = first_finite([nested_mean(r, {'pq_summary','mean_loss_kw'}), nested_mean(r, {'pq_summary','total_losses_kw'})]);
end

function val = nested_mean(s, path)
% NESTED_MEAN Read nested numeric field and average it.
val = NaN;
try
    v = s;
    for i = 1:numel(path)
        v = v.(path{i});
    end
    if isnumeric(v)
        val = mean(v(:), 'omitnan');
    end
catch
    val = NaN;
end
end

function val = first_finite(vals)
% FIRST_FINITE Return first finite value.
val = NaN;
for i = 1:numel(vals)
    if isfinite(vals(i))
        val = vals(i);
        return;
    end
end
end

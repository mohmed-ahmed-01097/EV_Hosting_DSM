function sa = sensitivity_analysis(cfg, data, net, assignment, cal_struct, weather, opts)
% SENSITIVITY_ANALYSIS One-at-a-time parameter sensitivity sweep.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg, data, net, assignment, cal_struct, weather - project structs.
%   opts (struct, optional): scenario_id, verbose.
%
% Outputs:
%   sa (struct): parameter names, sweep values, KPI matrix, and sensitivity indices.
%
% Example:
%   sa = sensitivity_analysis(cfg,data,net,assignment,cal,weather,struct('scenario_id',4));
if nargin < 7 || isempty(opts)
    opts = struct();
end
scenarioId = get_opt(opts, 'scenario_id', 4);
verbose = get_opt(opts, 'verbose', true);

sweepDefs = {
    'ev_penetration',   [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40];
    'lambda_comfort',   [0.0001, 0.001, 0.01, 0.10];
    'hvac_setpoint_C',  [22, 23, 24, 25, 26];
    'dt_min',           [5, 10, 15];
    'v2g_revenue_frac', [0.30, 0.40, 0.50, 0.60, 0.70]
};
kpiNames = {'mean_VUF_pct','peak_VUF_pct','V_min_pu','max_TL_pct', ...
    'hosting_cap_pct','mean_CI','mean_bill_EGP','losses_kW'};

sa = struct();
sa.parameter_names = sweepDefs(:, 1);
sa.sweep_values = sweepDefs(:, 2);
sa.kpi_matrix = cell(size(sweepDefs, 1), 1);
sa.kpi_names = kpiNames;
sa.sensitivity_index = struct();
sa.scenario_id = scenarioId;
runFn = str2func(sprintf('run_scenario%d', scenarioId));

for p = 1:size(sweepDefs, 1)
    pName = sweepDefs{p, 1};
    pVals = sweepDefs{p, 2};
    kpiMat = nan(numel(pVals), numel(kpiNames));
    if verbose
        fprintf('[sensitivity_analysis] Sweeping %s (%d values)...\n', pName, numel(pVals));
    end
    for v = 1:numel(pVals)
        try
            cfgV = apply_param_override(cfg, pName, pVals(v));
            if strcmp(pName, 'dt_min')
                calV = daytype_calendar(cfgV);
                weatherV = get_weather(cfgV);
            else
                calV = cal_struct;
                weatherV = weather;
            end
            netV = build_feeder_network(cfgV);
            assignV = assign_households(cfgV, data, netV);
            popV = simulate_population(cfgV, data, assignV, netV, calV, weatherV);
            r = runFn(cfgV, data, netV, assignV, popV, calV, weatherV);
            kpiMat(v, :) = extract_kpis(r);
        catch ME
            warning('sensitivity_analysis:runFailed', '%s=%.4g failed: %s', pName, pVals(v), ME.message);
        end
    end
    sa.kpi_matrix{p} = kpiMat;
    baseRow = max(1, round(numel(pVals) / 2));
    sa.sensitivity_index.(pName) = ...
        (max(kpiMat, [], 1, 'omitnan') - min(kpiMat, [], 1, 'omitnan')) ./ ...
        max(abs(kpiMat(baseRow, :)), 1e-9);
end

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end
save(fullfile(cfg.output_dir, 'sensitivity_analysis.mat'), 'sa', '-v7.3');
if verbose
    fprintf('[sensitivity_analysis] Done.\n');
end
end

function cfgV = apply_param_override(cfg, name, val)
% APPLY_PARAM_OVERRIDE Return cfg copy with one parameter changed.
cfgV = cfg;
switch name
    case 'ev_penetration'
        cfgV.ev.penetration_rate = val;
    case 'lambda_comfort'
        cfgV.dsm.lambda_comfort = val;
    case 'hvac_setpoint_C'
        cfgV.hvac.summer_setpoint_c = val;
    case 'v2g_revenue_frac'
        cfgV.ev.v2g_revenue_fraction = val;
    case 'dt_min'
        cfgV.simulation.dt_min = val;
        cfgV.simulation.dt_hr = val / 60;
        cfgV.simulation.Tsteps = cfgV.simulation.horizon_days * 24 * 60 / val;
        cfgV.simulation.tvec_min = (0:cfgV.simulation.Tsteps-1)' * val;
end
end

function kpi = extract_kpis(r)
% EXTRACT_KPIS Extract KPI row robustly from scenario result.
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

function v = get_opt(opts, name, defaultValue)
% GET_OPT Read option with default.
if isfield(opts, name)
    v = opts.(name);
else
    v = defaultValue;
end
end

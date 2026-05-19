function results = run_scenario2(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO2 Compare slow (3.7 kW) versus fast (7.4 kW) uncontrolled EV charging.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs: cfg, data, net, assignment, pop, cal_struct, weather, progress_cb.
% Outputs: results struct with .slow, .fast, and .comparison_table.
% Example: results = run_scenario2(cfg,data,net,assignment,pop,cal,weather);
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

assignSlow = force_charger(assignment, 'slow');
assignFast = force_charger(assignment, 'fast');
modeBase = struct('ev_enabled', true, 'dsm_enabled', false, 'v2g_enabled', false, ...
    'dispatch_mode', 'uncontrolled_ev');

progress_cb(5, 'Scenario 2a: slow charger uncontrolled EV...');
drawnow('limitrate');
modeSlow = modeBase;
modeSlow.charger_override = 'slow';
results.slow = run_scenario_core(cfg, data, net, assignSlow, pop, cal_struct, weather, ...
    2.1, 'Scenario 2a: Slow 3.7 kW uncontrolled EV charging', modeSlow, ...
    @(pct,msg) progress_cb(min(50, round(0.05 * 100 + 0.45 * pct)), msg));

progress_cb(55, 'Scenario 2b: fast charger uncontrolled EV...');
drawnow('limitrate');
modeFast = modeBase;
modeFast.charger_override = 'fast';
results.fast = run_scenario_core(cfg, data, net, assignFast, pop, cal_struct, weather, ...
    2.2, 'Scenario 2b: Fast 7.4 kW uncontrolled EV charging', modeFast, ...
    @(pct,msg) progress_cb(min(99, round(55 + 0.44 * pct)), msg));

kpis = {'mean_vuf_pct','max_vuf_pct','min_voltage_pu','max_loading_pct','mean_loss_kw','max_thdi_pct','max_thdv_pct'};
labels = {'Mean VUF (%)','Peak VUF (%)','V_min (pu)','Max TL (%)','Mean Losses (kW)','Max THDi (%)','Max THDv (%)'};
vSlow = cellfun(@(k) safe_pq(results.slow, k), kpis);
vFast = cellfun(@(k) safe_pq(results.fast, k), kpis);
results.comparison_table = table(labels', vSlow', vFast', ...
    'VariableNames', {'KPI','Slow_3p7kW','Fast_7p4kW'});
results.comparison = struct('slow', results.slow, 'fast', results.fast);
% Backward-compatible top-level fields use the fast-charger case because it is
% the more conservative stress case for feeder/PQ reporting.
results.scenario_id = 2;
results.description = 'Scenario 2: Slow versus fast uncontrolled EV charging comparison';
results.pq_summary = results.fast.pq_summary;
results.costs = results.fast.costs;
if isfield(results.fast, 'L_feeder_w')
    results.L_feeder_w = results.fast.L_feeder_w;
end
results.hosting_capacity_pct = results.fast.hosting_capacity_pct;
results.comfort_summary = results.fast.comfort_summary;
results.runtime_s = results.slow.runtime_s + results.fast.runtime_s;
progress_cb(100, 'Scenario 2 complete.');
drawnow('limitrate');
end

function a2 = force_charger(a, type)
% FORCE_CHARGER Force all EV households to the requested charger type.
a2 = a;
for h = 1:numel(a.has_ev)
    if a.has_ev(h)
        a2.charger_type{h} = type;
    end
end
end

function v = safe_pq(r, key)
% SAFE_PQ Robustly read a scalar KPI from r.pq_summary.
v = NaN;
try
    if isfield(r, 'pq_summary') && isfield(r.pq_summary, key)
        raw = r.pq_summary.(key);
        v = mean(raw(:), 'omitnan');
    end
catch
    v = NaN;
end
end

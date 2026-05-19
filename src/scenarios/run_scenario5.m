function results = run_scenario5(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO5 Run Scenario 5: MILP-controlled loads, EV, and V2G.
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', true, ...
    'dispatch_mode', 'milp_v2g', 'schedule_flexible_loads', true);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    5, 'Scenario 5: MILP-controlled loads, EV charging, and V2G', mode, progress_cb);
end

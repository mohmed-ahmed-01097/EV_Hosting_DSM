function results = run_scenario6(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO6 Run Scenario 6: full hierarchical AI-DSM.
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', true, ...
    'dispatch_mode', 'supervised_milp', 'schedule_flexible_loads', true);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    6, 'Scenario 6: full hierarchical AI-DSM with feeder supervisor and V2G', mode, progress_cb);
end

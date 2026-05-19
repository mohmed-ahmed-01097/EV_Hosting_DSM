function results = run_scenario3(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO3 Run Scenario 3: MILP-controlled EV only.
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', false, ...
    'dispatch_mode', 'milp_ev_only', 'schedule_flexible_loads', false);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    3, 'Scenario 3: MILP-controlled EV charging only', mode, progress_cb);
end

function results = run_scenario1(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO1 Run Scenario 1: uncontrolled EV integration.
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', true, 'dsm_enabled', false, 'v2g_enabled', false, ...
    'dispatch_mode', 'uncontrolled_ev');
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    1, 'Scenario 1: uncontrolled EV integration', mode, progress_cb);
end

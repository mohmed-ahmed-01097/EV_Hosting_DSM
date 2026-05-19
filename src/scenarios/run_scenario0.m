function results = run_scenario0(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_SCENARIO0 Run Scenario 0: no EVs with rule-based DSM.
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', false, 'dsm_enabled', true, 'v2g_enabled', false, ...
    'dispatch_mode', 'rule_based');
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    0, 'Scenario 0: no EVs with rule-based DSM', mode, progress_cb);
end

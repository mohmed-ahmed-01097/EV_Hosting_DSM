function results = run_scenario0(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO0 Run Scenario 0: no EVs with rule-based DSM.
mode = struct('ev_enabled', false, 'dsm_enabled', true, 'v2g_enabled', false, ...
    'dispatch_mode', 'rule_based');
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    0, 'Scenario 0: no EVs with rule-based DSM', mode);
end

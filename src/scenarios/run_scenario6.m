function results = run_scenario6(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO6 Run Scenario 6: full hierarchical AI-DSM.
mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', true, ...
    'dispatch_mode', 'supervised_milp', 'schedule_flexible_loads', true);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    6, 'Scenario 6: full hierarchical AI-DSM with feeder supervisor and V2G', mode);
end

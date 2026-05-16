function results = run_scenario4(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO4 Run Scenario 4: MILP-controlled loads plus EV.
mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', false, ...
    'dispatch_mode', 'milp', 'schedule_flexible_loads', true);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    4, 'Scenario 4: MILP-controlled household loads and EV charging', mode);
end

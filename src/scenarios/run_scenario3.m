function results = run_scenario3(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO3 Run Scenario 3: MILP-controlled EV only.
mode = struct('ev_enabled', true, 'dsm_enabled', true, 'v2g_enabled', false, ...
    'dispatch_mode', 'milp_ev_only', 'schedule_flexible_loads', false);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    3, 'Scenario 3: MILP-controlled EV charging only', mode);
end

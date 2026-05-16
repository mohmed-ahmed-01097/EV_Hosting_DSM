function results = run_scenario2(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO2 Run Scenario 2: slow versus fast uncontrolled EV charging.
mode = struct('ev_enabled', true, 'dsm_enabled', false, 'v2g_enabled', false, ...
    'dispatch_mode', 'uncontrolled_ev', 'compare_charger_types', true);
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    2, 'Scenario 2: slow versus fast uncontrolled EV charging', mode);
end

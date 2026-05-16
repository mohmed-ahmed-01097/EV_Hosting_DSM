function results = run_scenario1(cfg, data, net, assignment, pop, cal_struct, weather)
% RUN_SCENARIO1 Run Scenario 1: uncontrolled EV integration.
mode = struct('ev_enabled', true, 'dsm_enabled', false, 'v2g_enabled', false, ...
    'dispatch_mode', 'uncontrolled_ev');
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    1, 'Scenario 1: uncontrolled EV integration', mode);
end

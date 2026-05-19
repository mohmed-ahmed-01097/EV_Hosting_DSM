function results = run_baseline0(cfg, data, net, assignment, pop, cal_struct, weather, progress_cb)
% RUN_BASELINE0 Run Baseline 0: no EVs and no DSM.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs: cfg, data, net, assignment, pop, cal_struct, weather.
% Outputs: results struct with scenario metrics.
% Example: results = run_baseline0(cfg,data,net,assignment,pop,cal,weather);
if nargin < 8 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

mode = struct('ev_enabled', false, 'dsm_enabled', false, 'v2g_enabled', false, ...
    'dispatch_mode', 'none');
results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, ...
    -1, 'Baseline 0: no EVs and no DSM', mode, progress_cb);
end

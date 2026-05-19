function all_results = run_all_scenarios(cfg, data, net, assignment, pop, cal_struct, weather, scenarios_to_run, progress_cb)
% RUN_ALL_SCENARIOS Execute selected Phase 5 scenario runners.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg, data, net, assignment, pop, cal_struct, weather - project structs.
%   scenarios_to_run (numeric, optional): scenario IDs, with -1 for Baseline 0.
%
% Outputs:
%   all_results (cell): Scenario result structs in requested order.
%
% Example:
%   all_results = run_all_scenarios(cfg,data,net,assignment,pop,cal,weather,[-1 1 4 6]);
if nargin < 8 || isempty(scenarios_to_run)
    scenarios_to_run = [-1 0 1 2 3 4 5 6];
end
if nargin < 9 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end
all_results = cell(numel(scenarios_to_run), 1);
for k = 1:numel(scenarios_to_run)
    sid = scenarios_to_run(k);
    fprintf('\n[run_all_scenarios] === Running scenario %g ===\n', sid);
    switch sid
        case -1
            all_results{k} = run_baseline0(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 0
            all_results{k} = run_scenario0(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 1
            all_results{k} = run_scenario1(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 2
            all_results{k} = run_scenario2(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 3
            all_results{k} = run_scenario3(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 4
            all_results{k} = run_scenario4(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 5
            all_results{k} = run_scenario5(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        case 6
            all_results{k} = run_scenario6(cfg, data, net, assignment, pop, cal_struct, weather, @(pct,msg) progress_cb(round(((k-1)*100 + pct)/numel(scenarios_to_run)), msg));
        otherwise
            error('run_all_scenarios:unknownScenario', 'Unknown scenario id: %g', sid);
    end
end
end

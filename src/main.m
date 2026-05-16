function main(config_path, varargin)
% MAIN Top-level runner for implemented Phase 0 and Phase 1 layers.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   config_path (char/string, optional): JSON config path.
%   varargin: use 'validate' to run validation tests.
%
% Outputs:
%   None.
%
% Example:
%   main([], 'validate')
%   main('config/scenario_configs/scenario1.json')

if nargin < 1
    config_path = '';
end

thisFile = mfilename('fullpath');
srcDir = fileparts(thisFile);
rootDir = fileparts(srcDir);
addpath(genpath(fullfile(rootDir, 'src')));
addpath(genpath(fullfile(rootDir, 'tests')));

if any(strcmpi(varargin, 'validate'))
    run_config_tests();
    return;
end

% --- Section 1: Phase 0 IO layer ---
cfg = config_loader(config_path);
data = data_loader(cfg);
cal_struct = daytype_calendar(cfg);
weather = get_weather(cfg);

fprintf('[main] Phase 0 complete: config, survey data, calendar, and weather loaded successfully.\n');
fprintf('[main] Data rows: households=%d, residents=%d, occupancy=%d, activities=%d, appliances=%d, HVAC=%d, EV=%d.\n', ...
    height(data.household), height(data.residents), height(data.occ_pmf), height(data.activities), ...
    height(data.appliances), height(data.hvac), height(data.ev));
fprintf('[main] Calendar/weather: steps=%d, weather source=%s.\n', cfg.simulation.Tsteps, weather.meta.source);

% --- Section 2: Phase 1 feeder layer ---
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);
S_test = (3500 + 1j * 900) * ones(3, net.n_buses);
[V_bus, I_branch, I_neutral, converged] = bfs_power_flow(net, S_test, assignment);
pq = compute_pq_indices(V_bus, I_branch, I_neutral, S_test, net, cfg);

if ~converged
    warning('main:phase1Bfs', 'Phase 1 BFS smoke test did not converge.');
end

fprintf('[main] Phase 1 complete: feeder built, households assigned, BFS and PQ smoke test executed.\n');
fprintf('[main] Phase 1 smoke metrics: Vmin=%.4f pu | max VUF=%.3f%% | max TL=%.2f%%.\n', ...
    pq.V_min_pu, max(pq.VUF_pct), max(pq.TL_pct));
fprintf('[main] Next implementation step: Phase 2 behavior-driven load model.\n');
end

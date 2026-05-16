function main(config_path, varargin)
% MAIN Top-level runner for implemented Phase 0 through Phase 5 layers.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   config_path (char/string, optional): JSON config path.
%   varargin:
%       'validate'              - run validation tests.
%       'scenario', N           - run one scenario ID N (-1,0..6).
%       'scenarios', [ids]      - run selected scenario IDs.
%       'all_scenarios'         - run Baseline 0 and Scenarios 0..6.
%
% Outputs:
%   None. Scenario runs are saved to results/scenario_results.mat.
%
% Example:
%   main([], 'validate')
%   main([], 'scenario', 4)
%   main([], 'all_scenarios')
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

scenarioIds = parse_scenario_request(varargin);

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

% --- Section 3: Phase 2 behavior-driven load layer smoke test ---
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
cal_day.daytype = cal_struct.daytype(1);
cal_day.season = cal_struct.season(1);
cal_day.is_ramadan = cal_struct.is_ramadan(1);
weather_day = weather.temp_C(1:stepsPerDay);
hh = simulate_household(1, assignment, data, weather_day, cal_day, cfg);
daily_kwh = sum(hh.p_total_w) * cfg.simulation.dt_hr / 1000;

fprintf('[main] Phase 2 complete: one-household behavior-driven load smoke test executed.\n');
fprintf('[main] Phase 2 smoke metrics: daily energy=%.2f kWh | HVAC=%.2f kWh | controllable runs=%d | EV present=%d.\n', ...
    daily_kwh, sum(hh.p_hvac_w) * cfg.simulation.dt_hr / 1000, hh.flexibility.count, hh.ev.present);

% --- Section 4: Phase 3 pricing engine smoke test ---
L_demo_w = repmat(hh.p_total_w, 1, 2);
L_demo_w(:,2) = L_demo_w(:,2) + 500;
costs = compute_costs(cfg, L_demo_w, cfg.simulation.tvec_min(1:stepsPerDay), cal_struct);

fprintf('[main] Phase 3 complete: seven-tariff pricing smoke test executed.\n');
fprintf('[main] Phase 3 smoke metrics: Flat bills=[%.2f %.2f] EGP | Block bills=[%.2f %.2f] EGP.\n', ...
    costs.bill_total.Flat(1), costs.bill_total.Flat(2), costs.bill_total.Block(1), costs.bill_total.Block(2));

% --- Section 5: Phase 4 DSM controller smoke test ---
price_demo = pricing_tou(cfg, cfg.simulation.tvec_min(1:stepsPerDay), cal_struct);
schedule = run_household_milp(hh, price_demo, cfg);
fprintf('[main] Phase 4 complete: household DSM scheduling smoke test executed.\n');
fprintf('[main] Phase 4 smoke metrics: method=%s | cost=%.2f EGP | comfort=%.3f | EV max charge=%.1f W.\n', ...
    schedule.method, schedule.cost_EGP, schedule.comfort_idx, max(schedule.p_ev));

% --- Section 6: Phase 5 scenario execution when requested ---
if ~isempty(scenarioIds)
    pop = load_or_simulate_population(cfg, data, assignment, net, cal_struct, weather);
    all_results = run_all_scenarios(cfg, data, net, assignment, pop, cal_struct, weather, scenarioIds); %#ok<NASGU>
    outFile = fullfile(cfg.output_dir, 'scenario_results.mat');
    save(outFile, 'all_results', 'scenarioIds', '-v7.3');
    fprintf('[main] Phase 5 complete: scenario results saved to %s\n', outFile);
else
    fprintf('[main] Phase 5 scenario runners are implemented. Use main([], ''scenario'', 4) or main([], ''all_scenarios'') to execute them.\n');
end
end

function scenarioIds = parse_scenario_request(args)
% PARSE_SCENARIO_REQUEST Parse scenario-related varargin.
scenarioIds = [];
if any(strcmpi(args, 'all_scenarios'))
    scenarioIds = [-1 0 1 2 3 4 5 6];
    return;
end
idx = find(strcmpi(args, 'scenario'), 1, 'first');
if ~isempty(idx) && idx < numel(args)
    scenarioIds = double(args{idx + 1});
    return;
end
idx = find(strcmpi(args, 'scenarios'), 1, 'first');
if ~isempty(idx) && idx < numel(args)
    scenarioIds = double(args{idx + 1});
end
end

function pop = load_or_simulate_population(cfg, data, assignment, net, cal_struct, weather)
% LOAD_OR_SIMULATE_POPULATION Load a versioned cache or run Phase 2 population model.
% Delegate cache handling to simulate_population so stale caches created by older
% EV feasibility logic are automatically invalidated.
pop = simulate_population(cfg, data, assignment, net, cal_struct, weather);
end

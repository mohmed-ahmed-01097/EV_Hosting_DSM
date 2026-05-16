function test_phase5_scenarios()
% TEST_PHASE5_SCENARIOS Validate Phase 5 scenario runners on a one-day fixture.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None.
%
% Outputs:
%   Prints PASS/FAIL validation results.
%
% Example:
%   test_phase5_scenarios()

fprintf('\n[test_phase5_scenarios] Starting Phase 5 scenario validation...\n');

cfg = make_short_cfg(config_loader());
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);
assignment = slice_assignment(assignment, cfg.feeder.num_households);
cal_struct = daytype_calendar(cfg);
weather = make_test_weather(cfg, cal_struct);
pop = make_test_population(cfg, assignment);

rBase = run_baseline0(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(isfield(rBase, 'pq_summary'), 'Baseline result includes pq_summary');
assert_pass(isfield(rBase, 'costs') && isfield(rBase.costs.bill_total, 'Block'), ...
    'Baseline result includes seven-tariff costs');
assert_pass(size(rBase.L_feeder_w, 1) == cfg.simulation.Tsteps && size(rBase.L_feeder_w, 2) == 3, ...
    sprintf('Baseline L_feeder_w has expected size %dx3', cfg.simulation.Tsteps));
assert_pass(isfinite(rBase.hosting_capacity_pct), ...
    sprintf('Baseline hosting capacity estimate finite: %.1f%%', rBase.hosting_capacity_pct));

r1 = run_scenario1(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(sum(r1.L_house_w(:)) > sum(rBase.L_house_w(:)), ...
    'Scenario 1 uncontrolled EV adds energy above baseline');
assert_pass(r1.pq_summary.max_loading_pct >= rBase.pq_summary.max_loading_pct, ...
    'Scenario 1 loading is not lower than baseline');

r2 = run_scenario2(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(isfield(r2, 'comparison') && isfield(r2.comparison, 'slow') && isfield(r2.comparison, 'fast'), ...
    'Scenario 2 includes slow/fast comparison structs');
assert_pass(r2.comparison.fast.pq_summary.max_loading_pct >= r2.comparison.slow.pq_summary.max_loading_pct, ...
    'Fast charging comparison has loading at least as high as slow charging');

r3 = run_scenario3(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(isfield(r3, 'comfort_summary') && r3.comfort_summary.count > 0, ...
    'Scenario 3 returns comfort summary from EV-only MILP schedules');
assert_pass(isfinite(r3.pq_summary.min_voltage_pu), 'Scenario 3 PQ summary is finite');

r4 = run_scenario4(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(r4.comfort_summary.mean >= 0 && r4.comfort_summary.mean <= 1, ...
    sprintf('Scenario 4 comfort mean is in [0,1]: %.3f', r4.comfort_summary.mean));
assert_pass(size(r4.L_house_w, 2) == cfg.feeder.num_households, 'Scenario 4 household matrix width is correct');

r5 = run_scenario5(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(isfield(r5, 'schedules') && ~isempty(r5.schedules), 'Scenario 5 stores household schedules');
assert_pass(isfinite(r5.pq_summary.max_vuf_pct), 'Scenario 5 PQ summary is finite');

r6 = run_scenario6(cfg, data, net, assignment, pop, cal_struct, weather);
assert_pass(isfield(r6, 'schedules') && ~isempty(r6.schedules), 'Scenario 6 stores feeder-supervisor schedules');
assert_pass(r6.comfort_summary.mean >= 0 && r6.comfort_summary.mean <= 1, ...
    sprintf('Scenario 6 comfort mean is in [0,1]: %.3f', r6.comfort_summary.mean));

allResults = run_all_scenarios(cfg, data, net, assignment, pop, cal_struct, weather, [-1 1 4]);
assert_pass(numel(allResults) == 3 && allResults{2}.scenario_id == 1, ...
    'run_all_scenarios executes requested scenario IDs in order');

fprintf('[test_phase5_scenarios] Complete. Phase 5 scenario validation passed.\n');
end

function cfg = make_short_cfg(cfg)
% MAKE_SHORT_CFG Use a one-day, five-household deterministic fixture.
cfg.simulation.start_date = '2025-07-07';
cfg.simulation.end_date = '2025-07-08';
cfg.simulation.d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.d2 = datetime(cfg.simulation.end_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.horizon_days = days(cfg.simulation.d2 - cfg.simulation.d1);
cfg.simulation.dt_min = 15;
cfg.simulation.dt_hr = 0.25;
cfg.simulation.Tsteps = 96;
cfg.simulation.tvec_min = (0:cfg.simulation.Tsteps-1)' * cfg.simulation.dt_min;
cfg.feeder.num_households = 5;
cfg.feeder.households_per_zone = [1 1 1 1 1];
cfg.feeder.num_transformer_zones = 5;
cfg.ev.penetration_rate = 0.60;
cfg.ev.v2g_enabled = true;
cfg.pricing.active_methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
cfg.pricing.main_method = 'TOU';
cfg.dsm.max_coordination_iterations = 1;
cfg.output_dir = fullfile(cfg.root_folder, 'results', 'test_phase5');
cfg.figs_dir = fullfile(cfg.output_dir, 'figures');
cfg.tables_dir = fullfile(cfg.output_dir, 'tables');
if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figs_dir, 'dir'), mkdir(cfg.figs_dir); end
if ~exist(cfg.tables_dir, 'dir'), mkdir(cfg.tables_dir); end
end

function assignment = slice_assignment(assignment, H)
% SLICE_ASSIGNMENT Keep first H households and force EV diversity.
fields = fieldnames(assignment);
for i = 1:numel(fields)
    f = fields{i};
    v = assignment.(f);
    if isnumeric(v) || islogical(v)
        if size(v, 1) >= H
            assignment.(f) = v(1:H, :);
        end
    elseif iscell(v)
        if numel(v) >= H
            assignment.(f) = v(1:H);
        end
    end
end
assignment.household_id = (1:H)';
assignment.has_ev = [true; true; true; false; false];
assignment.charger_type = {'slow'; 'fast'; 'v2g'; 'none'; 'none'};
assignment.ev_battery_kwh = [40; 60; 75; 0; 0];
end

function weather = make_test_weather(cfg, cal_struct)
% MAKE_TEST_WEATHER Deterministic one-day summer weather.
weather = struct();
weather.timestamps = cal_struct.timestamps;
weather.temp_C = 38 + 6 * sin(2*pi*((0:cfg.simulation.Tsteps-1)'/cfg.simulation.Tsteps - 0.25));
weather.meta = struct('source', 'test_fixture', 'city', 'Assiut', 'lat', cfg.location.latitude, ...
    'lon', cfg.location.longitude, 'cache_file', 'none');
end

function pop = make_test_population(cfg, assignment)
% MAKE_TEST_POPULATION Create a deterministic Phase 5 population fixture.
T = cfg.simulation.Tsteps;
H = cfg.feeder.num_households;
hour = mod(cfg.simulation.tvec_min / 60, 24);
baseShape = 450 + 250 * exp(-0.5*((hour - 20)/2.0).^2) + 120 * exp(-0.5*((hour - 7)/1.5).^2);
hvacShape = 500 + 700 * exp(-0.5*((hour - 15)/3.0).^2);
pop = struct();
pop.L_house_w = zeros(T, H);
pop.L_fixed_w = zeros(T, H);
pop.L_ctrl_w = zeros(T, H);
pop.L_hvac_w = zeros(T, H);
pop.flexibility = cell(H, 1);
pop.EV = cell(H, 1);
for h = 1:H
    pop.L_fixed_w(:, h) = baseShape + hvacShape + 20*h;
    pop.L_ctrl_w(:, h) = zeros(T, 1);
    pref = 36 + 4*h;
    dur = 4;
    pop.L_ctrl_w(pref:pref+dur-1, h) = 700;
    pop.L_hvac_w(:, h) = hvacShape;
    pop.L_house_w(:, h) = pop.L_fixed_w(:, h) + pop.L_ctrl_w(:, h);
    pop.flexibility{h} = make_flex(pref, dur, 700);
    pop.EV{h} = struct('present', assignment.has_ev(h));
end
pop.metadata = struct('config_hash', 'phase5_test', 'created_on', datestr(now, 31), ...
    'dt_min', cfg.simulation.dt_min, 'num_households', H, 'num_days', 1);
end

function flex = make_flex(pref, dur, powerW)
% MAKE_FLEX Single controllable load flexibility.
flex = struct();
flex.count = 1;
flex.appliance = {'Washing_Machine'};
flex.duration_steps = dur;
flex.power_w = powerW;
flex.earliest_start_step = max(1, pref - 8);
flex.latest_start_step = min(96 - dur + 1, pref + 8);
flex.preferred_start_step = pref;
flex.max_shift_steps = 8;
flex.weight = 1.0;
end

function assert_pass(cond, msg)
% ASSERT_PASS Print PASS or fail loudly.
if cond
    fprintf('  PASS: %s\n', msg);
else
    fprintf('  FAIL: %s\n', msg);
    error('test_phase5_scenarios:assert', '%s', msg);
end
end

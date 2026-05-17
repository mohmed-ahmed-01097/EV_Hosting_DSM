function test_phase2_load_model()
% TEST_PHASE2_LOAD_MODEL Validate population-level Phase 2 smoke simulation.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None.
%
% Outputs:
%   Prints PASS/FAIL assertions.
%
% Example:
%   test_phase2_load_model()

fprintf('\n[test_phase2_load_model] Starting Phase 2 population smoke tests...\n');
cfg = make_small_one_day_cfg(config_loader());
data = data_loader(cfg);
cal = daytype_calendar(cfg);
weather.timestamps = cal.timestamps;
weather.temp_C = 39 + 3 * sin(pi * (cal.hour_of_day - 6) / 12);
weather.meta.source = 'test_synthetic';
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

rng(41, 'twister');
pop = simulate_population(cfg, data, assignment, net, cal, weather);
expectedSize = [cfg.simulation.Tsteps, cfg.feeder.num_households];
assert_pass(isequal(size(pop.L_house_w), expectedSize), sprintf('L_house_w size = %dx%d', size(pop.L_house_w,1), size(pop.L_house_w,2)));
assert_pass(all(isfinite(pop.L_house_w(:))) && all(pop.L_house_w(:) >= 0), 'Population load matrix is finite and nonnegative');
assert_pass(max(abs(pop.L_house_w(:) - pop.L_fixed_w(:) - pop.L_ctrl_w(:))) < 1e-6, 'Population power balance fixed + controllable');
assert_pass(sum(pop.L_house_w(:)) > 0, sprintf('Population daily energy positive: %.2f kWh', pop.metadata.energy_kwh_total));
assert_pass(numel(pop.EV) == cfg.feeder.num_households, 'EV cell array length matches household count');
assert_pass(numel(pop.flexibility) == cfg.feeder.num_households, 'Flexibility cell array length matches household count');
fprintf('[test_phase2_load_model] Complete.\n');
end

function cfg = make_small_one_day_cfg(cfg)
cfg.simulation.start_date = '2025-07-07';
cfg.simulation.end_date = '2025-07-08';
cfg.simulation.d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.d2 = datetime(cfg.simulation.end_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.horizon_days = days(cfg.simulation.d2 - cfg.simulation.d1);
cfg.simulation.dt_hr = cfg.simulation.dt_min / 60;
cfg.simulation.Tsteps = cfg.simulation.horizon_days * 24 * 60 / cfg.simulation.dt_min;
cfg.simulation.tvec_min = (0:cfg.simulation.Tsteps - 1)' * cfg.simulation.dt_min;
cfg.feeder.num_households = 5;
cfg.feeder.households_per_zone = [1 1 1 1 1];
cfg.output_dir = fullfile(cfg.output_dir, 'test_phase2');
cfg.figs_dir = fullfile(cfg.output_dir, 'figures');
cfg.tables_dir = fullfile(cfg.output_dir, 'tables');
if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figs_dir, 'dir'), mkdir(cfg.figs_dir); end
if ~exist(cfg.tables_dir, 'dir'), mkdir(cfg.tables_dir); end
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase2_load_model:assertionFailed', message);
end
end

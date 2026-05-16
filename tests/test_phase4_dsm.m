function test_phase4_dsm()
% TEST_PHASE4_DSM End-to-end smoke test for Phase 4 DSM controller.
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
%   test_phase4_dsm()

fprintf('\n[test_phase4_dsm] Starting Phase 4 end-to-end DSM smoke test...\n');

cfg = make_one_day_cfg(config_loader());
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

steps = 24 * 60 / cfg.simulation.dt_min;
price = 0.50 * ones(steps, 1);
price(18 * 60 / cfg.simulation.dt_min : 22 * 60 / cfg.simulation.dt_min) = 1.25;
weatherDay = 38 * ones(steps, 1);
calDay.daytype = uint8(0);
calDay.season = categorical("summer");
calDay.is_ramadan = false;

% Use a small subset to keep validation fast.
H = 6;
hhCells = cell(H, 1);
for h = 1:H
    hhCells{h} = simulate_household(h, assignment, data, weatherDay, calDay, cfg);
    if hhCells{h}.flexibility.count == 0
        hhCells{h}.flexibility.appliance = {'Washing_Machine'};
        hhCells{h}.flexibility.preferred_start_step = 70;
        hhCells{h}.flexibility.earliest_start_step = 60;
        hhCells{h}.flexibility.latest_start_step = 80;
        hhCells{h}.flexibility.duration_steps = 4;
        hhCells{h}.flexibility.power_w = 900;
        hhCells{h}.flexibility.max_shift_steps = 10;
        hhCells{h}.flexibility.count = 1;
    end
end

s = run_household_milp(hhCells{1}, price, cfg);
assert_pass(numel(s.p_total_w) == steps, sprintf('Household DSM schedule has %d steps', steps));
assert_pass(isfield(s, 'comfort_idx') && s.comfort_idx >= 0 && s.comfort_idx <= 1, ...
    sprintf('Comfort index in [0,1]: %.3f', s.comfort_idx));
assert_pass(all(isfinite(s.p_total_w)) && all(s.p_total_w >= -1e-6), 'Household DSM total power finite and nonnegative');

supervisor = feeder_supervisor(cfg, net, assignment, hhCells, price);
assert_pass(isfield(supervisor, 'schedules') && numel(supervisor.schedules) == H, ...
    sprintf('Feeder supervisor returned %d household schedules', H));
assert_pass(size(supervisor.L_house_w, 1) == steps && size(supervisor.L_house_w, 2) == H, ...
    sprintf('Supervisor L_house_w shape is %d x %d', size(supervisor.L_house_w, 1), size(supervisor.L_house_w, 2)));
assert_pass(isfield(supervisor.pq_summary, 'max_vuf_pct') && isfinite(supervisor.pq_summary.max_vuf_pct), ...
    sprintf('Supervisor PQ summary finite: max VUF %.3f%%', supervisor.pq_summary.max_vuf_pct));
assert_pass(supervisor.comfort_summary.mean >= 0 && supervisor.comfort_summary.mean <= 1, ...
    sprintf('Supervisor mean comfort in [0,1]: %.3f', supervisor.comfort_summary.mean));

fprintf('[test_phase4_dsm] Complete. Phase 4 smoke test passed.\n');
end

function cfg = make_one_day_cfg(cfg)
cfg.simulation.start_date = '2025-07-07';
cfg.simulation.end_date = '2025-07-08';
cfg.simulation.d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.d2 = datetime(cfg.simulation.end_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.horizon_days = days(cfg.simulation.d2 - cfg.simulation.d1);
cfg.simulation.dt_hr = cfg.simulation.dt_min / 60;
cfg.simulation.Tsteps = cfg.simulation.horizon_days * 24 * 60 / cfg.simulation.dt_min;
cfg.simulation.tvec_min = (0:cfg.simulation.Tsteps - 1)' * cfg.simulation.dt_min;
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase4_dsm:assertionFailed', '%s', message);
end
end

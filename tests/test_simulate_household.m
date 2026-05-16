function test_simulate_household()
% TEST_SIMULATE_HOUSEHOLD Validate single-household Phase 2 orchestration.
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
%   test_simulate_household()

fprintf('\n[test_simulate_household] Starting household simulation tests...\n');
cfg = make_one_day_cfg(config_loader());
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

acRows = find(logical(data.hvac.AC_Present) & double(data.hvac.AC_Units_Count) > 0, 1, 'first');
if isempty(acRows)
    acRows = 1;
end
assignment.survey_row(1) = acRows;
assignment.has_ev(1) = true;
assignment.charger_type{1} = 'slow';
assignment.ev_battery_kwh(1) = 60;

steps = 24 * 60 / cfg.simulation.dt_min;
weatherDay = 42 * ones(steps, 1);
calDay.daytype = uint8(0);
calDay.season = categorical("summer");
calDay.is_ramadan = false;

rng(31, 'twister');
hh = simulate_household(1, assignment, data, weatherDay, calDay, cfg);
dailyKwh = sum(hh.p_total_w) * cfg.simulation.dt_hr / 1000;
hvacKwh = sum(hh.p_hvac_w) * cfg.simulation.dt_hr / 1000;
assert_pass(numel(hh.p_total_w) == steps, sprintf('p_total length = %d steps', steps));
assert_pass(all(hh.p_total_w >= 0) && all(isfinite(hh.p_total_w)), 'Total power is finite and nonnegative');
assert_pass(dailyKwh >= 2 && dailyKwh <= 60, sprintf('Daily energy plausible for hot Egyptian day: %.2f kWh', dailyKwh));
assert_pass(max(abs(hh.p_total_w - (hh.p_fixed_w + hh.p_controllable_w))) < 1e-6, 'Power balance p_total = p_fixed + p_controllable');
assert_pass(hvacKwh > 0, sprintf('HVAC contributes energy on 42 C day: %.2f kWh', hvacKwh));
assert_pass(hvacKwh >= 0.25 * dailyKwh, sprintf('HVAC is dominant/significant in summer: %.1f%% of daily energy', 100 * hvacKwh / max(dailyKwh, eps)));
assert_pass(isfield(hh.ev, 'available_steps'), 'EV model attached to household output');
assert_pass(isfield(hh.flexibility, 'count'), sprintf('Flexibility struct exists with %d controllable runs', hh.flexibility.count));
fprintf('[test_simulate_household] Complete.\n');
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
    error('test_simulate_household:assertionFailed', message);
end
end

function test_simulate_occupancy()
% TEST_SIMULATE_OCCUPANCY Validate Phase 2 occupancy generation.
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
%   test_simulate_occupancy()

fprintf('\n[test_simulate_occupancy] Starting occupancy model tests...\n');
cfg = make_one_day_cfg(config_loader());
data = data_loader(cfg);
hhId = string(data.household.Household_ID(1));
occRows = data.occ_pmf(string(data.occ_pmf.Household_ID) == hhId, :);
calDay.daytype = uint8(0);
calDay.season = categorical("summer");
calDay.is_ramadan = false;

rng(11, 'twister');
O = simulate_occupancy(occRows, calDay, cfg);
steps = 24 * 60 / cfg.simulation.dt_min;
assert_pass(numel(O) == steps, sprintf('Occupancy length = %d steps', numel(O)));
assert_pass(all(ismember(double(O), [0 1 2])), 'Occupancy states are only 0/1/2');
assert_pass(any(O == 1), 'At least one home-awake step exists');
assert_pass(any(O == 2), 'At least one asleep step exists');

calDay.is_ramadan = true;
Or = simulate_occupancy(occRows, calDay, cfg);
assert_pass(numel(Or) == steps, 'Ramadan occupancy length is valid');
assert_pass(all(ismember(double(Or), [0 1 2])), 'Ramadan occupancy states are valid');
fprintf('[test_simulate_occupancy] Complete.\n');
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
    error('test_simulate_occupancy:assertionFailed', message);
end
end

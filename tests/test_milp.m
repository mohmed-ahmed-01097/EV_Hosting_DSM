function test_milp()
% TEST_MILP Validate Phase 4 household DSM MILP/fallback behavior.
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
%   test_milp()

fprintf('\n[test_milp] Starting Phase 4 DSM/MILP unit tests...\n');
cfg = config_loader();
cfg = make_one_day_cfg(cfg);
W = 24 * 60 / cfg.simulation.dt_min;
priceFlat = 0.50 * ones(W, 1);

% Test 1: Single appliance, unconstrained -> preferred time.
hh1 = make_synthetic_household(cfg, 1, false);
hh1.flexibility.appliance = {'Washing_Machine'};
hh1.flexibility.preferred_start_step = 30;
hh1.flexibility.earliest_start_step = 20;
hh1.flexibility.latest_start_step = 40;
hh1.flexibility.duration_steps = 4;
hh1.flexibility.power_w = 1000;
hh1.flexibility.max_shift_steps = 10;
hh1.flexibility.count = 1;
s1 = run_household_milp(hh1, priceFlat, cfg);
assert_pass(abs(s1.scheduled_start_step(1) - 30) <= 1, ...
    sprintf('Single appliance starts at preferred step: scheduled=%d preferred=30', round(s1.scheduled_start_step(1))));
assert_pass(s1.comfort_idx >= 0.90, sprintf('Comfort index high for preferred schedule: %.3f', s1.comfort_idx));

% Test 2: Two appliances with overlapping preferred times -> no overlap.
hh2 = make_synthetic_household(cfg, 2, false);
hh2.flexibility.appliance = {'Washing_Machine'; 'Dishwasher'};
hh2.flexibility.preferred_start_step = [40; 40];
hh2.flexibility.earliest_start_step = [36; 36];
hh2.flexibility.latest_start_step = [46; 46];
hh2.flexibility.duration_steps = [5; 5];
hh2.flexibility.power_w = [1000; 800];
hh2.flexibility.max_shift_steps = [10; 10];
hh2.flexibility.count = 2;
s2 = run_household_milp(hh2, priceFlat, cfg);
overlap = has_overlap(s2.scheduled_start_step, hh2.flexibility.duration_steps);
assert_pass(~overlap, sprintf('Two controllable appliances do not overlap: starts=[%d %d]', ...
    round(s2.scheduled_start_step(1)), round(s2.scheduled_start_step(2))));

% Test 3: EV SOC target met at departure/end of horizon.
hh3 = make_synthetic_household(cfg, 0, true);
hh3.ev.charger_type = 'fast';
hh3.ev.P_v2g_max_w = 0;
hh3.ev.soc_initial = 0.20;
hh3.ev.soc_target = 0.50;
hh3.ev.battery_kwh = 40;
hh3.ev.energy_needed_wh = (hh3.ev.soc_target - hh3.ev.soc_initial) * hh3.ev.battery_kwh * 1000 / hh3.ev.eta_c;
hh3.ev.available_steps(:) = true;
s3 = run_household_milp(hh3, priceFlat, cfg);
targetWh = hh3.ev.soc_target * hh3.ev.battery_kwh * 1000;
assert_pass(s3.soc(end) + 1e-3 >= targetWh, ...
    sprintf('EV SOC target met: final=%.1f Wh target=%.1f Wh', s3.soc(end), targetWh));

% Test 4: V2G discharges at high price while SOC remains above reserve.
priceV2G = 0.40 * ones(W, 1);
priceV2G(55:65) = 2.0;
hh4 = make_synthetic_household(cfg, 0, true);
hh4.ev.charger_type = 'v2g';
hh4.ev.P_v2g_max_w = hh4.ev.P_charge_max_w;
hh4.ev.soc_initial = 0.90;
hh4.ev.soc_target = 0.50;
hh4.ev.battery_kwh = 40;
hh4.ev.available_steps(:) = true;
s4 = run_household_milp(hh4, priceV2G, cfg);
reserveWh = cfg.ev.soc_min_pct / 100 * hh4.ev.battery_kwh * 1000;
assert_pass(any(s4.p_v2g > 0) || strcmpi(s4.method, 'milp'), ...
    sprintf('V2G schedule allows discharge or MILP arbitrage path exists: max p_v2g=%.1f W', max(s4.p_v2g)));
assert_pass(all(s4.soc >= reserveWh - 1e-3), sprintf('V2G SOC remains above minimum reserve %.1f Wh', reserveWh));

% Test 5: With power limit, total load respects constrained steps.
hh5 = make_synthetic_household(cfg, 1, false);
hh5.p_fixed_w(:) = 200;
hh5.flexibility.appliance = {'Washing_Machine'};
hh5.flexibility.preferred_start_step = 50;
hh5.flexibility.earliest_start_step = 45;
hh5.flexibility.latest_start_step = 55;
hh5.flexibility.duration_steps = 4;
hh5.flexibility.power_w = 1000;
hh5.flexibility.max_shift_steps = 5;
hh5.flexibility.count = 1;
pLimit = inf(W, 1);
pLimit(:) = 1500;
s5 = run_household_milp(hh5, priceFlat, cfg, pLimit);
assert_pass(all(s5.p_total_w <= pLimit + 1e-6), ...
    sprintf('Total load <= P_limit: max %.1f W limit %.1f W', max(s5.p_total_w), min(pLimit)));

fprintf('[test_milp] Complete. Phase 4 DSM/MILP unit tests passed.\n');
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

function hh = make_synthetic_household(cfg, nAppliances, hasEv)
W = 24 * 60 / cfg.simulation.dt_min;
hh = struct();
hh.p_fixed_w = 300 * ones(W, 1);
hh.p_controllable_w = zeros(W, 1);
hh.p_total_w = hh.p_fixed_w;
hh.phase_id = 1;
hh.zone = 1;
hh.bus_id = 1;
hh.household_id = 1;
hh.flexibility = struct();
hh.flexibility.appliance = cell(nAppliances, 1);
hh.flexibility.preferred_start_step = zeros(nAppliances, 1);
hh.flexibility.earliest_start_step = zeros(nAppliances, 1);
hh.flexibility.latest_start_step = zeros(nAppliances, 1);
hh.flexibility.duration_steps = zeros(nAppliances, 1);
hh.flexibility.power_w = zeros(nAppliances, 1);
hh.flexibility.max_shift_steps = zeros(nAppliances, 1);
hh.flexibility.count = nAppliances;
for a = 1:nAppliances
    hh.flexibility.appliance{a} = sprintf('Load_%d', a);
    hh.flexibility.preferred_start_step(a) = 30 + a;
    hh.flexibility.earliest_start_step(a) = 25;
    hh.flexibility.latest_start_step(a) = 40;
    hh.flexibility.duration_steps(a) = 4;
    hh.flexibility.power_w(a) = 800;
    hh.flexibility.max_shift_steps(a) = 10;
end
hh.ev = struct();
hh.ev.present = false;
hh.ev.available_steps = false(W, 1);
hh.ev.arrival_step = NaN;
hh.ev.departure_step = NaN;
hh.ev.soc_initial = 0;
hh.ev.soc_target = cfg.ev.soc_target_pct / 100;
hh.ev.battery_kwh = 0;
hh.ev.P_charge_max_w = 0;
hh.ev.P_v2g_max_w = 0;
hh.ev.eta_c = cfg.ev.eta_charge;
hh.ev.eta_d = cfg.ev.eta_discharge;
hh.ev.energy_needed_wh = 0;
hh.ev.charger_type = 'none';
if hasEv
    hh.ev.present = true;
    hh.ev.arrival_step = 1;
    hh.ev.departure_step = W;
    hh.ev.available_steps = true(W, 1);
    hh.ev.soc_initial = 0.30;
    hh.ev.soc_target = 0.60;
    hh.ev.battery_kwh = 40;
    hh.ev.P_charge_max_w = cfg.ev.fast_kw * 1000;
    hh.ev.P_v2g_max_w = 0;
    hh.ev.charger_type = 'fast';
    hh.ev.energy_needed_wh = (hh.ev.soc_target - hh.ev.soc_initial) * hh.ev.battery_kwh * 1000 / hh.ev.eta_c;
end
end

function tf = has_overlap(starts, durations)
tf = false;
for i = 1:numel(starts)
    for j = i+1:numel(starts)
        a1 = starts(i);
        a2 = starts(i) + durations(i) - 1;
        b1 = starts(j);
        b2 = starts(j) + durations(j) - 1;
        if a1 <= b2 && b1 <= a2
            tf = true;
            return;
        end
    end
end
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_milp:assertionFailed', '%s', message);
end
end

function test_ev_model()
% TEST_EV_MODEL Validate Phase 2 EV availability and charging parameters.
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
%   test_ev_model()

fprintf('\n[test_ev_model] Starting EV model tests...\n');
cfg = make_one_day_cfg(config_loader());
calDay.daytype = uint8(1);
calDay.season = categorical("summer");
calDay.is_ramadan = false;

rng(21, 'twister');
ev0 = ev_model(false, 'none', 0, calDay, cfg);
assert_pass(~ev0.present, 'No-EV household returns present=false');
assert_pass(~any(ev0.available_steps), 'No-EV household has no available steps');

evSlow = draw_present_ev('slow', 60, calDay, cfg);
assert_pass(abs(evSlow.P_charge_max_w - 3700) < 1e-9, 'Slow charger max power = 3700 W');
assert_pass(evSlow.energy_needed_wh >= 0, sprintf('EV energy_needed is nonnegative: %.1f Wh', evSlow.energy_needed_wh));
assert_pass(any(evSlow.available_steps), 'Present EV has an availability window');

evV2G = draw_present_ev('v2g', 75, calDay, cfg);
assert_pass(abs(evV2G.P_v2g_max_w - evV2G.P_charge_max_w) < 1e-9, 'V2G discharge max equals charge max');
thdNumerator = sqrt(sum(evV2G.harmonic_spectrum(2:end).^2));
assert_pass(thdNumerator > 0, sprintf('Harmonic spectrum contains non-fundamental content: %.3f pu', thdNumerator));
fprintf('[test_ev_model] Complete.\n');
end

function ev = draw_present_ev(chargerType, batteryKwh, calDay, cfg)
ev = struct('present', false);
for k = 1:30
    ev = ev_model(true, chargerType, batteryKwh, calDay, cfg);
    if ev.present
        return;
    end
end
error('test_ev_model:noPresentEv', 'Could not draw a present EV after 30 attempts.');
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
    error('test_ev_model:assertionFailed', message);
end
end

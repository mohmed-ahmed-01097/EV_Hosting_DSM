function test_phase3_pricing()
% TEST_PHASE3_PRICING  End-to-end Phase 3 pricing smoke test.
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
%   test_phase3_pricing()

fprintf('\n[test_phase3_pricing] Starting Phase 3 end-to-end smoke test...\n');

cfg = config_loader();
cal_struct = daytype_calendar(cfg);
T = min(7 * 24 * 60 / cfg.simulation.dt_min, cfg.simulation.Tsteps);
tvec = cfg.simulation.tvec_min(1:T);

% Three synthetic households for one week.
hour = mod(tvec / 60, 24);
baseProfile = 450 + 250 * (hour >= 18 & hour <= 23) + 150 * (hour >= 7 & hour <= 9);
L_house_w = [baseProfile, 1.2 * baseProfile, 1.5 * baseProfile];

costs = compute_costs(cfg, L_house_w, tvec, cal_struct);

requiredFields = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
for i = 1:numel(requiredFields)
    fn = requiredFields{i};
    assert_pass(isfield(costs.bill_total, fn), sprintf('bill_total.%s exists', fn));
    assert_pass(numel(costs.bill_total.(fn)) == 3, sprintf('bill_total.%s has 3 household bills', fn));
    assert_pass(all(isfinite(costs.bill_total.(fn))), sprintf('bill_total.%s is finite', fn));
end

assert_pass(all(costs.bill_total.Flat > 0), sprintf('Flat total bills positive: min %.2f EGP', min(costs.bill_total.Flat)));
assert_pass(all(costs.bill_total.RGDP > costs.bill_total.Flat), ...
    sprintf('RGDP includes demand charge: min RGDP %.2f EGP vs min Flat %.2f EGP', min(costs.bill_total.RGDP), min(costs.bill_total.Flat)));
assert_pass(all(isfinite(costs.price_series.TOU)) && numel(costs.price_series.TOU) == T, ...
    sprintf('TOU price series valid for %d steps', T));

fprintf('[test_phase3_pricing] Complete. Phase 3 smoke test passed.\n');
end

function assert_pass(condition, message)
% ASSERT_PASS  Print PASS/FAIL and throw on failure.
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase3_pricing:assertionFailed', '%s', message);
end
end

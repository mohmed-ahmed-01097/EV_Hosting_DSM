function test_pricing()
% TEST_PRICING  Validate Phase 3 pricing engine and block tariff logic.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None.
%
% Outputs:
%   Prints PASS/FAIL assertions with quantitative values.
%
% Example:
%   test_pricing()

fprintf('\n[test_pricing] Starting Phase 3 pricing validation...\n');

cfg = config_loader();
T30 = 30 * 24 * 60 / cfg.simulation.dt_min;
tvec30 = (0:T30-1)' * cfg.simulation.dt_min;

% --- Test 1: Egyptian block tariff exact examples ---
b0 = pricing_block(cfg, tvec30, 0, 30);
assert_pass(abs(b0.bill_egp - 0) < 1e-9, sprintf('Block tariff 0 kWh = %.2f EGP', b0.bill_egp));

b50 = pricing_block(cfg, tvec30, 50, 30);
assert_pass(abs(b50.bill_egp - 12.5) < 1e-9, sprintf('Block tariff 50 kWh = %.2f EGP', b50.bill_egp));

b110 = pricing_block(cfg, tvec30, 110, 30);
assert_pass(abs(b110.bill_egp - 41.5) < 1e-9, sprintf('Block tariff 110 kWh = %.2f EGP', b110.bill_egp));
assert_pass(b110.slab_reached == 3, sprintf('Block tariff 110 kWh reaches slab %d', b110.slab_reached));

% --- Test 2: All seven pricing methods dispatch correctly ---
methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
for i = 1:numel(methods)
    price = select_pricing(methods{i}, cfg, tvec30, 110);
    if strcmpi(methods{i}, 'Block')
        assert_pass(isstruct(price) && numel(price.price_series) == T30, ...
            sprintf('%s returns block struct with %d price steps', methods{i}, numel(price.price_series)));
    else
        assert_pass(isnumeric(price) && numel(price) == T30 && all(isfinite(price)) && all(price > 0), ...
            sprintf('%s returns valid vector with %d price steps', methods{i}, numel(price)));
    end
end

% --- Test 3: Dynamic tariff behavior is meaningful ---
pTou = pricing_tou(cfg, tvec30);
pSeasonal = pricing_seasonal(cfg, tvec30);
pRtp = pricing_rtp(cfg, tvec30);
pCpp = pricing_cpp(cfg, tvec30);
pRgdp = pricing_rgdp(cfg, tvec30);

assert_pass((max(pTou) - min(pTou)) > 0, sprintf('TOU has time variation: range %.3f EGP/kWh', (max(pTou) - min(pTou))));
assert_pass(all(pSeasonal > 0), sprintf('Seasonal prices positive: min %.3f EGP/kWh', min(pSeasonal)));
assert_pass((max(pRtp) - min(pRtp)) > 0.05, sprintf('RTP has dynamic variation: range %.3f EGP/kWh', (max(pRtp) - min(pRtp))));
assert_pass(max(pCpp) >= max(pTou) + cfg.pricing.cpp_adder_egp_per_kwh - 1e-9 || max(pCpp) >= max(pTou), ...
    sprintf('CPP maximum %.3f EGP/kWh is at least TOU maximum %.3f EGP/kWh', max(pCpp), max(pTou)));
assert_pass((max(pRgdp) - min(pRgdp)) > 0.05, sprintf('RGDP has renewable-linked variation: range %.3f EGP/kWh', (max(pRgdp) - min(pRgdp))));

% --- Test 4: compute_costs exact block comparison with EV-like increment ---
% 30-day constant energy: 90 kWh baseline and 140 kWh with EV charging.
L_no_ev_w = (90 / (30 * 24)) * 1000 * ones(T30, 1);
L_with_ev_w = (140 / (30 * 24)) * 1000 * ones(T30, 1);
L_house_w = [L_no_ev_w, L_with_ev_w];

costs = compute_costs(cfg, L_house_w, tvec30);
baseBill = costs.bill_total.Block(1);
evBill = costs.bill_total.Block(2);
increment = evBill - baseBill;

assert_pass(abs(baseBill - 30.5) < 1e-6, sprintf('Block bill for 90 kWh = %.2f EGP', baseBill));
assert_pass(abs(evBill - 61.0) < 1e-6, sprintf('Block bill for 140 kWh = %.2f EGP', evBill));
assert_pass(increment >= 30 && increment <= 50, sprintf('EV-like block increment = %.2f EGP/month', increment));
assert_pass(numel(costs.methods) == 7, sprintf('compute_costs produced %d tariff methods', numel(costs.methods)));
assert_pass(size(costs.energy_monthly_kwh, 1) == 2 && size(costs.energy_monthly_kwh, 2) == 1, ...
    sprintf('Monthly energy matrix size = %dx%d', size(costs.energy_monthly_kwh, 1), size(costs.energy_monthly_kwh, 2)));

fprintf('[test_pricing] Complete. Phase 3 pricing validation passed.\n');
end

function assert_pass(condition, message)
% ASSERT_PASS  Print PASS/FAIL and throw on failure.
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_pricing:assertionFailed', '%s', message);
end
end

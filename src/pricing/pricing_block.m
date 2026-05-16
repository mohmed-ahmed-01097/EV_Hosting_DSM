function block = pricing_block(cfg, tvec_min, monthly_kwh, period_days)
% PRICING_BLOCK  Compute Egyptian inclining block tariff billing.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg         (struct) - configuration with block slabs and rates.
%   tvec_min    (T x 1 double, optional) - time vector in minutes.
%   monthly_kwh (scalar double, optional) - period energy consumption [kWh].
%   period_days (scalar double, optional) - represented period length in days.
%
% Outputs:
%   block (struct) with fields:
%     price_series          (T x 1 double) - representative marginal price [EGP/kWh].
%     bill_egp              (scalar double) - inclining block bill [EGP].
%     energy_kwh            (scalar double) - billed energy [kWh].
%     slab_reached          (scalar integer) - highest reached tariff slab.
%     effective_rate_egp_kwh(scalar double) - bill divided by energy.
%     marginal_rate_egp_kwh (scalar double) - rate at final slab.
%     prorated_slabs_kwh    (1 x N double) - slab upper bounds after proration.
%     rates_egp             (1 x N+1 double) - slab rates [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   b = pricing_block(cfg, (0:95)'*15, 110, 30);
%
% Notes:
%   Slab boundaries are monthly by default. For sub-monthly periods, boundaries
%   are prorated by period_days / 30.

% --- Section 1: Defaults and validation ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3 || isempty(monthly_kwh)
    monthly_kwh = 0;
end
if nargin < 4 || isempty(period_days)
    period_days = 30;
end

tvec_min = tvec_min(:);
validateattributes(monthly_kwh, {'numeric'}, {'scalar', 'nonnegative', 'finite'}, mfilename, 'monthly_kwh');
validateattributes(period_days, {'numeric'}, {'scalar', 'positive', 'finite'}, mfilename, 'period_days');

slabs = cfg.pricing.block_slabs_kwh(:)';
rates = cfg.pricing.block_rates_egp(:)';
if numel(rates) ~= numel(slabs) + 1
    error('pricing_block:invalidConfig', 'block_rates_egp must have one more value than block_slabs_kwh.');
end

% --- Section 2: Prorate slab boundaries and compute bill ---
scale = period_days / 30;
proratedSlabs = slabs * scale;
[bill, slabReached, marginalRate] = local_block_bill(monthly_kwh, proratedSlabs, rates);

% --- Section 3: Build representative price vector ---
if monthly_kwh > 0
    effectiveRate = bill / monthly_kwh;
else
    effectiveRate = rates(1);
end

block.price_series = marginalRate * ones(numel(tvec_min), 1);
block.bill_egp = bill;
block.energy_kwh = monthly_kwh;
block.slab_reached = slabReached;
block.effective_rate_egp_kwh = effectiveRate;
block.marginal_rate_egp_kwh = marginalRate;
block.prorated_slabs_kwh = proratedSlabs;
block.rates_egp = rates;
end

function [bill, slabReached, marginalRate] = local_block_bill(energyKwh, slabs, rates)
% LOCAL_BLOCK_BILL  Marginal inclining block bill helper.

bill = 0;
remaining = energyKwh;
prevUpper = 0;
slabReached = 1;

for k = 1:numel(rates)
    if k <= numel(slabs)
        upper = slabs(k);
    else
        upper = Inf;
    end

    width = min(remaining, upper - prevUpper);
    if width > 0
        bill = bill + width * rates(k);
        remaining = remaining - width;
        slabReached = k;
    end

    prevUpper = upper;
    if remaining <= 1e-12
        break;
    end
end

marginalRate = rates(slabReached);
end

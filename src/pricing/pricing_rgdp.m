function price_series = pricing_rgdp(cfg, tvec_min, cal_struct)
% PRICING_RGDP  Return renewable-generation-based dynamic pricing series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - configuration with renewable fractions.
%   tvec_min   (T x 1 double) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct.
%
% Outputs:
%   price_series (T x 1 double) - RGDP energy price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_rgdp(cfg, cfg.simulation.tvec_min);
%
% Notes:
%   The demand-charge component for RGDP is added in compute_costs because it
%   depends on each household's daily peak demand.

% --- Section 1: Context and base price ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3
    cal_struct = [];
end
ctx = build_pricing_context(cfg, tvec_min, cal_struct);
T = numel(tvec_min);

basePrice = cfg.pricing.rtp_base_egp;
h = ctx.hour_of_day;

% --- Section 2: Renewable availability proxy ---
solarShape = sin(pi * max(0, min(1, (h - 6) / 12))).^2;
solarShape(h < 6 | h > 18) = 0;

seasonText = cellstr(ctx.season);
isSummer = strcmpi(seasonText, 'summer');
isWinter = strcmpi(seasonText, 'winter');
renewableFraction = 0.15 * ones(T, 1);
renewableFraction(isSummer) = cfg.pricing.rgdp_renewable_fraction_summer;
renewableFraction(isWinter) = cfg.pricing.rgdp_renewable_fraction_winter;
renewableAvailability = renewableFraction .* solarShape;

% --- Section 3: Price rule ---
eveningScarcity = exp(-0.5 * ((h - 20) / 2.3).^2);
price_series = basePrice .* (1 - 1.25 * renewableAvailability + 0.28 * eveningScarcity);
price_series = max(0.12, min(2.20, price_series));
end

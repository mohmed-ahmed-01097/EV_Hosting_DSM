function price_series = pricing_seasonal(cfg, tvec_min, cal_struct)
% PRICING_SEASONAL  Return seasonal TOU tariff series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - configuration with TOU rates and seasonal multipliers.
%   tvec_min   (T x 1 double) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct.
%
% Outputs:
%   price_series (T x 1 double) - seasonal price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_seasonal(cfg, cfg.simulation.tvec_min);

% --- Section 1: Base TOU price ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3
    cal_struct = [];
end
ctx = build_pricing_context(cfg, tvec_min, cal_struct);
price_series = pricing_tou(cfg, tvec_min, cal_struct);

% --- Section 2: Seasonal multipliers ---
seasonText = cellstr(ctx.season);
isSummer = strcmpi(seasonText, 'summer');
isWinter = strcmpi(seasonText, 'winter');

price_series(isSummer) = price_series(isSummer) * cfg.pricing.seasonal_summer_multiplier;
price_series(isWinter) = price_series(isWinter) * cfg.pricing.seasonal_winter_multiplier;
end

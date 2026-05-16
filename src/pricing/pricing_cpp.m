function price_series = pricing_cpp(cfg, tvec_min, cal_struct)
% PRICING_CPP  Return critical peak pricing series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - configuration with TOU rates and CPP adder.
%   tvec_min   (T x 1 double) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct.
%
% Outputs:
%   price_series (T x 1 double) - CPP price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_cpp(cfg, cfg.simulation.tvec_min);

% --- Section 1: Base tariff and context ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3
    cal_struct = [];
end
ctx = build_pricing_context(cfg, tvec_min, cal_struct);
price_series = pricing_tou(cfg, tvec_min, cal_struct);

% --- Section 2: Critical peak event rule ---
% Thesis assumption: critical events occur on hot summer non-holiday evenings.
seasonText = cellstr(ctx.season);
isSummer = strcmpi(seasonText, 'summer');
isEveningStress = ctx.hour_of_day >= 18 & ctx.hour_of_day < 22;
isBusinessLikeDay = ctx.daytype == 0;

cppEvent = isSummer & isEveningStress & isBusinessLikeDay;
price_series(cppEvent) = price_series(cppEvent) + cfg.pricing.cpp_adder_egp_per_kwh;
end

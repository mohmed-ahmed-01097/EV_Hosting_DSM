function price_series = pricing_tou(cfg, tvec_min, cal_struct)
% PRICING_TOU  Return 24-hour time-of-use tariff series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - configuration with pricing.tou_rates_24h.
%   tvec_min   (T x 1 double) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct.
%
% Outputs:
%   price_series (T x 1 double) - TOU price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_tou(cfg, cfg.simulation.tvec_min);

% --- Section 1: Context and validation ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3
    cal_struct = [];
end
ctx = build_pricing_context(cfg, tvec_min, cal_struct);

rates = cfg.pricing.tou_rates_24h(:);
if numel(rates) ~= 24
    error('pricing_tou:invalidRates', 'pricing.tou_rates_24h must contain exactly 24 values.');
end

% --- Section 2: Hourly lookup ---
price_series = rates(ctx.hour_index);
end

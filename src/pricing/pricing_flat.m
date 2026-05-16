function price_series = pricing_flat(cfg, tvec_min)
% PRICING_FLAT  Return a flat electricity price series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg      (struct) - configuration with pricing.flat_rate_egp_per_kwh.
%   tvec_min (T x 1 double, optional) - time vector in minutes.
%
% Outputs:
%   price_series (T x 1 double) - flat price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_flat(cfg, cfg.simulation.tvec_min);

% --- Section 1: Determine output length ---
if nargin < 2 || isempty(tvec_min)
    T = cfg.simulation.Tsteps;
else
    T = numel(tvec_min);
end

% --- Section 2: Constant tariff ---
price_series = cfg.pricing.flat_rate_egp_per_kwh * ones(T, 1);
end

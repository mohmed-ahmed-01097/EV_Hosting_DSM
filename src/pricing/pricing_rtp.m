function price_series = pricing_rtp(cfg, tvec_min, cal_struct)
% PRICING_RTP  Return deterministic real-time pricing series.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - configuration with RTP base and volatility.
%   tvec_min   (T x 1 double) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct.
%
% Outputs:
%   price_series (T x 1 double) - RTP price [EGP/kWh].
%
% Example:
%   cfg = config_loader();
%   p = pricing_rtp(cfg, cfg.simulation.tvec_min);
%
% Notes:
%   This implementation is intentionally deterministic for reproducible thesis
%   simulations. It combines a daily load-shape component, seasonal stress, and
%   a seeded low-frequency stochastic component.

% --- Section 1: Context and constants ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 3
    cal_struct = [];
end
ctx = build_pricing_context(cfg, tvec_min, cal_struct);
T = numel(tvec_min);

basePrice = cfg.pricing.rtp_base_egp;
volatility = cfg.pricing.rtp_volatility;

% --- Section 2: Deterministic daily and seasonal shape ---
h = ctx.hour_of_day;
eveningPeak = exp(-0.5 * ((h - 20) / 2.5).^2);
morningPeak = 0.55 * exp(-0.5 * ((h - 8) / 2.0).^2);
middayDip = 0.20 * exp(-0.5 * ((h - 13) / 3.0).^2);
shape = 0.25 * eveningPeak + 0.12 * morningPeak - middayDip;

seasonText = cellstr(ctx.season);
isSummer = strcmpi(seasonText, 'summer');
isWinter = strcmpi(seasonText, 'winter');
seasonAdder = zeros(T, 1);
seasonAdder(isSummer) = 0.16;
seasonAdder(isWinter) = -0.04;

% --- Section 3: Seeded low-frequency variation ---
oldState = rng;
rng(cfg.seed + 310, 'twister');
stepsPerHour = max(1, round(60 / cfg.simulation.dt_min));
numHours = ceil(T / stepsPerHour);
hourlyNoise = randn(numHours, 1);
window = ones(6, 1) / 6;
hourlyNoise = conv(hourlyNoise, window, 'same');
noise = repelem(hourlyNoise, stepsPerHour);
noise = noise(1:T);
rng(oldState);

price_series = basePrice * (1 + shape + seasonAdder + volatility * 0.25 * noise);

% --- Section 4: Safety bounds ---
price_series = max(0.15, min(2.50, price_series));
end

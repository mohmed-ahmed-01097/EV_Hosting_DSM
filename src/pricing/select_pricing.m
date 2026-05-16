function price_series = select_pricing(method, cfg, tvec_min, monthly_kwh, cal_struct)
% SELECT_PRICING  Dispatch to one of the seven supported pricing models.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   method      (char/string) - 'Flat','Block','TOU','RTP','Seasonal','CPP','RGDP'.
%   cfg         (struct) - project configuration.
%   tvec_min    (T x 1 double) - time vector in minutes.
%   monthly_kwh (scalar, optional) - needed for Block representative series.
%   cal_struct  (struct, optional) - calendar struct from daytype_calendar.
%
% Outputs:
%   price_series - normally a T x 1 double [EGP/kWh]. For Block, returns a
%                  struct from pricing_block with bill and slab metadata.
%
% Example:
%   cfg = config_loader();
%   p = select_pricing('TOU', cfg, cfg.simulation.tvec_min, 0);

% --- Section 1: Defaults ---
if nargin < 3 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 4 || isempty(monthly_kwh)
    monthly_kwh = 0;
end
if nargin < 5
    cal_struct = [];
end

if isstring(method)
    method = char(method);
end

% --- Section 2: Explicit dispatch ---
switch lower(strtrim(method))
    case 'flat'
        price_series = pricing_flat(cfg, tvec_min);
    case 'block'
        price_series = pricing_block(cfg, tvec_min, monthly_kwh, 30);
    case 'tou'
        price_series = pricing_tou(cfg, tvec_min, cal_struct);
    case 'rtp'
        price_series = pricing_rtp(cfg, tvec_min, cal_struct);
    case 'seasonal'
        price_series = pricing_seasonal(cfg, tvec_min, cal_struct);
    case 'cpp'
        price_series = pricing_cpp(cfg, tvec_min, cal_struct);
    case 'rgdp'
        price_series = pricing_rgdp(cfg, tvec_min, cal_struct);
    otherwise
        error('select_pricing:unknownMethod', 'Unknown pricing method: %s', method);
end
end

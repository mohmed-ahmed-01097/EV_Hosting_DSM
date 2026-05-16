function p_hvac = hvac_power_model(occ_seq, weather_day, hvac_hh, cal_day, cfg)
% HVAC_POWER_MODEL Compute one-day HVAC power for an Egyptian household.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   occ_seq (steps-by-1): Occupancy states where 0=away, 1=home-awake,
%       and 2=asleep.
%   weather_day (steps-by-1 double): Outdoor temperature [deg C].
%   hvac_hh (table): One HVAC_Thermal row for the household.
%   cal_day (struct): Day metadata with season.
%   cfg (struct): Project configuration.
%
% Outputs:
%   p_hvac (steps-by-1 double): HVAC active power [W].
%
% Example:
%   p_hvac = hvac_power_model(O, weather.temp_C(1:96), hvac_hh, cal_day, cfg);

% --- Section 1: Validate inputs and constants ---
validateattributes(occ_seq, {'numeric','logical'}, {'vector','nonempty'}, mfilename, 'occ_seq', 1);
validateattributes(weather_day, {'numeric'}, {'vector','numel', numel(occ_seq)}, mfilename, 'weather_day', 2);
validateattributes(hvac_hh, {'table'}, {}, mfilename, 'hvac_hh', 3);
validateattributes(cal_day, {'struct'}, {'scalar'}, mfilename, 'cal_day', 4);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 5);

N = numel(occ_seq);
p_hvac = zeros(N, 1);
if ~cfg.hvac.use || isempty(hvac_hh) || height(hvac_hh) < 1
    return;
end
if ~logical(hvac_hh.AC_Present(1))
    return;
end

thermalMassK = cfg.hvac.k_thermal_mass;
comfortBandC = cfg.hvac.delta_comfort_band_c;
season = get_season_string(cal_day);
if strcmpi(season, 'summer')
    baseSetpoint = double(hvac_hh.Summer_Setpoint_C(1));
elseif strcmpi(season, 'winter')
    baseSetpoint = double(hvac_hh.Winter_Setpoint_C(1));
else
    baseSetpoint = double(hvac_hh.Summer_Setpoint_C(1)) + 1.0;
end
if ~isfinite(baseSetpoint) || baseSetpoint <= 0
    baseSetpoint = cfg.hvac.summer_setpoint_c;
end

unitPowerW = double(hvac_hh.AC_Power_kW(1)) * 1000;
if ~isfinite(unitPowerW) || unitPowerW <= 0
    unitPowerW = cfg.hvac.power_per_unit_kw * 1000;
end
numUnits = max(0, double(hvac_hh.AC_Units_Count(1)));
pMax = unitPowerW * numUnits;

% --- Section 2: Piecewise duty-cycle calculation ---
for t = 1:N
    setpoint = baseSetpoint;
    if occ_seq(t) == 0
        setpoint = setpoint + 3.0;
    elseif occ_seq(t) == 2
        setpoint = setpoint + 1.0;
    end
    Tout = double(weather_day(t));
    if Tout <= setpoint
        duty = 0;
    elseif Tout >= setpoint + comfortBandC
        duty = 1;
    else
        duty = thermalMassK * (Tout - setpoint) / comfortBandC;
    end
    p_hvac(t) = pMax * min(1, max(0, duty));
end
end

function season = get_season_string(cal_day)
% GET_SEASON_STRING Normalize season value from char/string/categorical.
season = 'summer';
if isfield(cal_day, 'season')
    raw = cal_day.season;
    if iscategorical(raw)
        season = char(raw);
    else
        season = char(string(raw));
    end
end
end

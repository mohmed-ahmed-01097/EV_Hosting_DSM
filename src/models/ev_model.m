function ev = ev_model(has_ev, charger_type, battery_kwh, cal_day, cfg)
% EV_MODEL Generate one-day EV availability and charging parameters.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   has_ev (logical): Whether the household owns an EV.
%   charger_type (char/string): 'slow', 'fast', 'v2g', or 'none'.
%   battery_kwh (double): Battery capacity [kWh].
%   cal_day (struct): Day metadata. Weekend days slightly increase EV home
%       presence probability.
%   cfg (struct): Project configuration.
%
% Outputs:
%   ev (struct): EV availability, SOC, power limits, energy need, and
%       harmonic spectrum.
%
% Example:
%   ev = ev_model(true, 'slow', 60, cal_day, cfg);

% --- Section 1: Constants and default return ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 5);
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
emptyAvailable = false(stepsPerDay, 1);

ev = struct();
ev.present = false;
ev.arrival_step = NaN;
ev.departure_step = NaN;
ev.soc_initial = NaN;
ev.soc_target = cfg.ev.soc_target_pct / 100;
ev.battery_kwh = max(0, battery_kwh);
ev.P_charge_max_w = 0;
ev.P_v2g_max_w = 0;
ev.eta_c = cfg.ev.eta_charge;
ev.eta_d = cfg.ev.eta_discharge;
ev.available_steps = emptyAvailable;
ev.energy_needed_wh = 0;
ev.charger_type = char(lower(string(charger_type)));
ev.harmonic_spectrum = [1.0, 0.70, 0.40, 0.25, 0.15, 0.10, 0.08];
ev.harmonic_orders = [1, 3, 5, 7, 9, 11, 13];

if ~logical(has_ev) || strcmpi(ev.charger_type, 'none')
    return;
end
if ev.battery_kwh <= 0
    batteryOptions = cfg.ev.battery_kwh_options(:);
    ev.battery_kwh = batteryOptions(randi(numel(batteryOptions)));
end

% --- Section 2: Presence, arrival, and departure stochastic model ---
dayType = 0;
if isfield(cal_day, 'daytype')
    dayType = double(cal_day.daytype);
end
presenceProb = 0.90 + 0.05 * double(dayType > 0);
ev.present = rand() < presenceProb;
if ~ev.present
    return;
end

arrivalHr = cfg.ev.arrival_mean_hour + cfg.ev.arrival_std_hour * randn();
arrivalHr = max(15, min(23, arrivalHr));
ev.arrival_step = max(1, min(stepsPerDay, round(arrivalHr * 60 / cfg.simulation.dt_min) + 1));

departHr = cfg.ev.departure_mean_hour + cfg.ev.departure_std_hour * randn();
departHr = max(5, min(10, departHr));
ev.departure_step = max(1, round(departHr * 60 / cfg.simulation.dt_min) + 1);

% --- Section 3: SOC and power limits ---
ev.soc_initial = cfg.ev.soc_min_pct/100 + (0.60 - cfg.ev.soc_min_pct/100) * rand();
ev.soc_target = cfg.ev.soc_target_pct / 100;
ct = lower(ev.charger_type);
switch ct
    case 'slow'
        ev.P_charge_max_w = cfg.ev.slow_kw * 1000;
    case 'fast'
        ev.P_charge_max_w = cfg.ev.fast_kw * 1000;
    case 'v2g'
        ev.P_charge_max_w = cfg.ev.fast_kw * 1000;
    otherwise
        ev.P_charge_max_w = cfg.ev.slow_kw * 1000;
        ev.charger_type = 'slow';
end
if strcmpi(ev.charger_type, 'v2g') && cfg.ev.v2g_enabled
    ev.P_v2g_max_w = ev.P_charge_max_w;
end

ev.energy_needed_wh = max(0, (ev.soc_target - ev.soc_initial) * ev.battery_kwh * 1000 / ev.eta_c);

% --- Section 4: Availability vector and feasibility warning ---
ev.available_steps(ev.arrival_step:stepsPerDay) = true;
dtHr = cfg.simulation.dt_min / 60;
availableHr = (stepsPerDay - ev.arrival_step + 1 + ev.departure_step) * dtHr;
minChargeHr = ev.energy_needed_wh / max(ev.P_charge_max_w, 1e-9);
if minChargeHr > availableHr * 1.1
    warning('ev_model:insufficientChargeWindow', ...
        'Insufficient time to charge EV to target SOC (need %.1f h, have %.1f h).', ...
        minChargeHr, availableHr);
end
end

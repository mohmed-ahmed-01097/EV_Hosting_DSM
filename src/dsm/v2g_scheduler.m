function evSchedule = v2g_scheduler(ev, price_series, cfg, p_limit_w)
% V2G_SCHEDULER Heuristic EV charging and V2G scheduling.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   ev (struct): EV metadata from ev_model.
%   price_series (W x 1 double): Energy price [EGP/kWh].
%   cfg (struct): Project configuration.
%   p_limit_w (W x 1 double, optional): Available household power headroom [W].
%
% Outputs:
%   evSchedule (struct): p_ev, p_v2g, soc, energy_charged_wh,
%       energy_discharged_wh, and feasible flag.
%
% Example:
%   evs = v2g_scheduler(hh.ev, price, cfg);

% --- Section 1: Defaults and validation ---
validateattributes(ev, {'struct'}, {'scalar'}, mfilename, 'ev', 1);
validateattributes(price_series, {'numeric'}, {'vector','nonempty','finite'}, mfilename, 'price_series', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

W = numel(price_series);
price = double(price_series(:));
if nargin < 4 || isempty(p_limit_w)
    p_limit_w = inf(W, 1);
else
    p_limit_w = double(p_limit_w(:));
    if numel(p_limit_w) ~= W
        p_limit_w = repmat(p_limit_w(1), W, 1);
    end
end

dtHr = cfg.simulation.dt_min / 60;
evSchedule = struct();
evSchedule.p_ev = zeros(W, 1);
evSchedule.p_v2g = zeros(W, 1);
evSchedule.soc = zeros(W, 1);
evSchedule.energy_charged_wh = 0;
evSchedule.energy_discharged_wh = 0;
evSchedule.feasible = true;
evSchedule.note = 'no EV present';

if ~isfield(ev, 'present') || ~ev.present || ~isfield(ev, 'available_steps') || ~any(ev.available_steps)
    return;
end

% --- Section 2: Prepare EV state and availability ---
avail = logical(ev.available_steps(:));
if numel(avail) ~= W
    avail = resize_logical(avail, W);
end
socInitialWh = max(0, double(ev.soc_initial) * double(ev.battery_kwh) * 1000);
socTargetWh = max(0, double(ev.soc_target) * double(ev.battery_kwh) * 1000);
socMinWh = cfg.ev.soc_min_pct / 100 * double(ev.battery_kwh) * 1000;
socReserveWh = cfg.ev.soc_v2g_reserve_pct / 100 * double(ev.battery_kwh) * 1000;
socMaxWh = double(ev.battery_kwh) * 1000;

remainingWh = max(0, socTargetWh - socInitialWh);
chargeMax = max(0, double(ev.P_charge_max_w));
v2gMax = max(0, double(ev.P_v2g_max_w));
etaC = max(0.01, double(ev.eta_c));
etaD = max(0.01, double(ev.eta_d));

% --- Section 3: Charge at the cheapest available intervals ---
availIdx = find(avail);
[~, orderLow] = sort(price(availIdx), 'ascend');
for k = 1:numel(orderLow)
    t = availIdx(orderLow(k));
    if remainingWh <= 1e-6
        break;
    end
    pMax = min(chargeMax, max(0, p_limit_w(t)));
    if pMax <= 0
        continue;
    end
    whCanDeliverToBattery = pMax * dtHr * etaC;
    whToBattery = min(remainingWh, whCanDeliverToBattery);
    p = whToBattery / max(dtHr * etaC, eps);
    evSchedule.p_ev(t) = p;
    remainingWh = remainingWh - whToBattery;
end

% --- Section 4: Optional V2G at expensive intervals while preserving reserve ---
if v2gMax > 0 && strcmpi(ev.charger_type, 'v2g')
    priceThreshold = prctile(price(availIdx), 75);
    [~, orderHigh] = sort(price(availIdx), 'descend');
    socAvailable = socInitialWh + sum(evSchedule.p_ev) * dtHr * etaC;
    maxDischargeWh = max(0, socAvailable - max(socReserveWh, socTargetWh));
    for k = 1:numel(orderHigh)
        t = availIdx(orderHigh(k));
        if price(t) < priceThreshold || maxDischargeWh <= 1e-6
            break;
        end
        if evSchedule.p_ev(t) > 0
            continue;
        end
        whGridCanReceive = v2gMax * dtHr;
        whFromBattery = min(maxDischargeWh, whGridCanReceive / etaD);
        p = whFromBattery * etaD / max(dtHr, eps);
        evSchedule.p_v2g(t) = p;
        maxDischargeWh = maxDischargeWh - whFromBattery;
    end
end

% --- Section 5: Build SOC trajectory and feasibility flag ---
soc = socInitialWh;
for t = 1:W
    soc = soc + etaC * evSchedule.p_ev(t) * dtHr - (evSchedule.p_v2g(t) * dtHr) / etaD;
    soc = min(socMaxWh, max(socMinWh, soc));
    evSchedule.soc(t) = soc;
end

evSchedule.energy_charged_wh = sum(evSchedule.p_ev) * dtHr;
evSchedule.energy_discharged_wh = sum(evSchedule.p_v2g) * dtHr;
evSchedule.feasible = evSchedule.soc(end) + 1e-6 >= min(socTargetWh, socMaxWh);
if evSchedule.feasible
    evSchedule.note = 'EV target satisfied or no additional charge needed';
else
    evSchedule.note = 'EV target not fully satisfied within available window/headroom';
end
end

function out = resize_logical(in, W)
% RESIZE_LOGICAL Resize logical vector by padding or truncating.
out = false(W, 1);
n = min(W, numel(in));
out(1:n) = logical(in(1:n));
end

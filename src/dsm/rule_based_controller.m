function schedule = rule_based_controller(hh, price_series, cfg, p_limit_w)
% RULE_BASED_CONTROLLER Deterministic DSM fallback controller.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   hh (struct): Household daily profile from simulate_household.
%   price_series (W x 1 double): Electricity price [EGP/kWh].
%   cfg (struct): Project configuration.
%   p_limit_w (W x 1 double, optional): Total household power headroom [W].
%
% Outputs:
%   schedule (struct): DSM schedule with appliance start matrix, EV/V2G
%       schedules, SOC, total power, cost, comfort index, and metadata.
%
% Example:
%   schedule = rule_based_controller(hh, price, cfg);

% --- Section 1: Validate and initialize ---
validateattributes(hh, {'struct'}, {'scalar'}, mfilename, 'hh', 1);
validateattributes(price_series, {'numeric'}, {'vector','nonempty','finite'}, mfilename, 'price_series', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

price = double(price_series(:));
W = numel(price);
if nargin < 4 || isempty(p_limit_w)
    p_limit_w = inf(W, 1);
else
    p_limit_w = double(p_limit_w(:));
    if numel(p_limit_w) ~= W
        p_limit_w = repmat(p_limit_w(1), W, 1);
    end
end

fixedW = get_vector_field(hh, 'p_fixed_w', W, 0);
flex = hh.flexibility;
Aloads = get_flex_count(flex);
x = zeros(Aloads, W);
appliancePower = zeros(W, 1);
scheduledStart = nan(Aloads, 1);

% --- Section 2: Schedule controllable appliances at lowest weighted price ---
currentLoad = fixedW;
ctrlActiveCount = zeros(W, 1);
for a = 1:Aloads
    duration = max(1, round(double(flex.duration_steps(a))));
    powerW = max(0, double(flex.power_w(a)));
    earliest = max(1, round(double(flex.earliest_start_step(a))));
    latest = min(W - duration + 1, round(double(flex.latest_start_step(a))));
    pref = min(W, max(1, round(double(flex.preferred_start_step(a)))));
    if latest < earliest
        earliest = max(1, min(W, pref));
        latest = min(W - duration + 1, earliest);
    end
    bestScore = inf;
    bestStart = earliest;
    for t = earliest:latest
        activeIdx = t:min(W, t + duration - 1);
        limitPenalty = sum(max(0, currentLoad(activeIdx) + powerW - p_limit_w(activeIdx))) / 1000;
        overlapPenalty = sum(ctrlActiveCount(activeIdx) > 0);
        priceCost = sum(price(activeIdx)) * (powerW / 1000) * cfg.simulation.dt_hr;
        comfortPenalty = 0.002 * abs(t - pref);
        score = priceCost + comfortPenalty + 1000 * limitPenalty + 1000 * overlapPenalty;
        if score < bestScore
            bestScore = score;
            bestStart = t;
        end
    end
    activeIdx = bestStart:min(W, bestStart + duration - 1);
    x(a, bestStart) = 1;
    appliancePower(activeIdx) = appliancePower(activeIdx) + powerW;
    currentLoad(activeIdx) = currentLoad(activeIdx) + powerW;
    ctrlActiveCount(activeIdx) = ctrlActiveCount(activeIdx) + 1;
    scheduledStart(a) = bestStart;
end

% --- Section 3: EV/V2G heuristic under remaining headroom ---
evHeadroom = p_limit_w - currentLoad;
evSchedule = v2g_scheduler(get_ev_or_empty(hh, W, cfg), price, cfg, evHeadroom);

% --- Section 4: Build final schedule struct ---
pTotal = currentLoad + evSchedule.p_ev - evSchedule.p_v2g;
schedule = struct();
schedule.x = x;
schedule.scheduled_start_step = scheduledStart;
schedule.p_appliance = appliancePower;
schedule.p_ev = evSchedule.p_ev;
schedule.p_v2g = evSchedule.p_v2g;
schedule.soc = evSchedule.soc;
schedule.p_total = pTotal;
schedule.p_total_w = pTotal;
schedule.p_fixed_w = fixedW;
schedule.price_series = price;
schedule.cost_EGP = sum(max(pTotal, 0) .* price) * cfg.simulation.dt_hr / 1000;
schedule.energy_kwh = sum(max(pTotal, 0)) * cfg.simulation.dt_hr / 1000;
schedule.ev_schedule = evSchedule;
schedule.exitflag = 0;
schedule.method = 'rule_based';
schedule.solver_message = 'Heuristic rule-based schedule';
[schedule.comfort_idx, schedule.comfort_detail] = comfort_index(schedule, flex, cfg);
schedule.flexibility = flex;
schedule.limit_violation_w = max(0, pTotal - p_limit_w);
end

function A = get_flex_count(flexibility)
% GET_FLEX_COUNT Return number of controllable loads.
if isfield(flexibility, 'count')
    A = double(flexibility.count);
elseif isfield(flexibility, 'appliance')
    A = numel(flexibility.appliance);
else
    A = 0;
end
end

function v = get_vector_field(s, fieldName, W, defaultValue)
% GET_VECTOR_FIELD Return vector field resized to W.
if isfield(s, fieldName)
    v = double(s.(fieldName)(:));
else
    v = defaultValue * ones(W, 1);
end
if numel(v) < W
    if isempty(v)
        v = defaultValue * ones(W, 1);
    else
        v = [v; repmat(v(end), W - numel(v), 1)];
    end
elseif numel(v) > W
    v = v(1:W);
end
end

function ev = get_ev_or_empty(hh, W, cfg)
% GET_EV_OR_EMPTY Return EV struct with defaults.
ev = struct();
ev.present = false;
ev.available_steps = false(W, 1);
ev.P_charge_max_w = 0;
ev.P_v2g_max_w = 0;
ev.battery_kwh = 0;
ev.soc_initial = 0;
ev.soc_target = cfg.ev.soc_target_pct / 100;
ev.eta_c = cfg.ev.eta_charge;
ev.eta_d = cfg.ev.eta_discharge;
ev.charger_type = 'none';
if isfield(hh, 'ev') && isstruct(hh.ev)
    names = fieldnames(hh.ev);
    for i = 1:numel(names)
        ev.(names{i}) = hh.ev.(names{i});
    end
end
end

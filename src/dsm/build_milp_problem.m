function problem = build_milp_problem(hh, price_series, cfg, p_limit_w)
% BUILD_MILP_PROBLEM Build household DSM MILP matrices for intlinprog.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   hh (struct): Household daily profile from simulate_household.
%   price_series (W x 1 double): Electricity price [EGP/kWh].
%   cfg (struct): Project configuration.
%   p_limit_w (W x 1 double, optional): Maximum allowed total household load [W].
%
% Outputs:
%   problem (struct): intlinprog-ready matrices plus variable index metadata.
%
% Example:
%   problem = build_milp_problem(hh, price, cfg);

% --- Section 1: Validate inputs and dimensions ---
validateattributes(hh, {'struct'}, {'scalar'}, mfilename, 'hh', 1);
validateattributes(price_series, {'numeric'}, {'vector','nonempty','finite'}, mfilename, 'price_series', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

price = double(price_series(:));
W = numel(price);
dtHr = cfg.simulation.dt_min / 60;
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

% --- Section 2: Variable indexing ---
nX = Aloads * W;
nEv = W;
nV2G = W;
nSoc = W;
nVars = nX + nEv + nV2G + nSoc;
idx.x = @(a, t) (a - 1) * W + t;
idx.ev = @(t) nX + t;
idx.v2g = @(t) nX + nEv + t;
idx.soc = @(t) nX + nEv + nV2G + t;
idx.nX = nX;
idx.nVars = nVars;
idx.W = W;
idx.Aloads = Aloads;

f = zeros(nVars, 1);
intcon = 1:nX;
lb = zeros(nVars, 1);
ub = inf(nVars, 1);

% --- Section 3: Appliance start variables and objective coefficients ---
lambdaComfort = get_scalar_or_default(cfg.dsm, 'lambda_comfort', 0.001);
for a = 1:Aloads
    duration = max(1, round(double(flex.duration_steps(a))));
    powerW = max(0, double(flex.power_w(a)));
    earliest = max(1, round(double(flex.earliest_start_step(a))));
    latest = min(W, round(double(flex.latest_start_step(a))));
    pref = min(W, max(1, round(double(flex.preferred_start_step(a)))));
    wt = get_appliance_weight(flex.appliance{a}, cfg);
    validEndLatest = max(earliest, min(latest, W - duration + 1));
    for t = 1:W
        j = idx.x(a, t);
        if t < earliest || t > validEndLatest
            ub(j) = 0;
        else
            activeIdx = t:min(W, t + duration - 1);
            energyCost = sum(price(activeIdx)) * (powerW / 1000) * dtHr;
            comfortCost = lambdaComfort * wt * abs(t - pref);
            f(j) = energyCost + comfortCost;
            ub(j) = 1;
        end
    end
end

% --- Section 4: EV variable bounds and objective coefficients ---
ev = get_ev_or_empty(hh, W, cfg);
if ev.present
    avail = logical(ev.available_steps(:));
    if numel(avail) ~= W
        avail = resize_logical(avail, W);
    end
    for t = 1:W
        evUb = max(0, double(ev.P_charge_max_w)) * double(avail(t));
        v2gUb = max(0, double(ev.P_v2g_max_w)) * double(avail(t));
        ub(idx.ev(t)) = evUb;
        ub(idx.v2g(t)) = v2gUb;
        f(idx.ev(t)) = price(t) * dtHr / 1000;
        f(idx.v2g(t)) = -0.50 * price(t) * dtHr / 1000;
    end
    socMin = cfg.ev.soc_min_pct / 100 * ev.battery_kwh * 1000;
    socMax = ev.battery_kwh * 1000;
    for t = 1:W
        lb(idx.soc(t)) = socMin;
        ub(idx.soc(t)) = socMax;
    end
else
    for t = 1:W
        ub(idx.ev(t)) = 0;
        ub(idx.v2g(t)) = 0;
        lb(idx.soc(t)) = 0;
        ub(idx.soc(t)) = 0;
    end
end

% --- Section 5: Equality constraints for appliance execution and SOC dynamics ---
AeqRows = {};
beqVals = [];
for a = 1:Aloads
    row = sparse(1, nVars);
    hasValid = false;
    for t = 1:W
        j = idx.x(a, t);
        if ub(j) > 0
            row(j) = 1;
            hasValid = true;
        end
    end
    if hasValid
        AeqRows{end + 1, 1} = row; %#ok<AGROW>
        beqVals(end + 1, 1) = 1; %#ok<AGROW>
    end
end

if ev.present
    soc0 = ev.soc_initial * ev.battery_kwh * 1000;
    etaC = max(0.01, ev.eta_c);
    etaD = max(0.01, ev.eta_d);
    for t = 1:W
        row = sparse(1, nVars);
        row(idx.soc(t)) = 1;
        row(idx.ev(t)) = -etaC * dtHr;
        row(idx.v2g(t)) = dtHr / etaD;
        if t == 1
            rhs = soc0;
        else
            row(idx.soc(t - 1)) = -1;
            rhs = 0;
        end
        AeqRows{end + 1, 1} = row; %#ok<AGROW>
        beqVals(end + 1, 1) = rhs; %#ok<AGROW>
    end
end

Aeq = stack_sparse_rows(AeqRows, nVars);
beq = beqVals;

% --- Section 6: Inequality constraints for power limits, overlap, EV target ---
ARows = {};
bVals = [];

% Total household power headroom.
for t = 1:W
    if isfinite(p_limit_w(t))
        row = sparse(1, nVars);
        for a = 1:Aloads
            duration = max(1, round(double(flex.duration_steps(a))));
            powerW = max(0, double(flex.power_w(a)));
            tauMin = max(1, t - duration + 1);
            tauMax = min(t, W);
            for tau = tauMin:tauMax
                row(idx.x(a, tau)) = row(idx.x(a, tau)) + powerW;
            end
        end
        row(idx.ev(t)) = 1;
        row(idx.v2g(t)) = -1;
        ARows{end + 1, 1} = row; %#ok<AGROW>
        bVals(end + 1, 1) = max(0, p_limit_w(t) - fixedW(t)); %#ok<AGROW>
    end
end

% Conservative non-overlap among controllable appliance runs.
for t = 1:W
    row = sparse(1, nVars);
    activeTerms = 0;
    for a = 1:Aloads
        duration = max(1, round(double(flex.duration_steps(a))));
        tauMin = max(1, t - duration + 1);
        tauMax = min(t, W);
        for tau = tauMin:tauMax
            if ub(idx.x(a, tau)) > 0
                row(idx.x(a, tau)) = 1;
                activeTerms = activeTerms + 1;
            end
        end
    end
    if activeTerms > 1
        ARows{end + 1, 1} = row; %#ok<AGROW>
        bVals(end + 1, 1) = 1; %#ok<AGROW>
    end
end

% EV charge and V2G cannot exceed inverter rating simultaneously.
if ev.present
    for t = 1:W
        row = sparse(1, nVars);
        row(idx.ev(t)) = 1;
        row(idx.v2g(t)) = 1;
        ARows{end + 1, 1} = row; %#ok<AGROW>
        bVals(end + 1, 1) = max(double(ev.P_charge_max_w), double(ev.P_v2g_max_w)); %#ok<AGROW>
    end
    targetWh = min(ev.soc_target * ev.battery_kwh * 1000, ev.battery_kwh * 1000);
    row = sparse(1, nVars);
    targetStep = W;
    if isfield(ev, 'departure_step') && isfinite(ev.departure_step) && ev.departure_step > ev.arrival_step && ev.departure_step <= W
        targetStep = round(ev.departure_step);
    end
    row(idx.soc(targetStep)) = -1;
    ARows{end + 1, 1} = row; %#ok<AGROW>
    bVals(end + 1, 1) = -targetWh; %#ok<AGROW>
end

Aineq = stack_sparse_rows(ARows, nVars);
bineq = bVals;

% --- Section 7: Package output ---
problem = struct();
problem.f = f;
problem.intcon = intcon;
problem.A = Aineq;
problem.b = bineq;
problem.Aeq = Aeq;
problem.beq = beq;
problem.lb = lb;
problem.ub = ub;
problem.index = idx;
problem.W = W;
problem.Aloads = Aloads;
problem.fixed_w = fixedW;
problem.flexibility = flex;
problem.ev = ev;
problem.price_series = price;
problem.p_limit_w = p_limit_w;
problem.dt_hr = dtHr;
problem.description = 'Household DSM MILP: controllable appliances, EV charging, V2G, comfort, and power headroom.';
end

function A = stack_sparse_rows(rows, nVars)
% STACK_SPARSE_ROWS Convert cell rows into sparse matrix.
if isempty(rows)
    A = sparse(0, nVars);
    return;
end
A = sparse(numel(rows), nVars);
for i = 1:numel(rows)
    A(i, :) = rows{i};
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
    v = [v; repmat(v(end), W - numel(v), 1)];
elseif numel(v) > W
    v = v(1:W);
end
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

function val = get_scalar_or_default(s, fieldName, defaultValue)
% GET_SCALAR_OR_DEFAULT Read scalar from struct.
val = defaultValue;
if isstruct(s) && isfield(s, fieldName) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    val = double(s.(fieldName));
end
end

function wt = get_appliance_weight(applianceName, cfg)
% GET_APPLIANCE_WEIGHT Read comfort weight.
wt = 1.0;
if isfield(cfg, 'dsm') && isfield(cfg.dsm, 'comfort_weights')
    key = matlab.lang.makeValidName(char(applianceName));
    if isfield(cfg.dsm.comfort_weights, key)
        wt = double(cfg.dsm.comfort_weights.(key));
    end
end
if ~isfinite(wt) || wt <= 0
    wt = 1.0;
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
ev.arrival_step = NaN;
ev.departure_step = NaN;
if isfield(hh, 'ev') && isstruct(hh.ev)
    names = fieldnames(hh.ev);
    for i = 1:numel(names)
        ev.(names{i}) = hh.ev.(names{i});
    end
end
end

function out = resize_logical(in, W)
% RESIZE_LOGICAL Resize logical vector.
out = false(W, 1);
n = min(W, numel(in));
out(1:n) = logical(in(1:n));
end

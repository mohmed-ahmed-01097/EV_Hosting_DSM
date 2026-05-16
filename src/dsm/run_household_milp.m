function schedule = run_household_milp(hh, price_series, cfg, p_limit_w)
% RUN_HOUSEHOLD_MILP Solve household DSM scheduling problem.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   hh (struct): Household daily profile from simulate_household.
%   price_series (W x 1 double): Electricity price [EGP/kWh].
%   cfg (struct): Project configuration.
%   p_limit_w (W x 1 double, optional): Total household power limit [W].
%
% Outputs:
%   schedule (struct): Optimized or fallback household schedule.
%
% Example:
%   schedule = run_household_milp(hh, price, cfg);

% --- Section 1: Validate inputs and build problem ---
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

problem = build_milp_problem(hh, price, cfg, p_limit_w);

% --- Section 2: Solve with intlinprog when available ---
useFallback = false;
solution = [];
fval = NaN;
exitflag = -999;
solverMessage = '';

if problem.index.nVars == 0 || isempty(problem.f)
    useFallback = true;
    solverMessage = 'Empty MILP problem; used rule-based fallback.';
elseif exist('intlinprog', 'file') ~= 2
    useFallback = true;
    solverMessage = 'intlinprog unavailable; used rule-based fallback.';
else
    try
        options = optimoptions('intlinprog', ...
            'Display', 'off', ...
            'MaxTime', 30, ...
            'RelativeGapTolerance', 0.02);
        [solution, fval, exitflag, output] = intlinprog(problem.f, problem.intcon, ...
            problem.A, problem.b, problem.Aeq, problem.beq, problem.lb, problem.ub, options);
        if isfield(output, 'message')
            solverMessage = output.message;
        end
        if isempty(solution) || exitflag <= 0
            useFallback = true;
            solverMessage = sprintf('MILP exitflag %d; used rule-based fallback. %s', exitflag, solverMessage);
        end
    catch ME
        useFallback = true;
        solverMessage = sprintf('MILP exception; used rule-based fallback: %s', ME.message);
    end
end

% --- Section 3: Decode or fallback ---
if useFallback
    schedule = rule_based_controller(hh, price, cfg, p_limit_w);
    schedule.problem = problem;
    schedule.exitflag = exitflag;
    schedule.solver_message = solverMessage;
    if ~isfield(schedule, 'method') || isempty(schedule.method)
        schedule.method = 'rule_based';
    end
    return;
end

schedule = decode_solution(solution, fval, exitflag, solverMessage, problem, hh, cfg);
end

function schedule = decode_solution(sol, fval, exitflag, solverMessage, problem, hh, cfg)
% DECODE_SOLUTION Convert intlinprog vector to schedule struct.
idx = problem.index;
W = problem.W;
Aloads = problem.Aloads;
flex = problem.flexibility;
fixedW = problem.fixed_w;
price = problem.price_series;
dtHr = problem.dt_hr;

x = zeros(Aloads, W);
for a = 1:Aloads
    for t = 1:W
        x(a, t) = sol(idx.x(a, t));
    end
end
x = double(x > 0.5);

pAppliance = zeros(W, 1);
scheduledStart = nan(Aloads, 1);
for a = 1:Aloads
    starts = find(x(a, :) > 0.5);
    if isempty(starts)
        [~, starts] = max(x(a, :));
    end
    s = starts(1);
    scheduledStart(a) = s;
    duration = max(1, round(double(flex.duration_steps(a))));
    powerW = max(0, double(flex.power_w(a)));
    activeIdx = s:min(W, s + duration - 1);
    pAppliance(activeIdx) = pAppliance(activeIdx) + powerW;
end

pEv = zeros(W, 1);
pV2G = zeros(W, 1);
soc = zeros(W, 1);
for t = 1:W
    pEv(t) = sol(idx.ev(t));
    pV2G(t) = sol(idx.v2g(t));
    soc(t) = sol(idx.soc(t));
end
pTotal = fixedW + pAppliance + pEv - pV2G;

schedule = struct();
schedule.x = x;
schedule.scheduled_start_step = scheduledStart;
schedule.p_appliance = pAppliance;
schedule.p_ev = pEv;
schedule.p_v2g = pV2G;
schedule.soc = soc;
schedule.p_total = pTotal;
schedule.p_total_w = pTotal;
schedule.p_fixed_w = fixedW;
schedule.price_series = price;
schedule.cost_EGP = sum(max(pTotal, 0) .* price) * dtHr / 1000;
schedule.energy_kwh = sum(max(pTotal, 0)) * dtHr / 1000;
schedule.fval = fval;
schedule.exitflag = exitflag;
schedule.solver_message = solverMessage;
schedule.method = 'milp';
schedule.problem = problem;
schedule.flexibility = flex;
schedule.limit_violation_w = max(0, pTotal - problem.p_limit_w);
[schedule.comfort_idx, schedule.comfort_detail] = comfort_index(schedule, flex, cfg);

if isfield(hh, 'ev') && isstruct(hh.ev)
    schedule.ev_schedule = struct('p_ev', pEv, 'p_v2g', pV2G, 'soc', soc, ...
        'feasible', true, 'note', 'MILP-decoded EV schedule');
else
    schedule.ev_schedule = struct('p_ev', pEv, 'p_v2g', pV2G, 'soc', soc, ...
        'feasible', true, 'note', 'No EV');
end
end

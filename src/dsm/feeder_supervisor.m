function supervisor = feeder_supervisor(cfg, net, assignment, householdProfiles, price_series)
% FEEDER_SUPERVISOR Hierarchical feeder-level DSM coordination loop.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Project configuration.
%   net (struct): Feeder network from build_feeder_network.
%   assignment (struct): Household assignment from assign_households.
%   householdProfiles (cell/struct array): Household profiles from simulate_household.
%   price_series (W x 1 double): Electricity price [EGP/kWh].
%
% Outputs:
%   supervisor (struct): Coordinated schedules, feeder load, PQ summary,
%       iteration history, comfort summary, and convergence flag.
%
% Example:
%   out = feeder_supervisor(cfg, net, assignment, hhCells, price);

% --- Section 1: Validate and normalize inputs ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
validateattributes(net, {'struct'}, {'scalar'}, mfilename, 'net', 2);
validateattributes(assignment, {'struct'}, {'scalar'}, mfilename, 'assignment', 3);
validateattributes(price_series, {'numeric'}, {'vector','nonempty','finite'}, mfilename, 'price_series', 5);

price = double(price_series(:));
W = numel(price);
hhCells = normalize_households(householdProfiles);
H = numel(hhCells);
if H == 0
    error('feeder_supervisor:noHouseholds', 'householdProfiles must contain at least one household.');
end
maxIter = cfg.dsm.max_coordination_iterations;
if isempty(maxIter) || maxIter < 1
    maxIter = 3;
end

fprintf('[feeder_supervisor] Starting coordination: H=%d | W=%d | max_iter=%d\n', H, W, maxIter);

% --- Section 2: Initial independent household optimization ---
pLimit = inf(W, H);
schedules = cell(H, 1);
for h = 1:H
    schedules{h} = run_household_milp(hhCells{h}, price, cfg, pLimit(:, h));
end

history = struct('iteration', {}, 'violating_steps', {}, 'max_vuf_pct', {}, ...
    'min_voltage_pu', {}, 'max_loading_pct', {}, 'max_iuf_pct', {}, 'max_ncr_pct', {});
converged = false;
pqTimeseries = cell(W, 1);

% --- Section 3: Outer feeder coordination loop ---
for iter = 1:maxIter
    [S_series, L_house_w, L_phase_w] = assemble_feeder_loads(schedules, hhCells, assignment, net, W);
    [violSteps, pqTimeseries, pqSummary] = evaluate_pq_series(S_series, net, assignment, cfg);

    history(iter).iteration = iter; %#ok<AGROW>
    history(iter).violating_steps = violSteps; %#ok<AGROW>
    history(iter).max_vuf_pct = pqSummary.max_vuf_pct; %#ok<AGROW>
    history(iter).min_voltage_pu = pqSummary.min_voltage_pu; %#ok<AGROW>
    history(iter).max_loading_pct = pqSummary.max_loading_pct; %#ok<AGROW>
    history(iter).max_iuf_pct = pqSummary.max_iuf_pct; %#ok<AGROW>
    history(iter).max_ncr_pct = pqSummary.max_ncr_pct; %#ok<AGROW>

    fprintf('[feeder_supervisor] Iteration %d | violations=%d | Vmin=%.3f pu | max VUF=%.3f%% | max TL=%.1f%%\n', ...
        iter, numel(violSteps), pqSummary.min_voltage_pu, pqSummary.max_vuf_pct, pqSummary.max_loading_pct);

    if isempty(violSteps)
        converged = true;
        break;
    end

    % Tighten per-household headroom for households active during violating steps.
    overloadRatio = max(0, pqSummary.max_loading_pct / max(cfg.pq_limits.transformer_loading_max_pct, 1) - 1);
    voltageRatio = max(0, cfg.pq_limits.voltage_min_pu - pqSummary.min_voltage_pu) / max(cfg.pq_limits.voltage_min_pu, 1e-6);
    tightenFactor = min(0.35, max(0.05, 0.10 + 0.50 * max(overloadRatio, voltageRatio)));

    affected = false(H, 1);
    for h = 1:H
        p = schedules{h}.p_total_w(:);
        p = resize_numeric(p, W, 0);
        if any(p(violSteps) > median(p) + 100)
            affected(h) = true;
        end
    end
    if ~any(affected)
        affected(:) = true;
    end

    for h = find(affected)'
        oldLimit = pLimit(:, h);
        currentP = resize_numeric(schedules{h}.p_total_w(:), W, 0);
        newLimit = oldLimit;
        newLimit(violSteps) = min(oldLimit(violSteps), max(0, currentP(violSteps) * (1 - tightenFactor)));
        pLimit(:, h) = newLimit;
        schedules{h} = run_household_milp(hhCells{h}, price, cfg, pLimit(:, h));
    end
end

% --- Section 4: Final aggregation and report ---
[S_series, L_house_w, L_phase_w] = assemble_feeder_loads(schedules, hhCells, assignment, net, W);
[violSteps, pqTimeseries, pqSummary] = evaluate_pq_series(S_series, net, assignment, cfg);
comfortValues = zeros(H, 1);
for h = 1:H
    comfortValues(h) = schedules{h}.comfort_idx;
end

supervisor = struct();
supervisor.schedules = schedules;
supervisor.L_house_w = L_house_w;
supervisor.L_phase_w = L_phase_w;
supervisor.S_series = S_series;
supervisor.pq_timeseries = pqTimeseries;
supervisor.pq_summary = pqSummary;
supervisor.violating_steps = violSteps;
supervisor.iteration_history = history;
supervisor.converged = converged || isempty(violSteps);
supervisor.iterations_used = numel(history);
supervisor.comfort_summary = struct('mean', mean(comfortValues), 'min', min(comfortValues), ...
    'max', max(comfortValues));
supervisor.total_cost_EGP = sum(cellfun(@(s) s.cost_EGP, schedules));
supervisor.description = 'Hierarchical feeder supervisor for Phase 4 DSM coordination.';

fprintf('[feeder_supervisor] Complete | converged=%d | final violations=%d | mean CI=%.3f\n', ...
    supervisor.converged, numel(supervisor.violating_steps), supervisor.comfort_summary.mean);
end

function hhCells = normalize_households(householdProfiles)
% NORMALIZE_HOUSEHOLDS Convert input to cell array.
if iscell(householdProfiles)
    hhCells = householdProfiles(:);
elseif isstruct(householdProfiles) && numel(householdProfiles) > 1
    hhCells = num2cell(householdProfiles(:));
elseif isstruct(householdProfiles) && isfield(householdProfiles, 'L_fixed_w')
    error('feeder_supervisor:unsupportedPopStruct', ...
        'Pass daily household profile structs/cells. Population matrices are handled in Phase 5 scenarios.');
elseif isstruct(householdProfiles)
    hhCells = {householdProfiles};
else
    error('feeder_supervisor:badProfiles', 'Unsupported householdProfiles input.');
end
end

function [S_series, L_house_w, L_phase_w] = assemble_feeder_loads(schedules, hhCells, assignment, net, W)
% ASSEMBLE_FEEDER_LOADS Map household schedules to three-phase bus loads.
H = numel(schedules);
S_series = complex(zeros(3, net.n_buses, W));
L_house_w = zeros(W, H);
L_phase_w = zeros(W, 3);
pf = 0.95;
qFactor = tan(acos(pf));
for h = 1:H
    p = resize_numeric(schedules{h}.p_total_w(:), W, 0);
    L_house_w(:, h) = p;
    if isfield(hhCells{h}, 'phase_id')
        phaseId = hhCells{h}.phase_id;
    else
        phaseId = assignment.phase_id(h);
    end
    if isfield(hhCells{h}, 'bus_id')
        busId = hhCells{h}.bus_id;
    else
        busId = assignment.bus_id(h);
    end
    phaseId = max(1, min(3, round(double(phaseId))));
    busId = max(1, min(net.n_buses, round(double(busId))));
    for t = 1:W
        S_series(phaseId, busId, t) = S_series(phaseId, busId, t) + complex(p(t), p(t) * qFactor);
        L_phase_w(t, phaseId) = L_phase_w(t, phaseId) + p(t);
    end
end
end

function [violSteps, pqTimeseries, summary] = evaluate_pq_series(S_series, net, assignment, cfg)
% EVALUATE_PQ_SERIES Run BFS and PQ checks for every time step.
W = size(S_series, 3);
pqTimeseries = cell(W, 1);
viol = false(W, 1);
maxVuf = 0;
maxLoading = 0;
maxIuf = 0;
maxNcr = 0;
minVoltage = inf;
nonConverged = false(W, 1);
for t = 1:W
    S = S_series(:, :, t);
    [V, I, In, ok] = bfs_power_flow(net, S, assignment);
    pq = compute_pq_indices(V, I, In, S, net, cfg);
    pqTimeseries{t} = pq;
    maxVuf = max(maxVuf, max(pq.VUF_pct));
    maxLoading = max(maxLoading, max(pq.TL_pct));
    maxIuf = max(maxIuf, max(pq.IUF_pct));
    maxNcr = max(maxNcr, max(pq.NCR_pct));
    minVoltage = min(minVoltage, pq.V_min_pu);
    stepViol = ~ok || pq.violations.vuf || pq.violations.voltage || ...
        pq.violations.loading || pq.violations.iuf || pq.violations.ncr;
    viol(t) = stepViol;
    nonConverged(t) = ~ok;
end
violSteps = find(viol);
summary = struct();
summary.max_vuf_pct = maxVuf;
summary.min_voltage_pu = minVoltage;
summary.max_loading_pct = maxLoading;
summary.max_iuf_pct = maxIuf;
summary.max_ncr_pct = maxNcr;
summary.non_converged_steps = find(nonConverged);
summary.violation_count = numel(violSteps);
end

function v = resize_numeric(v, W, defaultValue)
% RESIZE_NUMERIC Resize vector to W.
if isempty(v)
    v = defaultValue * ones(W, 1);
elseif numel(v) < W
    v = [v; repmat(v(end), W - numel(v), 1)];
elseif numel(v) > W
    v = v(1:W);
end
end

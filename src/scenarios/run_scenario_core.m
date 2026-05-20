function results = run_scenario_core(cfg, data, net, assignment, pop, cal_struct, weather, scenario_id, description, mode, progress_cb)
% RUN_SCENARIO_CORE Shared Phase 5 scenario execution engine.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg          (struct): Project configuration.
%   data         (struct): Survey data from data_loader.
%   net          (struct): Feeder network from build_feeder_network.
%   assignment   (struct): Household assignment from assign_households.
%   pop          (struct): Population profiles from simulate_population or a
%                compatible test fixture.
%   cal_struct   (struct): Calendar struct from daytype_calendar.
%   weather      (struct): Weather struct from get_weather.
%   scenario_id  (double): Scenario identifier.
%   description  (char): Scenario description.
%   mode         (struct): Scenario controls.
%
% Outputs:
%   results (struct): Phase 5 scenario result with fields required by the
%       master implementation plan.
%
% Example:
%   r = run_scenario_core(cfg,data,net,assignment,pop,cal,weather,1, ...
%       'Uncontrolled EV integration', struct('ev_enabled',true));

% --- Section 1: Validate inputs and normalize mode ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
validateattributes(net, {'struct'}, {'scalar'}, mfilename, 'net', 3);
validateattributes(assignment, {'struct'}, {'scalar'}, mfilename, 'assignment', 4);
validateattributes(pop, {'struct'}, {'scalar'}, mfilename, 'pop', 5);
validateattributes(cal_struct, {'struct'}, {'scalar'}, mfilename, 'cal_struct', 6);
validateattributes(scenario_id, {'numeric'}, {'scalar'}, mfilename, 'scenario_id', 8);
if nargin < 10 || isempty(mode)
    mode = struct();
end
if nargin < 11 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end
mode = normalize_mode(mode);

tStartClock = tic;
T = size(pop.L_house_w, 1);
H = size(pop.L_house_w, 2);
tvec = cfg.simulation.tvec_min(1:T);
cal_eval = slice_calendar(cal_struct, T);
weather_eval = slice_weather(weather, T); %#ok<NASGU>
base = normalize_population_matrices(pop, T, H);
base = apply_feeder_load_calibration_if_needed(base, cfg, assignment, net, progress_cb);

fprintf('[run_scenario_core] Scenario %g: %s | T=%d | H=%d | mode=%s\n', ...
    scenario_id, description, T, H, mode.dispatch_mode);
progress_cb(5, sprintf('Scenario %g: initializing...', scenario_id));
drawnow('limitrate');

% --- Section 2: Build scenario load matrix ---
progress_cb(10, sprintf('Scenario %g: building load matrix...', scenario_id));
drawnow('limitrate');
price = select_scenario_price(cfg, tvec, cal_eval);

switch lower(mode.dispatch_mode)
    case 'none'
        L_house_w = base.L_house_w;
        schedules = {};
        comfortValues = nan(H, 1);
        if mode.ev_enabled
            L_house_w = L_house_w + build_uncontrolled_ev_matrix(cfg, assignment, T, H, mode.charger_override, mode.ev_penetration_override);
        end

    case 'uncontrolled_ev'
        L_house_w = base.L_house_w + build_uncontrolled_ev_matrix(cfg, assignment, T, H, mode.charger_override, mode.ev_penetration_override);
        schedules = {};
        comfortValues = nan(H, 1);

    case 'rule_based'
        [L_house_w, schedules, comfortValues] = apply_household_scheduling(base, cfg, assignment, price, mode, 'rule_based', progress_cb, scenario_id);

    case 'milp_ev_only'
        evOnlyMode = mode;
        evOnlyMode.schedule_flexible_loads = false;
        [L_house_w, schedules, comfortValues] = apply_household_scheduling(base, cfg, assignment, price, evOnlyMode, 'milp', progress_cb, scenario_id);

    case {'milp', 'milp_v2g'}
        [L_house_w, schedules, comfortValues] = apply_household_scheduling(base, cfg, assignment, price, mode, 'milp', progress_cb, scenario_id);

    case 'supervised_milp'
        [L_house_w, schedules, comfortValues] = apply_supervised_scheduling(base, cfg, assignment, net, price, mode, progress_cb);

    otherwise
        error('run_scenario_core:unknownMode', 'Unknown dispatch mode: %s', mode.dispatch_mode);
end

L_house_w = max(0, L_house_w);

% --- Section 3: Feeder PQ evaluation ---
progress_cb(50, sprintf('Scenario %g: running power flow...', scenario_id));
drawnow('limitrate');
[S_series, L_feeder_w] = assemble_feeder_power_series(L_house_w, assignment, net, cfg);
[pq_timeseries, pq_summary] = evaluate_scenario_pq(S_series, net, assignment, cfg, progress_cb, scenario_id);

if mode.ev_enabled
    L_ev_per_bus = estimate_ev_harmonic_power_per_bus(cfg, assignment, net, L_house_w, mode);
    [pq_timeseries, pq_summary] = augment_harmonic_pq_series(pq_timeseries, pq_summary, L_ev_per_bus, assignment, net, cfg);
end

% --- Section 4: Costs, comfort, hosting capacity, and output struct ---
progress_cb(80, sprintf('Scenario %g: computing costs and comfort...', scenario_id));
drawnow('limitrate');
costs = compute_costs(cfg, L_house_w, tvec, cal_eval);
comfortSummary = summarize_comfort(comfortValues, mode.dispatch_mode);
hostingCapacityPct = estimate_hosting_capacity(cfg, base, assignment, net, cal_eval, mode);

results = struct();
results.scenario_id = scenario_id;
results.description = description;
results.mode = mode;
results.pq_summary = pq_summary;
results.pq_timeseries = pq_timeseries;
results.costs = costs;
results.hosting_capacity_pct = hostingCapacityPct;
results.comfort_summary = comfortSummary;
results.L_feeder_w = L_feeder_w;
results.L_house_w = L_house_w;
results.S_series = S_series;
results.schedules = schedules;
results.runtime_s = toc(tStartClock);
results.metadata = struct();
results.metadata.created_on = datestr(now, 31);
results.metadata.num_steps = T;
results.metadata.num_households = H;
results.metadata.dt_min = cfg.simulation.dt_min;
results.metadata.weather_source = getfield_safe(weather, 'meta', 'source', 'unknown');
results.metadata.note = ['Phase 5 scenario runner. Hosting capacity is a screening estimate ' ...
    'using representative sample steps; later thesis runs can refine it with full Monte Carlo evaluation.'];

if mode.compare_charger_types
    results.comparison = compare_slow_fast_uncontrolled(cfg, base, assignment, net, cal_eval, mode);
end

% Apply result-storage policy before returning. In normal thesis runs this keeps
% the MAT file small by saving summaries and feeder-level outputs only, while
% avoiding large per-step PQ structs, household matrices, and controller objects.
results = apply_result_storage_policy(results, cfg);
progress_cb(100, sprintf('Scenario %g complete.', scenario_id));
drawnow('limitrate');

fprintf('[run_scenario_core] Scenario %g complete | Vmin=%.3f pu | max VUF=%.3f%% | max TL=%.1f%% | runtime=%.2fs | storage=%s\n', ...
    scenario_id, results.pq_summary.min_voltage_pu, results.pq_summary.max_vuf_pct, ...
    results.pq_summary.max_loading_pct, results.runtime_s, results.metadata.storage_mode);
end

function mode = normalize_mode(mode)
% NORMALIZE_MODE Fill default scenario mode fields.
def = struct();
def.ev_enabled = false;
def.v2g_enabled = false;
def.dsm_enabled = false;
def.dispatch_mode = 'none';
def.charger_override = '';
def.ev_penetration_override = [];
def.schedule_flexible_loads = true;
def.compare_charger_types = false;
def.price_method = 'TOU';
def.hosting_step_pct = 5;
def.hosting_max_pct = 50;
def.hosting_sample_steps = 96;
def.allow_negative_net_load = false;
fields = fieldnames(def);
for i = 1:numel(fields)
    f = fields{i};
    if ~isfield(mode, f) || isempty(mode.(f))
        mode.(f) = def.(f);
    end
end
end

function base = normalize_population_matrices(pop, T, H)
% NORMALIZE_POPULATION_MATRICES Ensure expected population fields exist.
base = struct();
base.L_house_w = resize_matrix_field(pop, 'L_house_w', T, H, 0);
base.L_fixed_w = resize_matrix_field(pop, 'L_fixed_w', T, H, 0);
base.L_ctrl_w = resize_matrix_field(pop, 'L_ctrl_w', T, H, 0);
base.L_hvac_w = resize_matrix_field(pop, 'L_hvac_w', T, H, 0);
if isfield(pop, 'flexibility')
    base.flexibility = pop.flexibility;
else
    base.flexibility = cell(H, 1);
    for h = 1:H
        base.flexibility{h} = empty_flexibility();
    end
end
if numel(base.flexibility) < H
    base.flexibility(end+1:H, 1) = {empty_flexibility()};
end
end


function base = apply_feeder_load_calibration_if_needed(base, cfg, assignment, net, progress_cb)
% APPLY_FEEDER_LOAD_CALIBRATION_IF_NEEDED Scale survey-derived base loads to a plausible feeder baseline.
%
% The legacy survey data can generate very high coincident summer HVAC peaks.
% Without calibration, the no-EV baseline may already violate voltage and
% transformer-loading limits, which makes EV hosting capacity permanently zero
% and hides the actual DSM/EV contribution. This calibration is deliberately
% applied only to the behavior-driven base load. Scenario EV charging power is
% not scaled.
if nargin < 5 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end
if ~isfield(cfg, 'calibration') || ~get_nested_logical_local(cfg.calibration, 'enable_feeder_load_calibration', false)
    base.calibration = struct('enabled', false, 'scale_factor', 1.0, 'reason', 'disabled');
    return;
end
if isfield(base, 'calibration') && isfield(base.calibration, 'applied') && base.calibration.applied
    return;
end
[T, ~] = size(base.L_house_w);
sampleN = round(get_nested_number_local(cfg.calibration, 'sample_steps', 120));
sampleN = max(24, min(T, sampleN));
steps = sample_steps_for_hosting(base.L_house_w, sampleN);
if isempty(steps)
    base.calibration = struct('enabled', true, 'applied', false, 'scale_factor', 1.0, 'reason', 'empty sample');
    return;
end
try
    [S0, ~] = assemble_feeder_power_series(base.L_house_w(steps, :), assignment, net, cfg);
    [~, summary0] = evaluate_scenario_pq(S0, net, assignment, cfg);
catch ME
    warning('run_scenario_core:calibrationEval', 'Baseline calibration evaluation failed: %s', ME.message);
    base.calibration = struct('enabled', true, 'applied', false, 'scale_factor', 1.0, 'reason', ME.message);
    return;
end
targetTL = get_nested_number_local(cfg.calibration, 'target_baseline_loading_pct', 80.0);
targetV  = get_nested_number_local(cfg.calibration, 'target_baseline_vmin_pu', 0.95);
minScale = get_nested_number_local(cfg.calibration, 'min_load_scale', 0.25);
maxScale = get_nested_number_local(cfg.calibration, 'max_load_scale', 1.0);
scaleFromTL = 1.0;
if isfinite(summary0.max_loading_pct) && summary0.max_loading_pct > targetTL
    scaleFromTL = 0.98 * targetTL / max(summary0.max_loading_pct, eps);
end
scaleFromV = 1.0;
if isfinite(summary0.min_voltage_pu) && summary0.min_voltage_pu < targetV
    actualDrop = max(1e-6, 1.0 - summary0.min_voltage_pu);
    targetDrop = max(1e-6, 1.0 - targetV);
    scaleFromV = 0.98 * targetDrop / actualDrop;
end
scale = max(minScale, min([maxScale, scaleFromTL, scaleFromV]));
if ~isfinite(scale) || scale <= 0
    scale = 1.0;
end
base.calibration = struct();
base.calibration.enabled = true;
base.calibration.applied = scale < 0.999;
base.calibration.scale_factor = scale;
base.calibration.pre_max_loading_pct = summary0.max_loading_pct;
base.calibration.pre_min_voltage_pu = summary0.min_voltage_pu;
base.calibration.target_loading_pct = targetTL;
base.calibration.target_vmin_pu = targetV;
base.calibration.sample_steps = numel(steps);
if scale < 0.999
    if get_nested_logical_local(cfg.calibration, 'apply_to_fixed', true), base.L_fixed_w = base.L_fixed_w * scale; end
    if get_nested_logical_local(cfg.calibration, 'apply_to_controllable', true), base.L_ctrl_w = base.L_ctrl_w * scale; end
    if get_nested_logical_local(cfg.calibration, 'apply_to_hvac', true), base.L_hvac_w = base.L_hvac_w * scale; end
    base.L_house_w = base.L_house_w * scale;
    progress_cb(7, sprintf('Applied feeder load calibration scale %.3f (baseline TL %.1f%%, Vmin %.3f pu)', scale, summary0.max_loading_pct, summary0.min_voltage_pu));
    fprintf('[run_scenario_core] Applied feeder load calibration scale %.3f | pre TL=%.1f%% | pre Vmin=%.3f pu\n', scale, summary0.max_loading_pct, summary0.min_voltage_pu);
else
    progress_cb(7, sprintf('Feeder load calibration not needed (baseline TL %.1f%%, Vmin %.3f pu)', summary0.max_loading_pct, summary0.min_voltage_pu));
end
drawnow('limitrate');
end

function M = resize_matrix_field(s, fieldName, T, H, defaultValue)
% RESIZE_MATRIX_FIELD Read and resize matrix field.
if isfield(s, fieldName)
    M = double(s.(fieldName));
else
    M = defaultValue * ones(T, H);
end
if isempty(M)
    M = defaultValue * ones(T, H);
end
if size(M, 1) < T
    M = [M; repmat(M(end, :), T - size(M, 1), 1)];
elseif size(M, 1) > T
    M = M(1:T, :);
end
if size(M, 2) < H
    M = [M, defaultValue * ones(T, H - size(M, 2))];
elseif size(M, 2) > H
    M = M(:, 1:H);
end
M(~isfinite(M)) = defaultValue;
M = max(0, M);
end

function calOut = slice_calendar(calStruct, T)
% SLICE_CALENDAR Return first T calendar samples.
calOut = struct();
fields = fieldnames(calStruct);
for i = 1:numel(fields)
    f = fields{i};
    v = calStruct.(f);
    if isnumeric(v) || islogical(v) || isdatetime(v) || iscategorical(v)
        if numel(v) >= T
            calOut.(f) = v(1:T);
        else
            calOut.(f) = v;
        end
    else
        calOut.(f) = v;
    end
end
end

function weatherOut = slice_weather(weather, T)
% SLICE_WEATHER Return first T weather samples.
weatherOut = weather;
if isfield(weatherOut, 'temp_C') && numel(weatherOut.temp_C) >= T
    weatherOut.temp_C = weatherOut.temp_C(1:T);
end
if isfield(weatherOut, 'timestamps') && numel(weatherOut.timestamps) >= T
    weatherOut.timestamps = weatherOut.timestamps(1:T);
end
end

function price = select_scenario_price(cfg, tvec, calStruct)
% SELECT_SCENARIO_PRICE Choose the main scenario scheduling price.
method = 'TOU';
if isfield(cfg, 'pricing') && isfield(cfg.pricing, 'main_method') && ~isempty(cfg.pricing.main_method)
    method = cfg.pricing.main_method;
end
if strcmpi(method, 'Block')
    method = 'TOU';  % block tariff is monthly volume-based; TOU gives a usable dispatch signal
end
price = select_pricing(method, cfg, tvec, 0, calStruct);
if isstruct(price)
    price = price.price_series;
end
price = double(price(:));
end

function [L_house_w, schedules, comfortValues] = apply_household_scheduling(base, cfg, assignment, price, mode, controller, progress_cb, scenario_id)
% APPLY_HOUSEHOLD_SCHEDULING Run household controllers day by day.
if nargin < 7 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end
if nargin < 8, scenario_id = NaN; end
[T, H] = size(base.L_house_w);
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
numDays = ceil(T / stepsPerDay);
L_house_w = zeros(T, H);
schedules = cell(H, numDays);
comfortValues = nan(H, numDays);
for day = 1:numDays
    idx = day_indices(day, stepsPerDay, T);
    W = numel(idx);
    priceDay = price(idx);
    fprintf('[run_scenario_core] Scheduling day %d/%d with %s controller\n', day, numDays, controller);
    progress_cb(10 + round(35 * (day-1) / max(numDays,1)), sprintf('Scenario %g: scheduling day %d/%d (%s)', scenario_id, day, numDays, controller));
    drawnow('limitrate');
    for h = 1:H
        hh = build_daily_household(base, assignment, cfg, h, idx, day, mode);
        if strcmpi(controller, 'rule_based')
            sch = rule_based_controller(hh, priceDay, cfg);
        else
            sch = run_household_milp(hh, priceDay, cfg);
        end
        L_house_w(idx, h) = resize_vector(sch.p_total_w, W, 0);
        schedules{h, day} = strip_large_problem_field(sch);
        comfortValues(h, day) = sch.comfort_idx;
        if mod(h, max(1, round(H/5))) == 0
            progress_cb(10 + round(35 * ((day-1) + h/H) / max(numDays,1)), sprintf('Scenario %g: scheduling day %d/%d, household %d/%d', scenario_id, day, numDays, h, H));
            drawnow('limitrate');
        end
    end
end
comfortValues = comfortValues(:);
end

function [L_house_w, schedules, comfortValues] = apply_supervised_scheduling(base, cfg, assignment, net, price, mode, progress_cb)
% APPLY_SUPERVISED_SCHEDULING Run feeder supervisor day by day.
[T, H] = size(base.L_house_w);
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
numDays = ceil(T / stepsPerDay);
L_house_w = zeros(T, H);
schedules = cell(numDays, 1);
comfortValues = nan(H, numDays);
for day = 1:numDays
    idx = day_indices(day, stepsPerDay, T);
    W = numel(idx);
    priceDay = price(idx);
    hhCells = cell(H, 1);
    for h = 1:H
        hhCells{h} = build_daily_household(base, assignment, cfg, h, idx, day, mode);
    end
    dayProgress = @(pct, msg) progress_cb(min(99, round(((day - 1) + pct/100) * 100 / max(numDays,1))), msg);
    sup = feeder_supervisor(cfg, net, assignment, hhCells, priceDay, dayProgress);
    L_house_w(idx, :) = resize_matrix_to(sup.L_house_w, W, H, 0);
    schedules{day} = sup;
    if isfield(sup, 'schedules')
        for h = 1:min(H, numel(sup.schedules))
            comfortValues(h, day) = sup.schedules{h}.comfort_idx;
        end
    end
end
comfortValues = comfortValues(:);
end

function hh = build_daily_household(base, assignment, cfg, h, idx, day, mode)
% BUILD_DAILY_HOUSEHOLD Build controller-compatible household struct.
W = numel(idx);
hh = struct();
if mode.schedule_flexible_loads
    hh.p_fixed_w = resize_vector(base.L_fixed_w(idx, h), W, 0);
    hh.p_controllable_w = resize_vector(base.L_ctrl_w(idx, h), W, 0);
else
    hh.p_fixed_w = resize_vector(base.L_house_w(idx, h), W, 0);
    hh.p_controllable_w = zeros(W, 1);
end
hh.p_hvac_w = resize_vector(base.L_hvac_w(idx, h), W, 0);
hh.p_original_total_w = resize_vector(base.L_house_w(idx, h), W, 0);
hh.p_total_w = hh.p_fixed_w + hh.p_controllable_w;
hh.phase_id = assignment.phase_id(h);
hh.zone = assignment.zone(h);
hh.bus_id = assignment.bus_id(h);
hh.household_id = assignment.household_id(h);
if mode.schedule_flexible_loads && h <= numel(base.flexibility) && ~isempty(base.flexibility{h})
    hh.flexibility = sanitize_flexibility(base.flexibility{h}, W);
else
    hh.flexibility = empty_flexibility();
end
if mode.ev_enabled
    hh.ev = make_deterministic_ev(cfg, assignment, h, day, W, mode);
else
    hh.ev = make_no_ev(W, cfg);
end
end

function flex = sanitize_flexibility(flex, W)
% SANITIZE_FLEXIBILITY Make flexibility windows valid for current horizon.
if ~isstruct(flex) || ~isfield(flex, 'count') || flex.count < 1
    flex = empty_flexibility();
    return;
end
n = double(flex.count);
fields = {'duration_steps','power_w','earliest_start_step','latest_start_step','preferred_start_step'};
for i = 1:numel(fields)
    f = fields{i};
    if ~isfield(flex, f) || isempty(flex.(f))
        flex.(f) = ones(n, 1);
    end
    flex.(f) = double(flex.(f)(:));
    if numel(flex.(f)) < n
        flex.(f)(end+1:n, 1) = flex.(f)(end);
    end
    flex.(f) = flex.(f)(1:n);
end
flex.duration_steps = max(1, min(W, round(flex.duration_steps)));
flex.earliest_start_step = max(1, min(W, round(flex.earliest_start_step)));
flex.latest_start_step = max(1, min(W, round(flex.latest_start_step)));
flex.preferred_start_step = max(1, min(W, round(flex.preferred_start_step)));
for a = 1:n
    latestAllowed = max(1, W - flex.duration_steps(a) + 1);
    flex.earliest_start_step(a) = min(flex.earliest_start_step(a), latestAllowed);
    flex.latest_start_step(a) = min(max(flex.latest_start_step(a), flex.earliest_start_step(a)), latestAllowed);
    flex.preferred_start_step(a) = min(max(flex.preferred_start_step(a), 1), latestAllowed);
end
flex.count = n;
end

function flex = empty_flexibility()
% EMPTY_FLEXIBILITY Return empty flexibility struct.
flex = struct();
flex.count = 0;
flex.appliance = {};
flex.duration_steps = zeros(0, 1);
flex.power_w = zeros(0, 1);
flex.earliest_start_step = zeros(0, 1);
flex.latest_start_step = zeros(0, 1);
flex.preferred_start_step = zeros(0, 1);
flex.max_shift_steps = zeros(0, 1);
flex.weight = zeros(0, 1);
end

function ev = make_deterministic_ev(cfg, assignment, h, day, W, mode)
% MAKE_DETERMINISTIC_EV Deterministic daily EV metadata for scenarios.
ev = make_no_ev(W, cfg);
if ~is_household_ev_owner(assignment, h, mode.ev_penetration_override)
    return;
end
chargerType = assignment.charger_type{h};
if ~isempty(mode.charger_override)
    chargerType = mode.charger_override;
end
if strcmpi(chargerType, 'none') || isempty(chargerType)
    chargerType = 'slow';
end
if mode.v2g_enabled && strcmpi(chargerType, 'fast')
    chargerType = 'v2g';
end
batteryKwh = assignment.ev_battery_kwh(h);
if batteryKwh <= 0
    opts = cfg.ev.battery_kwh_options(:);
    batteryKwh = opts(mod(h - 1, numel(opts)) + 1);
end
stepsPerDay = W;
arrivalHr = cfg.ev.arrival_mean_hour + 0.5 * sin(0.7 * h + day);
departHr = cfg.ev.departure_mean_hour + 0.25 * cos(0.5 * h + day);
arrivalStep = max(1, min(stepsPerDay, round(arrivalHr * 60 / cfg.simulation.dt_min)));
departureStep = max(1, min(stepsPerDay, round(departHr * 60 / cfg.simulation.dt_min)));
avail = false(W, 1);
avail(arrivalStep:W) = true;
if departureStep > 1
    avail(1:departureStep) = true;
end
switch lower(chargerType)
    case 'slow'
        pCharge = cfg.ev.slow_kw * 1000;
        pV2G = 0;
    case 'fast'
        pCharge = cfg.ev.fast_kw * 1000;
        pV2G = 0;
    case 'v2g'
        pCharge = cfg.ev.fast_kw * 1000;
        pV2G = pCharge * double(mode.v2g_enabled && cfg.ev.v2g_enabled);
    otherwise
        pCharge = cfg.ev.slow_kw * 1000;
        pV2G = 0;
        chargerType = 'slow';
end
ev.present = true;
ev.available_steps = avail;
ev.arrival_step = arrivalStep;
ev.departure_step = departureStep;
ev.soc_initial = max(cfg.ev.soc_min_pct / 100, min(0.60, 0.35 + 0.15 * sin(h + day)));
ev.soc_target = cfg.ev.soc_target_pct / 100;
ev.battery_kwh = batteryKwh;
ev.P_charge_max_w = pCharge;
ev.P_v2g_max_w = pV2G;
ev.eta_c = cfg.ev.eta_charge;
ev.eta_d = cfg.ev.eta_discharge;
ev.energy_needed_wh = max(0, (ev.soc_target - ev.soc_initial) * batteryKwh * 1000 / ev.eta_c);
ev.charger_type = chargerType;
ev.harmonic_orders = [1 3 5 7 9 11 13];
ev.harmonic_spectrum = [1.0 0.70 0.40 0.25 0.15 0.10 0.08];
end

function ev = make_no_ev(W, cfg)
% MAKE_NO_EV Return empty EV struct.
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
end

function tf = is_household_ev_owner(assignment, h, penetrationOverride)
% IS_HOUSEHOLD_EV_OWNER Determine EV ownership for actual or forced penetration.
if isempty(penetrationOverride)
    tf = logical(assignment.has_ev(h));
else
    H = numel(assignment.household_id);
    nEv = round(max(0, min(1, penetrationOverride)) * H);
    tf = h <= nEv;
end
end

function L_ev = build_uncontrolled_ev_matrix(cfg, assignment, T, H, chargerOverride, penetrationOverride)
% BUILD_UNCONTROLLED_EV_MATRIX Create deterministic immediate EV charging load.
L_ev = zeros(T, H);
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
numDays = ceil(T / stepsPerDay);
mode = struct('ev_enabled', true, 'v2g_enabled', false, 'charger_override', chargerOverride, ...
    'ev_penetration_override', penetrationOverride, 'schedule_flexible_loads', false);
for day = 1:numDays
    idx = day_indices(day, stepsPerDay, T);
    W = numel(idx);
    for h = 1:H
        ev = make_deterministic_ev(cfg, assignment, h, day, W, mode);
        if ~ev.present
            continue;
        end
        remainingWh = max(0, ev.energy_needed_wh);
        pMax = max(0, ev.P_charge_max_w);
        if remainingWh <= 0 || pMax <= 0
            continue;
        end
        % Uncontrolled charging starts immediately at home arrival and continues
        % at charger rating until the daily energy target is met or the day ends.
        chargeOrder = ev.arrival_step:W;
        for kk = 1:numel(chargeOrder)
            t = chargeOrder(kk);
            if remainingWh <= 1e-6
                break;
            end
            whFromGrid = min(pMax * cfg.simulation.dt_hr, remainingWh / max(ev.eta_c, eps));
            L_ev(idx(t), h) = whFromGrid / cfg.simulation.dt_hr;
            remainingWh = remainingWh - whFromGrid * ev.eta_c;
        end
    end
end
end

function [S_series, L_feeder_w] = assemble_feeder_power_series(L_house_w, assignment, net, cfg)
% ASSEMBLE_FEEDER_POWER_SERIES Convert household loads to phase/bus complex power.
[T, H] = size(L_house_w);
S_series = complex(zeros(3, net.n_buses, T));
L_feeder_w = zeros(T, 3);
pf = 0.95;
if isfield(cfg, 'feeder') && isfield(cfg.feeder, 'load_power_factor')
    pf = cfg.feeder.load_power_factor;
end
qFactor = tan(acos(max(0.1, min(1.0, pf))));
for h = 1:H
    phaseId = max(1, min(3, round(double(assignment.phase_id(h)))));
    busId = max(1, min(net.n_buses, round(double(assignment.bus_id(h)))));
    p = max(0, double(L_house_w(:, h)));
    L_feeder_w(:, phaseId) = L_feeder_w(:, phaseId) + p;
    for t = 1:T
        S_series(phaseId, busId, t) = S_series(phaseId, busId, t) + complex(p(t), p(t) * qFactor);
    end
end
end

function [pq_timeseries, summary] = evaluate_scenario_pq(S_series, net, assignment, cfg, progress_cb, scenario_id)
% EVALUATE_SCENARIO_PQ Run BFS and PQ index calculation for every scenario step.
if nargin < 5 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end
if nargin < 6, scenario_id = NaN; end
T = size(S_series, 3);
pq_timeseries = cell(T, 1);
maxVuf = 0;
maxIuf = 0;
maxNcr = 0;
maxLoading = 0;
minVoltage = inf;
lossKw = zeros(T, 1);
lossKvar = zeros(T, 1);
viol = false(T, 1);
nonConv = false(T, 1);
for t = 1:T
    S = S_series(:, :, t);
    [V, I, In, ok] = bfs_power_flow(net, S, assignment);
    pq = compute_pq_indices(V, I, In, S, net, cfg);
    pq_timeseries{t} = pq;
    maxVuf = max(maxVuf, max(pq.VUF_pct));
    maxIuf = max(maxIuf, max(pq.IUF_pct));
    maxNcr = max(maxNcr, max(pq.NCR_pct));
    maxLoading = max(maxLoading, max(pq.TL_pct));
    minVoltage = min(minVoltage, pq.V_min_pu);
    lossKw(t) = pq.Ploss_kW;
    lossKvar(t) = pq.Qloss_kvar;
    nonConv(t) = ~ok;
    viol(t) = ~ok || pq.violations.vuf || pq.violations.voltage || pq.violations.loading || pq.violations.iuf || pq.violations.ncr;
    if mod(t, max(1, round(T/100))) == 0 || t == T
        progress_cb(50 + round(25 * t / max(T,1)), sprintf('Scenario %g: power flow step %d/%d | Vmin=%.3f pu | VUF=%.2f%%', scenario_id, t, T, minVoltage, maxVuf));
        drawnow('limitrate');
    end
end
summary = struct();
summary.max_vuf_pct = maxVuf;
summary.mean_vuf_pct = mean(cellfun(@(p) mean(p.VUF_pct), pq_timeseries));
summary.max_iuf_pct = maxIuf;
summary.max_ncr_pct = maxNcr;
summary.max_loading_pct = maxLoading;
summary.min_voltage_pu = minVoltage;
summary.mean_loss_kw = mean(lossKw);
summary.mean_loss_kvar = mean(lossKvar);
summary.violation_count = sum(viol);
summary.violation_steps = find(viol);
summary.non_converged_steps = find(nonConv);
summary.has_violations = any(viol);
end

function L_ev_per_bus = estimate_ev_harmonic_power_per_bus(cfg, assignment, net, L_house_w, mode)
% ESTIMATE_EV_HARMONIC_POWER_PER_BUS Estimate per-bus EV charger harmonic injection.
[~, H] = size(L_house_w);
L_ev_per_bus = zeros(1, net.n_buses);
for h = 1:H
    if ~is_household_ev_owner(assignment, h, mode.ev_penetration_override)
        continue;
    end
    if ~isfield(assignment, 'bus_id') || assignment.bus_id(h) < 1
        continue;
    end
    chargerType = assignment.charger_type{h};
    if ~isempty(mode.charger_override)
        chargerType = mode.charger_override;
    end
    if strcmpi(chargerType, 'none') || isempty(chargerType)
        chargerType = 'slow';
    end
    switch lower(chargerType)
        case 'slow'
            pRated = cfg.ev.slow_kw * 1000;
        otherwise
            pRated = cfg.ev.fast_kw * 1000;
    end
    b = max(1, min(net.n_buses, round(double(assignment.bus_id(h)))));
    % Use a conservative mean active charging proxy. It is intentionally
    % decoupled from base household demand so THD KPIs are not permanent zeros.
    pProxy = min(pRated, max(0, mean(max(0, L_house_w(:, h))) * 0.35));
    if pProxy < 1
        pProxy = 0.25 * pRated;
    end
    L_ev_per_bus(b) = L_ev_per_bus(b) + pProxy;
end
end

function [pq_timeseries, summary] = augment_harmonic_pq_series(pq_timeseries, summary, L_ev_per_bus, assignment, net, cfg)
% AUGMENT_HARMONIC_PQ_SERIES Add EV harmonic indices and update summary fields.
maxThdi = 0;
maxThdv = 0;
maxK = 1;
violThdi = false;
violThdv = false;
for t = 1:numel(pq_timeseries)
    if isempty(pq_timeseries{t})
        continue;
    end
    pq_timeseries{t} = compute_harmonic_pq(pq_timeseries{t}, L_ev_per_bus, assignment, net, cfg);
    maxThdi = max(maxThdi, max(pq_timeseries{t}.THDi_pct(:)));
    maxThdv = max(maxThdv, max(pq_timeseries{t}.THDv_pct(:)));
    maxK = max(maxK, max(pq_timeseries{t}.Kfactor(:)));
    if isfield(pq_timeseries{t}, 'violations')
        violThdi = violThdi || pq_timeseries{t}.violations.thdi;
        violThdv = violThdv || pq_timeseries{t}.violations.thdv;
    end
end
summary.max_thdi_pct = maxThdi;
summary.max_thdv_pct = maxThdv;
summary.max_kfactor = maxK;
summary.harmonic_thdi_violation = violThdi;
summary.harmonic_thdv_violation = violThdv;
summary.has_violations = summary.has_violations || violThdi || violThdv;
end

function comfortSummary = summarize_comfort(comfortValues, dispatchMode)
% SUMMARIZE_COMFORT Return mean/min/max CI.
vals = comfortValues(:);
vals = vals(isfinite(vals));
if isempty(vals)
    comfortSummary = struct('mean', NaN, 'min', NaN, 'max', NaN, 'count', 0, ...
        'note', sprintf('No comfort index for dispatch mode %s', dispatchMode));
else
    comfortSummary = struct('mean', mean(vals), 'min', min(vals), 'max', max(vals), ...
        'count', numel(vals), 'note', 'Comfort index from scheduled household controllers.');
end
end

function hostingPct = estimate_hosting_capacity(cfg, base, assignment, net, cal_eval, mode)
% ESTIMATE_HOSTING_CAPACITY Simple representative-step EV hosting estimate.
[T, H] = size(base.L_house_w);
steps = sample_steps_for_hosting(base.L_house_w, mode.hosting_sample_steps);
if isempty(steps)
    hostingPct = 0;
    return;
end
penList = 0:mode.hosting_step_pct:mode.hosting_max_pct;
hostingPct = 0;
for p = penList
    evMatrix = build_uncontrolled_ev_matrix(cfg, assignment, T, H, mode.charger_override, p / 100);
    L = base.L_house_w + evMatrix;
    [S, ~] = assemble_feeder_power_series(L(steps, :), assignment, net, cfg);
    [~, summary] = evaluate_scenario_pq(S, net, assignment, cfg);
    if ~summary.has_violations
        hostingPct = p;
    else
        break;
    end
end
if isempty(cal_eval) %#ok<INUSD>
    hostingPct = hostingPct;
end
end

function steps = sample_steps_for_hosting(L_house_w, maxSteps)
% SAMPLE_STEPS_FOR_HOSTING Select representative and peak loading steps.
T = size(L_house_w, 1);
if T <= maxSteps
    steps = (1:T)';
    return;
end
interval = max(1, floor(T / maxSteps));
steps = (1:interval:T)';
[~, peakIdx] = max(sum(L_house_w, 2));
steps = unique([steps; peakIdx]);
steps = steps(steps >= 1 & steps <= T);
end

function comparison = compare_slow_fast_uncontrolled(cfg, base, assignment, net, cal_eval, mode)
% COMPARE_SLOW_FAST_UNCONTROLLED Build Scenario 2 slow/fast comparison.
[T, H] = size(base.L_house_w);
comparison = struct();
for k = 1:2
    if k == 1
        label = 'slow';
    else
        label = 'fast';
    end
    L = base.L_house_w + build_uncontrolled_ev_matrix(cfg, assignment, T, H, label, mode.ev_penetration_override);
    [S, Lf] = assemble_feeder_power_series(L, assignment, net, cfg);
    [~, summary] = evaluate_scenario_pq(S, net, assignment, cfg);
    comparison.(label).pq_summary = summary;
    comparison.(label).L_feeder_w = Lf;
    comparison.(label).costs = compute_costs(cfg, L, cfg.simulation.tvec_min(1:T), cal_eval);
end
end

function idx = day_indices(day, stepsPerDay, T)
% DAY_INDICES Step indices for a simulation day.
a = (day - 1) * stepsPerDay + 1;
b = min(T, day * stepsPerDay);
idx = a:b;
end

function v = resize_vector(v, W, defaultValue)
% RESIZE_VECTOR Resize vector to W.
v = double(v(:));
if isempty(v)
    v = defaultValue * ones(W, 1);
elseif numel(v) < W
    v = [v; repmat(v(end), W - numel(v), 1)];
elseif numel(v) > W
    v = v(1:W);
end
v(~isfinite(v)) = defaultValue;
end

function M = resize_matrix_to(M, W, H, defaultValue)
% RESIZE_MATRIX_TO Resize matrix to W x H.
M = double(M);
if isempty(M)
    M = defaultValue * ones(W, H);
end
if size(M, 1) < W
    M = [M; repmat(M(end, :), W - size(M, 1), 1)];
elseif size(M, 1) > W
    M = M(1:W, :);
end
if size(M, 2) < H
    M = [M, defaultValue * ones(size(M, 1), H - size(M, 2))];
elseif size(M, 2) > H
    M = M(:, 1:H);
end
M(~isfinite(M)) = defaultValue;
end

function sch = strip_large_problem_field(sch)
% STRIP_LARGE_PROBLEM_FIELD Remove MILP matrices from stored scenario schedules.
if isfield(sch, 'problem')
    sch = rmfield(sch, 'problem');
end
end


function results = apply_result_storage_policy(results, cfg)
% APPLY_RESULT_STORAGE_POLICY Reduce scenario result size for normal thesis runs.
%
% storage_mode options:
%   lean  - recommended default; keep summaries, costs, and feeder-level load only.
%   full  - keep all internal fields for debugging and method development.
%   debug - same as full.

policy = default_result_policy();
if isfield(cfg, 'results') && isstruct(cfg.results)
    names = fieldnames(cfg.results);
    for k = 1:numel(names)
        policy.(names{k}) = cfg.results.(names{k});
    end
end

mode = char(string(get_policy_text(policy, 'storage_mode', 'lean')));
modeLower = lower(strtrim(mode));
if any(strcmp(modeLower, {'full','debug'}))
    results.metadata.storage_mode = modeLower;
    results.metadata.storage_note = 'Full/debug mode: large internal fields retained. MAT files may be several GB.';
    return;
end

results.metadata.storage_mode = 'lean';
results.metadata.storage_note = ['Lean mode: full internal PQ time-series, household matrices, ' ...
    'S-series, controller schedules, and price vectors are omitted from saved scenario results.'];

if ~get_policy_logical(policy, 'store_pq_timeseries', false) && isfield(results, 'pq_timeseries')
    results = rmfield(results, 'pq_timeseries');
end
if ~get_policy_logical(policy, 'store_household_timeseries', false) && isfield(results, 'L_house_w')
    results = rmfield(results, 'L_house_w');
end
if ~get_policy_logical(policy, 'store_s_series', false) && isfield(results, 'S_series')
    results = rmfield(results, 'S_series');
end
if ~get_policy_logical(policy, 'store_schedules', false) && isfield(results, 'schedules')
    results = rmfield(results, 'schedules');
end
if ~get_policy_logical(policy, 'store_price_series', false) && isfield(results, 'costs') && ...
        isstruct(results.costs) && isfield(results.costs, 'price_series')
    results.costs = rmfield(results.costs, 'price_series');
end
if ~get_policy_logical(policy, 'store_l_feeder_w', true) && isfield(results, 'L_feeder_w')
    results = rmfield(results, 'L_feeder_w');
end

if get_policy_logical(policy, 'use_single_precision_for_saved_timeseries', true)
    if isfield(results, 'L_feeder_w') && isnumeric(results.L_feeder_w)
        results.L_feeder_w = single(results.L_feeder_w);
    end
    if isfield(results, 'comparison') && isstruct(results.comparison)
        labels = fieldnames(results.comparison);
        for i = 1:numel(labels)
            label = labels{i};
            if isfield(results.comparison.(label), 'L_feeder_w') && isnumeric(results.comparison.(label).L_feeder_w)
                results.comparison.(label).L_feeder_w = single(results.comparison.(label).L_feeder_w);
            end
            if isfield(results.comparison.(label), 'costs') && isstruct(results.comparison.(label).costs) && ...
                    isfield(results.comparison.(label).costs, 'price_series') && ...
                    ~get_policy_logical(policy, 'store_price_series', false)
                results.comparison.(label).costs = rmfield(results.comparison.(label).costs, 'price_series');
            end
        end
    end
end
end

function policy = default_result_policy()
% DEFAULT_RESULT_POLICY Storage defaults used when cfg.results is absent.
policy = struct();
policy.storage_mode = 'lean';
policy.store_pq_timeseries = false;
policy.store_household_timeseries = false;
policy.store_s_series = false;
policy.store_schedules = false;
policy.store_price_series = false;
policy.store_l_feeder_w = true;
policy.use_single_precision_for_saved_timeseries = true;
end

function tf = get_policy_logical(policy, fieldName, defaultValue)
% GET_POLICY_LOGICAL Robust logical result policy read.
tf = defaultValue;
if isfield(policy, fieldName) && ~isempty(policy.(fieldName))
    v = policy.(fieldName);
    if islogical(v)
        tf = logical(v(1));
    elseif isnumeric(v)
        tf = v(1) ~= 0;
    elseif ischar(v) || isstring(v)
        tf = any(strcmpi(char(string(v)), {'true','yes','1','on'}));
    end
end
end

function txt = get_policy_text(policy, fieldName, defaultValue)
% GET_POLICY_TEXT Robust text result policy read.
txt = defaultValue;
if isfield(policy, fieldName) && ~isempty(policy.(fieldName))
    txt = char(string(policy.(fieldName)));
end
end

function value = getfield_safe(s, field1, field2, defaultValue)
% GETFIELD_SAFE Nested field read.
value = defaultValue;
if isstruct(s) && isfield(s, field1) && isstruct(s.(field1)) && isfield(s.(field1), field2)
    value = s.(field1).(field2);
end
end


function v = get_nested_number_local(s, fieldName, defaultValue)
% GET_NESTED_NUMBER_LOCAL Return scalar numeric field with default.
v = defaultValue;
try
    if isstruct(s) && isfield(s, fieldName) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
        v = double(s.(fieldName));
    end
catch
    v = defaultValue;
end
end

function tf = get_nested_logical_local(s, fieldName, defaultValue)
% GET_NESTED_LOGICAL_LOCAL Return logical field with default.
tf = defaultValue;
try
    if isstruct(s) && isfield(s, fieldName)
        raw = s.(fieldName);
        if islogical(raw)
            tf = logical(raw);
        elseif isnumeric(raw)
            tf = raw ~= 0;
        elseif ischar(raw) || isstring(raw)
            tf = any(strcmpi(char(string(raw)), {'true','1','yes','on'}));
        end
    end
catch
    tf = defaultValue;
end
end

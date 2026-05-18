function test_phase7_household_twin()
% TEST_PHASE7_HOUSEHOLD_TWIN Validate configurable HouseholdTwin behavior.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None.
%
% Outputs:
%   Prints PASS/FAIL assertions.
%
% Example:
%   test_phase7_household_twin()

fprintf('\n[test_phase7_household_twin] Starting Phase 7 HouseholdTwin tests...\n');
cfg = make_one_day_cfg(config_loader());
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

steps = 24 * 60 / cfg.simulation.dt_min;
weatherDay = 40 * ones(steps, 1);
calDay.daytype = uint8(0);
calDay.season = categorical("summer");
calDay.is_ramadan = false;
calDay.timestamp = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');

rng(77, 'twister');
twin = HouseholdTwin(1, assignment, data, cfg);
assert_pass(twin.phase_id == assignment.phase_id(1), sprintf('Constructor phase_id=%d', twin.phase_id));
assert_pass(twin.zone == assignment.zone(1), sprintf('Constructor zone=%d', twin.zone));
assert_pass(isfield(twin.config, 'household_id'), 'Twin config contains household metadata');

twin.generateDayProfile(calDay, weatherDay);
assert_pass(isfield(twin.daily_profile, 'p_total_w'), 'generateDayProfile created daily_profile.p_total_w');
assert_pass(numel(twin.daily_profile.p_total_w) == steps, sprintf('Daily profile length = %d steps', steps));
assert_pass(all(isfinite(twin.daily_profile.p_total_w)) && all(twin.daily_profile.p_total_w >= 0), 'Daily profile power is finite and nonnegative');

windows = twin.getFlexibilityWindows();
assert_pass(isfield(windows, 'count') && windows.count >= 0, sprintf('Flexibility API returned count=%d', windows.count));
assert_pass(isfield(windows, 'dt_min') && windows.dt_min == cfg.simulation.dt_min, 'Flexibility API exposes dt_min');

ev = twin.getEVStatus();
assert_pass(isfield(ev, 'present'), 'getEVStatus returned EV present field');

proj = twin.getProjectedLoad(8);
assert_pass(numel(proj.power_w) == 8, 'getProjectedLoad returned requested 8-step horizon');
assert_pass(all(isfinite(proj.power_w)), 'Projected load is finite');

twin.updateFromMeasurement(proj.power_w(1) + 100);
assert_pass(isfinite(twin.current_state.measurement_bias_w), sprintf('updateFromMeasurement bias=%.2f W', twin.current_state.measurement_bias_w));
assert_pass(twin.current_state.current_step == 2, 'updateFromMeasurement advances current_step');

% Use a deterministic synthetic flexibility case if the stochastic day produced
% no conflict-free controllable window. This validates the control API without
% depending on a random activity occurrence.
if windows.count == 0 || ~has_acceptance_candidate(twin)
    twin = inject_synthetic_flexibility(twin, cfg);
    windows = twin.getFlexibilityWindows();
end

badCmd = struct('appliance', windows.appliance{1}, 'new_start', max(1, windows.earliest_start_step(1) - 5));
[acceptedBad, ciBad, reasonBad] = twin.acceptDSMCommand(badCmd);
assert_pass(~acceptedBad, ['Out-of-window command rejected: ' reasonBad]);
assert_pass(ciBad >= 0 && ciBad <= 1, sprintf('Rejected command returns valid CI=%.3f', ciBad));

goodStart = choose_valid_start_without_overlap(twin, 1);
goodCmd = struct('appliance', windows.appliance{1}, 'new_start', goodStart);
[acceptedGood, ciGood, reasonGood] = twin.acceptDSMCommand(goodCmd);
assert_pass(acceptedGood, ['Valid command accepted: ' reasonGood]);
assert_pass(ciGood >= 0.30 && ciGood <= 1.0, sprintf('Accepted command comfort index %.3f', ciGood));
assert_pass(isfield(twin.daily_profile, 'p_commanded_w') && numel(twin.daily_profile.p_commanded_w) == steps, 'Accepted command updates commanded load vector');
assert_pass(twin.current_state.command_count >= 1, sprintf('Command log count=%d', twin.current_state.command_count));

fprintf('[test_phase7_household_twin] Complete. Phase 7 HouseholdTwin validation passed.\n');
end

function tf = has_acceptance_candidate(twin)
% HAS_ACCEPTANCE_CANDIDATE True when first flexible load has a conflict-free step.
try
    windows = twin.getFlexibilityWindows();
    if windows.count == 0
        tf = false;
        return;
    end
    choose_valid_start_without_overlap(twin, 1);
    tf = true;
catch
    tf = false;
end
end

function startStep = choose_valid_start_without_overlap(twin, idx)
% CHOOSE_VALID_START_WITHOUT_OVERLAP Find a comfort-safe, conflict-free command start.
%
% The command API enforces a minimum comfort index. A start time can be
% inside the flexibility window and conflict-free but still invalid when it is
% too far from the preferred start. Therefore the test must try candidates in
% preference-distance order instead of choosing the earliest valid window edge.
windows = twin.getFlexibilityWindows();
flex = twin.daily_profile.flexibility;
steps = numel(twin.daily_profile.p_total_w);
A = windows.count;

earliest = round(windows.earliest_start_step(idx));
latest = round(windows.latest_start_step(idx));
pref = round(flex.preferred_start_step(idx));
candidates = earliest:latest;
[~, order] = sort(abs(candidates - pref), 'ascend');
candidates = candidates(order);

for k = 1:numel(candidates)
    s = candidates(k);
    r1 = s:min(steps, s + round(windows.duration_steps(idx)) - 1);
    conflict = false;
    for a = 1:A
        if a == idx
            continue;
        end
        if isfield(twin.daily_profile, 'command_schedule') && isfield(twin.daily_profile.command_schedule, 'scheduled_start_step')
            s2 = round(twin.daily_profile.command_schedule.scheduled_start_step(a));
        else
            s2 = round(flex.preferred_start_step(a));
        end
        r2 = s2:min(steps, s2 + round(flex.duration_steps(a)) - 1);
        if any(ismember(r1, r2))
            conflict = true;
            break;
        end
    end
    if ~conflict
        startStep = s;
        return;
    end
end
error('test_phase7_household_twin:noCandidate', 'No comfort-safe conflict-free command start found.');
end

function twin = inject_synthetic_flexibility(twin, cfg)
% INJECT_SYNTHETIC_FLEXIBILITY Insert a deterministic one-load flexibility case.
steps = 24 * 60 / cfg.simulation.dt_min;
flex = struct();
flex.appliance = {'Washing_Machine'};
flex.preferred_start_step = 40;
flex.earliest_start_step = 32;
flex.latest_start_step = 48;
flex.duration_steps = 4;
flex.power_w = 600;
flex.max_shift_steps = 12;
flex.count = 1;

if ~isfield(twin.daily_profile, 'p_fixed_w') || isempty(twin.daily_profile.p_fixed_w)
    twin.daily_profile.p_fixed_w = 300 * ones(steps, 1);
end
if ~isfield(twin.daily_profile, 'p_total_w') || isempty(twin.daily_profile.p_total_w)
    twin.daily_profile.p_total_w = twin.daily_profile.p_fixed_w;
end
twin.daily_profile.flexibility = flex;
twin.daily_profile.command_schedule = struct();
twin.daily_profile.command_schedule.scheduled_start_step = flex.preferred_start_step;
twin.daily_profile.command_schedule.x = zeros(1, steps);
twin.daily_profile.command_schedule.x(1, flex.preferred_start_step) = 1;
twin.daily_profile.command_schedule.method = 'test_synthetic';
twin.daily_profile.command_schedule.flexibility = flex;
twin.daily_profile.p_commanded_w = twin.daily_profile.p_fixed_w;
activeIdx = flex.preferred_start_step:(flex.preferred_start_step + flex.duration_steps - 1);
twin.daily_profile.p_commanded_w(activeIdx) = twin.daily_profile.p_commanded_w(activeIdx) + flex.power_w;
end

function cfg = make_one_day_cfg(cfg)
cfg.simulation.start_date = '2025-07-07';
cfg.simulation.end_date = '2025-07-08';
cfg.simulation.d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.d2 = datetime(cfg.simulation.end_date, 'InputFormat', 'yyyy-MM-dd');
cfg.simulation.horizon_days = days(cfg.simulation.d2 - cfg.simulation.d1);
cfg.simulation.dt_hr = cfg.simulation.dt_min / 60;
cfg.simulation.Tsteps = cfg.simulation.horizon_days * 24 * 60 / cfg.simulation.dt_min;
cfg.simulation.tvec_min = (0:cfg.simulation.Tsteps - 1)' * cfg.simulation.dt_min;
cfg.output_dir = fullfile(cfg.root_folder, 'results');
cfg.figs_dir = fullfile(cfg.output_dir, 'figures');
cfg.tables_dir = fullfile(cfg.output_dir, 'tables');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase7_household_twin:assertionFailed', message);
end
end

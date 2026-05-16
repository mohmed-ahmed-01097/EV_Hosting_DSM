function events = generate_activities(occ_seq, act_data_hh, cal_day, cfg)
% GENERATE_ACTIVITIES Generate household activity events for one day.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   occ_seq (steps_per_day-by-1 uint8): Occupancy sequence where 1 means
%       home-awake.
%   act_data_hh (table): Activity rows for one household.
%   cal_day (struct): Day metadata with daytype, season, and Ramadan flags.
%   cfg (struct): Project configuration.
%
% Outputs:
%   events (struct array): Activity events with fields activity, start_step,
%       duration_steps, and start_hour.
%
% Example:
%   events = generate_activities(O, data.activities(idx,:), cal_day, cfg);

% --- Section 1: Validate inputs ---
validateattributes(occ_seq, {'numeric','logical'}, {'vector','nonempty'}, mfilename, 'occ_seq', 1);
validateattributes(act_data_hh, {'table'}, {}, mfilename, 'act_data_hh', 2);
validateattributes(cal_day, {'struct'}, {'scalar'}, mfilename, 'cal_day', 3);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 4);

stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
if numel(occ_seq) ~= stepsPerDay
    error('generate_activities:badOccupancyLength', 'occ_seq must contain one day of samples.');
end

emptyEvent = struct('activity', {}, 'start_step', {}, 'duration_steps', {}, 'start_hour', {});
events = emptyEvent;
if isempty(act_data_hh)
    return;
end

majorBusy = false(stepsPerDay, 1);
isWeekend = isfield(cal_day, 'daytype') && double(cal_day.daytype) > 0;
isRamadan = isfield(cal_day, 'is_ramadan') && logical(cal_day.is_ramadan);

% --- Section 2: Generate candidate events per activity row ---
for r = 1:height(act_data_hh)
    activity = char(string(act_data_hh.Activity(r)));
    dailyCount = sample_daily_count(act_data_hh, r, isWeekend);
    for k = 1:dailyCount
        startStep = sample_start_step(act_data_hh, r, activity, occ_seq, majorBusy, isRamadan, cfg);
        if isempty(startStep)
            continue;
        end
        durationSteps = sample_duration_steps(double(act_data_hh.Avg_Duration_min(r)), cfg);
        endStep = min(stepsPerDay, startStep + durationSteps - 1);
        if is_major_activity(activity)
            if any(majorBusy(startStep:endStep))
                startStep = find_alternate_slot(occ_seq, majorBusy, durationSteps);
                if isempty(startStep)
                    continue;
                end
                endStep = min(stepsPerDay, startStep + durationSteps - 1);
            end
            majorBusy(startStep:endStep) = true;
        end
        e.activity = activity;
        e.start_step = startStep;
        e.duration_steps = durationSteps;
        e.start_hour = (startStep - 1) * cfg.simulation.dt_min / 60;
        events(end + 1) = e; %#ok<AGROW>
    end
end

% --- Section 3: Sort by start step for deterministic downstream behavior ---
if ~isempty(events)
    [~, order] = sort([events.start_step]);
    events = events(order);
end
end

function dailyCount = sample_daily_count(T, rowIdx, isWeekend)
% SAMPLE_DAILY_COUNT Convert per-day/per-week frequency to event count.
freq = max(0, double(T.Frequency_Value(rowIdx)));
unit = lower(strtrim(char(string(T.Frequency_Unit(rowIdx)))));
if contains(unit, 'week')
    p = min(1, freq / 7);
    if isWeekend && ismember('Weekend_Different', T.Properties.VariableNames) && logical(T.Weekend_Different(rowIdx))
        p = min(1, 1.25 * p);
    end
    dailyCount = double(rand() < p);
else
    if isWeekend && ismember('Weekend_Different', T.Properties.VariableNames) && logical(T.Weekend_Different(rowIdx))
        freq = 1.15 * freq;
    end
    dailyCount = floor(freq) + double(rand() < (freq - floor(freq)));
end
dailyCount = max(0, min(4, dailyCount));
end

function startStep = sample_start_step(T, rowIdx, activity, occSeq, majorBusy, isRamadan, cfg)
% SAMPLE_START_STEP Choose an occupied start step using survey bins and priors.
stepsPerDay = numel(occSeq);
binEdges = [0 6 9 12 17 21 24];
cols = {'StartBin_00_06_%','StartBin_06_09_%','StartBin_09_12_%', ...
    'StartBin_12_17_%','StartBin_17_21_%','StartBin_21_24_%'};
weights = zeros(1, 6);
for i = 1:6
    weights(i) = double(T.(cols{i})(rowIdx));
end
weights = apply_egyptian_activity_bias(weights, activity, isRamadan);
weights(~isfinite(weights)) = 0;
weights = max(weights, 0);
if sum(weights) <= 0
    weights = ones(1, 6);
end
weights = weights ./ sum(weights);

binIdx = find(rand() <= cumsum(weights), 1, 'first');
if isempty(binIdx)
    binIdx = 6;
end
h0 = binEdges(binIdx);
h1 = binEdges(binIdx + 1);
step0 = max(1, floor(h0 * 60 / cfg.simulation.dt_min) + 1);
step1 = min(stepsPerDay, max(step0, ceil(h1 * 60 / cfg.simulation.dt_min)));

candidate = (step0:step1)';
homeAwake = occSeq(candidate) == 1;
notBusy = ~majorBusy(candidate);
candidate = candidate(homeAwake & notBusy);
if isempty(candidate)
    candidate = find(occSeq == 1 & ~majorBusy);
end
if isempty(candidate)
    startStep = [];
else
    startStep = candidate(randi(numel(candidate)));
end
end

function weights = apply_egyptian_activity_bias(weights, activity, isRamadan)
% APPLY_EGYPTIAN_ACTIVITY_BIAS Add soft Egyptian timing priors.
a = lower(strrep(activity, '_', ' '));
if contains(a, 'cook')
    weights = weights .* [0.6 1.3 0.9 1.4 1.5 0.8];
elseif contains(a, 'tv')
    weights = weights .* [0.2 0.2 0.3 0.7 1.8 1.9];
elseif contains(a, 'laundry')
    weights = weights .* [0.3 1.6 1.4 1.0 0.7 0.4];
elseif contains(a, 'shower')
    weights = weights .* [0.6 1.6 0.6 0.4 1.0 1.4];
elseif contains(a, 'iron')
    weights = weights .* [0.2 0.7 1.1 1.0 1.4 1.1];
elseif contains(a, 'dishwasher')
    weights = weights .* [0.2 0.4 0.5 0.7 1.4 1.6];
elseif contains(a, 'computer') || contains(a, 'work')
    weights = weights .* [0.2 0.7 1.5 1.5 1.0 0.5];
end
if isRamadan
    weights = weights .* [1.4 0.8 0.7 0.8 1.3 1.7];
end
end

function durationSteps = sample_duration_steps(avgDurationMin, cfg)
% SAMPLE_DURATION_STEPS Draw a truncated normal-like duration.
if ~isfinite(avgDurationMin) || avgDurationMin <= 0
    avgDurationMin = cfg.simulation.dt_min;
end
sigma = 0.25 * avgDurationMin;
durationMin = avgDurationMin + sigma * randn();
durationMin = min(2.0 * avgDurationMin, max(0.5 * avgDurationMin, durationMin));
durationSteps = max(1, round(durationMin / cfg.simulation.dt_min));
end

function tf = is_major_activity(activity)
% IS_MAJOR_ACTIVITY True for events that should not overlap.
a = lower(strrep(activity, '_', ' '));
tf = contains(a, 'cook') || contains(a, 'laundry') || contains(a, 'iron') || contains(a, 'shower');
end

function startStep = find_alternate_slot(occSeq, busy, durationSteps)
% FIND_ALTERNATE_SLOT Find a non-overlapping occupied slot.
candidates = find(occSeq == 1);
startStep = [];
for i = 1:numel(candidates)
    s = candidates(i);
    e = min(numel(occSeq), s + durationSteps - 1);
    if e - s + 1 < durationSteps
        continue;
    end
    if ~any(busy(s:e))
        startStep = s;
        return;
    end
end
end

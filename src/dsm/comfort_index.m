function [CI, CI_per_appliance] = comfort_index(schedule, flexibility, cfg)
% COMFORT_INDEX Compute household DSM comfort index.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   schedule (struct): DSM schedule from run_household_milp or rule_based_controller.
%   flexibility (struct): Controllable-load flexibility metadata.
%   cfg (struct): Project configuration.
%
% Outputs:
%   CI (double): Aggregate comfort index in [0,1].
%   CI_per_appliance (struct): Per-appliance penalties and comfort scores.
%
% Example:
%   [CI, detail] = comfort_index(schedule, hh.flexibility, cfg);

% --- Section 1: Validate and handle empty flexibility ---
validateattributes(schedule, {'struct'}, {'scalar'}, mfilename, 'schedule', 1);
validateattributes(flexibility, {'struct'}, {'scalar'}, mfilename, 'flexibility', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

A = get_flex_count(flexibility);
CI_per_appliance = struct();
CI_per_appliance.appliance = {};
CI_per_appliance.scheduled_start_step = [];
CI_per_appliance.preferred_start_step = [];
CI_per_appliance.max_shift_steps = [];
CI_per_appliance.weight = [];
CI_per_appliance.penalty = [];
CI_per_appliance.comfort = [];

if A == 0
    CI = 1.0;
    return;
end

% --- Section 2: Extract scheduled start steps ---
scheduledStart = nan(A, 1);
if isfield(schedule, 'scheduled_start_step') && numel(schedule.scheduled_start_step) >= A
    scheduledStart = double(schedule.scheduled_start_step(:));
    scheduledStart = scheduledStart(1:A);
elseif isfield(schedule, 'x') && ~isempty(schedule.x)
    x = double(schedule.x);
    for a = 1:min(A, size(x, 1))
        [~, scheduledStart(a)] = max(x(a, :));
    end
end

% --- Section 3: Weighted normalized shift penalty ---
penalties = zeros(A, 1);
weights = zeros(A, 1);
comfortScores = zeros(A, 1);
for a = 1:A
    appl = flexibility.appliance{a};
    pref = double(flexibility.preferred_start_step(a));
    maxShift = max(1, double(flexibility.max_shift_steps(a)));
    wt = get_appliance_weight(appl, cfg);
    if ~isfinite(scheduledStart(a)) || scheduledStart(a) <= 0
        shiftRatio = 1;
    else
        shiftRatio = abs(double(scheduledStart(a)) - pref) / maxShift;
    end
    shiftRatio = min(1, max(0, shiftRatio));
    penalties(a) = wt * shiftRatio;
    weights(a) = wt;
    comfortScores(a) = 1 - shiftRatio;

    CI_per_appliance.appliance{a, 1} = appl;
    CI_per_appliance.scheduled_start_step(a, 1) = scheduledStart(a);
    CI_per_appliance.preferred_start_step(a, 1) = pref;
    CI_per_appliance.max_shift_steps(a, 1) = maxShift;
    CI_per_appliance.weight(a, 1) = wt;
    CI_per_appliance.penalty(a, 1) = penalties(a);
    CI_per_appliance.comfort(a, 1) = comfortScores(a);
end

CI = 1 - sum(penalties) / max(sum(weights), eps);
CI = min(1, max(0, CI));
end

function A = get_flex_count(flexibility)
% GET_FLEX_COUNT Return number of controllable appliances.
if isfield(flexibility, 'count')
    A = double(flexibility.count);
elseif isfield(flexibility, 'appliance')
    A = numel(flexibility.appliance);
else
    A = 0;
end
end

function wt = get_appliance_weight(applianceName, cfg)
% GET_APPLIANCE_WEIGHT Read configured comfort weight with safe fallback.
wt = 1.0;
if ~isfield(cfg, 'dsm') || ~isfield(cfg.dsm, 'comfort_weights')
    return;
end
key = matlab.lang.makeValidName(char(applianceName));
if isfield(cfg.dsm.comfort_weights, key)
    wt = double(cfg.dsm.comfort_weights.(key));
end
if ~isfinite(wt) || wt <= 0
    wt = 1.0;
end
end

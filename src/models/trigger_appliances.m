function runs = trigger_appliances(events, appliances_hh, cfg)
% TRIGGER_APPLIANCES Map activity events to appliance runs.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   events (struct array): Activity events from generate_activities.
%   appliances_hh (table): Appliance inventory rows for one household.
%   cfg (struct): Project configuration.
%
% Outputs:
%   runs (struct array): Appliance usage runs with fields appliance,
%       start_step, end_step, power_w, is_controllable,
%       flexibility_window_steps, preferred_start_step, and duration_steps.
%
% Example:
%   runs = trigger_appliances(events, appl_hh, cfg);

% --- Section 1: Validate inputs ---
validateattributes(events, {'struct'}, {}, mfilename, 'events', 1);
validateattributes(appliances_hh, {'table'}, {}, mfilename, 'appliances_hh', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

runs = struct('appliance', {}, 'start_step', {}, 'end_step', {}, 'power_w', {}, ...
    'is_controllable', {}, 'flexibility_window_steps', {}, ...
    'preferred_start_step', {}, 'duration_steps', {});
if isempty(events) || isempty(appliances_hh)
    return;
end

% --- Section 2: Activity-to-appliance mapping ---
for i = 1:numel(events)
    applianceNames = map_activity_to_appliances(events(i).activity);
    for j = 1:numel(applianceNames)
        row = find_appliance_row(appliances_hh, applianceNames{j});
        if isempty(row)
            continue;
        end
        count = max(1, double(appliances_hh.Count(row(1))));
        if count <= 0
            continue;
        end
        powerW = double(appliances_hh.Rated_Power_W(row(1)));
        if ~isfinite(powerW) || powerW <= 0
            continue;
        end
        durationSteps = max(1, events(i).duration_steps);
        if strcmpi(applianceNames{j}, 'Microwave')
            durationSteps = min(durationSteps, max(1, round(10 / cfg.simulation.dt_min)));
        end
        run.appliance = char(applianceNames{j});
        run.start_step = max(1, events(i).start_step);
        run.end_step = run.start_step + durationSteps - 1;
        run.power_w = powerW * count;
        run.is_controllable = logical(appliances_hh.Is_Controllable(row(1)));
        run.flexibility_window_steps = max(0, round(double(appliances_hh.Flexibility_Window_hr(row(1))) * 60 / cfg.simulation.dt_min));
        preferredHr = double(appliances_hh.Preferred_Start_hr(row(1)));
        if ~isfinite(preferredHr) || preferredHr < 0
            preferredHr = events(i).start_hour;
        end
        run.preferred_start_step = max(1, round(preferredHr * 60 / cfg.simulation.dt_min) + 1);
        run.duration_steps = durationSteps;
        runs(end + 1) = run; %#ok<AGROW>
    end
end
end

function names = map_activity_to_appliances(activity)
% MAP_ACTIVITY_TO_APPLIANCES Return preferred appliance names for activity.
a = lower(strrep(char(activity), '_', ' '));
if contains(a, 'cook')
    names = {'Oven','Microwave','Kettle'};
elseif contains(a, 'laundry')
    names = {'Washing_Machine'};
elseif contains(a, 'iron')
    names = {'Iron'};
elseif contains(a, 'dishwasher')
    names = {'Dishwasher'};
elseif contains(a, 'tv')
    names = {'Television'};
elseif contains(a, 'computer') || contains(a, 'work')
    names = {'Computer'};
elseif contains(a, 'shower')
    names = {'Water_Heater'};
else
    names = {};
end
end

function idx = find_appliance_row(T, wanted)
% FIND_APPLIANCE_ROW Case-insensitive appliance lookup.
names = lower(strrep(string(T.Appliance), ' ', '_'));
key = lower(strrep(string(wanted), ' ', '_'));
idx = find(names == key & double(T.Count) > 0, 1, 'first');
if isempty(idx) && contains(key, 'television')
    idx = find(contains(names, 'tv') & double(T.Count) > 0, 1, 'first');
end
if isempty(idx) && contains(key, 'washing')
    idx = find(contains(names, 'washing') & double(T.Count) > 0, 1, 'first');
end
end

function flexibility = extract_flexibility(runs, cfg)
% EXTRACT_FLEXIBILITY Build DSM flexibility metadata from controllable runs.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   runs (struct array): Appliance runs from trigger_appliances.
%   cfg (struct): Project configuration.
%
% Outputs:
%   flexibility (struct): Controllable run metadata with fields appliance,
%       preferred_start_step, earliest_start_step, latest_start_step,
%       duration_steps, power_w, max_shift_steps, and count.
%
% Example:
%   flex = extract_flexibility(runs, cfg);

validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 2);
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
flexibility = struct();
flexibility.appliance = {};
flexibility.preferred_start_step = [];
flexibility.earliest_start_step = [];
flexibility.latest_start_step = [];
flexibility.duration_steps = [];
flexibility.power_w = [];
flexibility.max_shift_steps = [];

for i = 1:numel(runs)
    if ~runs(i).is_controllable
        continue;
    end
    maxShift = max(0, runs(i).flexibility_window_steps);
    preferred = runs(i).preferred_start_step;
    duration = runs(i).duration_steps;
    earliest = max(1, preferred - maxShift);
    latest = min(stepsPerDay - duration + 1, preferred + maxShift);
    flexibility.appliance{end + 1, 1} = runs(i).appliance; %#ok<AGROW>
    flexibility.preferred_start_step(end + 1, 1) = preferred; %#ok<AGROW>
    flexibility.earliest_start_step(end + 1, 1) = earliest; %#ok<AGROW>
    flexibility.latest_start_step(end + 1, 1) = latest; %#ok<AGROW>
    flexibility.duration_steps(end + 1, 1) = duration; %#ok<AGROW>
    flexibility.power_w(end + 1, 1) = runs(i).power_w; %#ok<AGROW>
    flexibility.max_shift_steps(end + 1, 1) = maxShift; %#ok<AGROW>
end
flexibility.count = numel(flexibility.appliance);
end

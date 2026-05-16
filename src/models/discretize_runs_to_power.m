function [p_total, p_controllable, p_fixed] = discretize_runs_to_power(runs, standby_w, steps_per_day, cfg)
% DISCRETIZE_RUNS_TO_POWER Convert appliance runs to dense daily profiles.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   runs (struct array): Appliance runs from trigger_appliances.
%   standby_w (double): Always-on standby load [W].
%   steps_per_day (integer): Number of samples in one day.
%   cfg (struct): Project configuration.
%
% Outputs:
%   p_total (steps_per_day-by-1 double): Total appliance profile [W].
%   p_controllable (steps_per_day-by-1 double): Shiftable component [W].
%   p_fixed (steps_per_day-by-1 double): Non-controllable component [W].
%
% Example:
%   [p, pc, pf] = discretize_runs_to_power(runs, standby, 96, cfg);

% --- Section 1: Validate inputs ---
validateattributes(standby_w, {'numeric'}, {'scalar','nonnegative'}, mfilename, 'standby_w', 2);
validateattributes(steps_per_day, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'steps_per_day', 3);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 4);

p_total = standby_w * ones(steps_per_day, 1);
p_controllable = zeros(steps_per_day, 1);
p_fixed = p_total;

% --- Section 2: Insert each appliance profile ---
for i = 1:numel(runs)
    s = max(1, runs(i).start_step);
    if s > steps_per_day
        continue;
    end
    durationSteps = max(1, runs(i).duration_steps);
    profile = run_appliance_profile(runs(i).appliance, durationSteps, runs(i).power_w, cfg);
    e = min(steps_per_day, s + numel(profile) - 1);
    n = e - s + 1;
    if n <= 0
        continue;
    end
    p_total(s:e) = p_total(s:e) + profile(1:n);
    if runs(i).is_controllable
        p_controllable(s:e) = p_controllable(s:e) + profile(1:n);
    else
        p_fixed(s:e) = p_fixed(s:e) + profile(1:n);
    end
end
end

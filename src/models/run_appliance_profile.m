function profile_w = run_appliance_profile(appliance_name, duration_steps, power_w, cfg)
% RUN_APPLIANCE_PROFILE Generate a finite-state appliance power profile.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   appliance_name (char/string): Appliance identifier.
%   duration_steps (integer): Requested duration in simulation steps.
%   power_w (double): Rated active power in watts.
%   cfg (struct): Project configuration.
%
% Outputs:
%   profile_w (duration_steps-by-1 double): Appliance active power profile [W].
%
% Example:
%   p = run_appliance_profile('Washing_Machine', 8, 800, cfg);

% --- Section 1: Validate inputs and constants ---
validateattributes(duration_steps, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'duration_steps', 2);
validateattributes(power_w, {'numeric'}, {'scalar','nonnegative'}, mfilename, 'power_w', 3);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 4);

if isfield(cfg.simulation, 'fsm_power_cv_default')
    cv = cfg.simulation.fsm_power_cv_default;
else
    cv = 0.10;
end
name = lower(strrep(char(string(appliance_name)), ' ', '_'));
N = duration_steps;
profile_w = zeros(N, 1);

% --- Section 2: Appliance finite-state models ---
if contains(name, 'washing')
    pattern = [0.8 * ones(min(3,N),1); 1.2 * ones(min(5,max(N-3,0)),1)];
    if numel(pattern) < N
        remaining = N - numel(pattern);
        cycle = repmat([0.3;0.3;0.7;0.2], ceil(remaining/4), 1);
        pattern = [pattern; cycle(1:remaining)];
    end
    profile_w = power_w * pattern(1:N);
elseif contains(name, 'oven')
    preheat = min(4, N);
    profile_w(1:preheat) = power_w;
    if preheat < N
        profile_w(preheat+1:N) = 0.6 * power_w;
    end
elseif contains(name, 'water_heater') || contains(name, 'heater')
    heatSteps = min(max(2, round(0.45 * N)), N);
    profile_w(1:heatSteps) = power_w;
    if heatSteps < N
        profile_w(heatSteps+1:N) = 0.05 * power_w;
    end
elseif contains(name, 'iron')
    heatSteps = min(2, N);
    profile_w(1:heatSteps) = power_w;
    if heatSteps < N
        profile_w(heatSteps+1:N) = 0.4 * power_w;
    end
elseif contains(name, 'refrigerator') || contains(name, 'freezer')
    cycle = repmat([0.3;0.0;0.3;0.0], ceil(N/4), 1);
    profile_w = power_w * cycle(1:N);
else
    profile_w(:) = power_w;
end

% --- Section 3: Stochastic power variation with non-negative clipping ---
noise = 1 + cv * randn(N, 1);
profile_w = max(0, profile_w .* noise);
end

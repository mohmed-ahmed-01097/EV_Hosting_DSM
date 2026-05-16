function O = simulate_occupancy(occ_pmf_hh, cal_day, cfg)
% SIMULATE_OCCUPANCY Generate one-day occupancy states from survey PMFs.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   occ_pmf_hh (table): Rows from OccupancyPMF for one household. Required
%       columns: Hour, Day_Type, P_Away, P_Home_Awake, P_Asleep.
%   cal_day (struct): Day metadata with fields daytype and is_ramadan.
%   cfg (struct): Project configuration from config_loader.
%
% Outputs:
%   O (steps_per_day-by-1 uint8): Occupancy state vector.
%       0 = Away, 1 = Home-Awake, 2 = Asleep.
%
% Example:
%   O = simulate_occupancy(data.occ_pmf(idx,:), cal_day, cfg);

% --- Section 1: Validate inputs and constants ---
validateattributes(occ_pmf_hh, {'table'}, {'nonempty'}, mfilename, 'occ_pmf_hh', 1);
validateattributes(cal_day, {'struct'}, {'scalar'}, mfilename, 'cal_day', 2);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 3);

stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
persistence = 0.85;
requiredVars = {'Hour','Day_Type','P_Away','P_Home_Awake','P_Asleep'};
for i = 1:numel(requiredVars)
    if ~ismember(requiredVars{i}, occ_pmf_hh.Properties.VariableNames)
        error('simulate_occupancy:missingColumn', 'Missing OccupancyPMF column: %s', requiredVars{i});
    end
end

% --- Section 2: Initialize from hour-zero PMF ---
O = zeros(stepsPerDay, 1, 'uint8');
dayType = get_daytype_code(cal_day);
isRamadan = isfield(cal_day, 'is_ramadan') && logical(cal_day.is_ramadan);
pmf0 = get_occ_pmf_for_hour(occ_pmf_hh, 0, dayType, isRamadan);
O(1) = sample_from_pmf(pmf0);

% --- Section 3: Time-inhomogeneous Markov simulation ---
for t = 2:stepsPerDay
    hourNow = floor((t - 1) * cfg.simulation.dt_min / 60);
    targetPmf = get_occ_pmf_for_hour(occ_pmf_hh, hourNow, dayType, isRamadan);
    if rand() < persistence
        O(t) = O(t - 1);
    else
        O(t) = sample_from_pmf(targetPmf);
    end
end
end

function dayType = get_daytype_code(cal_day)
% GET_DAYTYPE_CODE Extract uint8 day type code from cal_day.
if isfield(cal_day, 'daytype')
    dayType = double(cal_day.daytype);
else
    dayType = 0;
end
if dayType < 0 || dayType > 2
    dayType = 0;
end
end

function pmf = get_occ_pmf_for_hour(T, hourNow, dayType, isRamadan)
% GET_OCC_PMF_FOR_HOUR Return normalized [away home_awake asleep].
lookupHour = hourNow;
if isRamadan
    % Shift the sleep/wake behavioral lookup two hours later.
    lookupHour = mod(hourNow - 2, 24);
end

rows = T(double(T.Hour) == lookupHour & double(T.Day_Type) == dayType, :);
if isempty(rows) && dayType == 2
    rows = T(double(T.Hour) == lookupHour & double(T.Day_Type) == 1, :);
end
if isempty(rows)
    rows = T(double(T.Hour) == lookupHour, :);
end
if isempty(rows)
    pmf = [0.20, 0.55, 0.25];
else
    pmf = [mean(double(rows.P_Away), 'omitnan'), ...
           mean(double(rows.P_Home_Awake), 'omitnan'), ...
           mean(double(rows.P_Asleep), 'omitnan')];
end

if isRamadan
    if hourNow >= 19 && hourNow <= 23
        pmf = [pmf(1) * 0.75, pmf(2) * 1.25, pmf(3) * 0.65];
    elseif hourNow >= 0 && hourNow <= 2
        pmf = [pmf(1) * 0.80, pmf(2) * 1.20, pmf(3) * 0.85];
    elseif hourNow >= 7 && hourNow <= 9
        pmf = [pmf(1) * 0.85, pmf(2) * 0.85, pmf(3) * 1.35];
    end
end

pmf(~isfinite(pmf)) = 0;
pmf = max(pmf, 0);
if sum(pmf) <= 0
    pmf = [0.20, 0.55, 0.25];
else
    pmf = pmf ./ sum(pmf);
end
end

function state = sample_from_pmf(pmf)
% SAMPLE_FROM_PMF Draw state code 0/1/2 from probability vector.
cdf = cumsum(pmf(:));
r = rand();
idx = find(r <= cdf, 1, 'first');
if isempty(idx)
    idx = 3;
end
state = uint8(idx - 1);
end

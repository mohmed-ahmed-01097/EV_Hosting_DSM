function hh = simulate_household(h_idx, assignment, data, weather_day, cal_day, cfg)
% SIMULATE_HOUSEHOLD Simulate one household for one day.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   h_idx (integer): Household index in assignment, 1..H.
%   assignment (struct): Household assignment from assign_households.
%   data (struct): Survey data from data_loader.
%   weather_day (steps-by-1 double): Outdoor temperature for one day [deg C].
%   cal_day (struct): Day metadata.
%   cfg (struct): Project configuration.
%
% Outputs:
%   hh (struct): Daily household simulation result with fields p_total_w,
%       p_fixed_w, p_controllable_w, p_hvac_w, p_standby_w, ev,
%       flexibility, occupancy, household_id, phase_id, zone, and survey_row.
%
% Example:
%   hh = simulate_household(1, assignment, data, weatherDay, cal_day, cfg);

% --- Section 1: Validate inputs and lookup survey rows ---
validateattributes(h_idx, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'h_idx', 1);
validateattributes(assignment, {'struct'}, {'scalar'}, mfilename, 'assignment', 2);
validateattributes(data, {'struct'}, {'scalar'}, mfilename, 'data', 3);
validateattributes(weather_day, {'numeric'}, {'vector','nonempty'}, mfilename, 'weather_day', 4);
validateattributes(cal_day, {'struct'}, {'scalar'}, mfilename, 'cal_day', 5);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 6);

steps = 24 * 60 / cfg.simulation.dt_min;
if numel(weather_day) ~= steps
    error('simulate_household:badWeatherLength', 'weather_day must contain one day of samples.');
end

if h_idx > numel(assignment.survey_row)
    error('simulate_household:badHouseholdIndex', 'h_idx exceeds assignment length.');
end
sr = assignment.survey_row(h_idx);
householdId = string(data.household.Household_ID(sr));

occRows = data.occ_pmf(string(data.occ_pmf.Household_ID) == householdId, :);
actRows = data.activities(string(data.activities.Household_ID) == householdId, :);
applRows = data.appliances(string(data.appliances.Household_ID) == householdId, :);
hvacRows = data.hvac(string(data.hvac.Household_ID) == householdId, :);
if isempty(occRows)
    error('simulate_household:missingOccupancyRows', 'No OccupancyPMF rows for household %s.', householdId);
end
if isempty(hvacRows)
    hvacRows = data.hvac(1, :);
    hvacRows.AC_Present(1) = false;
end

% --- Section 2: Occupancy, activities, appliance runs ---
hh = struct();
hh.occupancy = simulate_occupancy(occRows, cal_day, cfg);
events = generate_activities(hh.occupancy, actRows, cal_day, cfg);
runs = trigger_appliances(events, applRows, cfg);

standbyW = compute_standby_power(applRows);
[hh.p_total_w, hh.p_controllable_w, hh.p_fixed_w] = discretize_runs_to_power(runs, standbyW, steps, cfg);

% --- Section 3: HVAC and EV modules ---
hh.p_hvac_w = hvac_power_model(hh.occupancy, weather_day(:), hvacRows, cal_day, cfg);
hh.p_total_w = hh.p_total_w + hh.p_hvac_w;
hh.p_fixed_w = hh.p_fixed_w + hh.p_hvac_w;

hh.ev = ev_model(assignment.has_ev(h_idx), assignment.charger_type{h_idx}, ...
    assignment.ev_battery_kwh(h_idx), cal_day, cfg);

% --- Section 4: Metadata and integrity checks ---
hh.flexibility = extract_flexibility(runs, cfg);
hh.events = events;
hh.runs = runs;
hh.household_id = h_idx;
hh.phase_id = assignment.phase_id(h_idx);
hh.zone = assignment.zone(h_idx);
hh.bus_id = assignment.bus_id(h_idx);
hh.survey_row = sr;
hh.p_standby_w = standbyW;

if any(~isfinite(hh.p_total_w)) || any(hh.p_total_w < 0)
    error('simulate_household:invalidPower', 'Generated non-finite or negative household power.');
end
end

function standbyW = compute_standby_power(applRows)
% COMPUTE_STANDBY_POWER Sum always-on standby power.
standbyW = 0;
if isempty(applRows)
    return;
end
if ismember('Standby_Always_On', applRows.Properties.VariableNames)
    mask = logical(applRows.Standby_Always_On);
else
    mask = double(applRows.Standby_W) > 0;
end
standbyW = sum(double(applRows.Standby_W(mask)) .* double(applRows.Count(mask)), 'omitnan');
standbyW = max(0, standbyW);
end

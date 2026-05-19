function pop = simulate_population(cfg, data, assignment, net, cal_struct, weather, progress_cb)
% SIMULATE_POPULATION Simulate household profiles over the configured period.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Project configuration.
%   data (struct): Survey data.
%   assignment (struct): Household-to-zone/phase/bus assignment.
%   net (struct): Feeder network. Included for interface consistency.
%   cal_struct (struct): Calendar vectors from daytype_calendar.
%   weather (struct): Weather vectors from get_weather.
%
% Outputs:
%   pop (struct): Population load matrices and metadata.
%
% Example:
%   pop = simulate_population(cfg, data, assignment, net, cal, weather);
%   pop = simulate_population(cfg, data, assignment, net, cal, weather, @(p,m) fprintf('%d%% %s\n',p,m));

% --- Section 1: Validate inputs and cache ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
validateattributes(data, {'struct'}, {'scalar'}, mfilename, 'data', 2);
validateattributes(assignment, {'struct'}, {'scalar'}, mfilename, 'assignment', 3);
validateattributes(net, {'struct'}, {'scalar'}, mfilename, 'net', 4); %#ok<INUSD>
validateattributes(cal_struct, {'struct'}, {'scalar'}, mfilename, 'cal_struct', 5);
validateattributes(weather, {'struct'}, {'scalar'}, mfilename, 'weather', 6);
if nargin < 7 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg) [];
end

H = cfg.feeder.num_households;
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
Tsteps = cfg.simulation.Tsteps;
numDays = cfg.simulation.horizon_days;
cacheFile = fullfile(cfg.output_dir, 'population_profiles.mat');
modelVersion = 'phase2_ev_feasible_v2';
configHash = build_population_hash(cfg, assignment, modelVersion);

if isfile(cacheFile)
    cached = load(cacheFile, 'pop');
    if isfield(cached, 'pop') && isfield(cached.pop, 'metadata') && ...
            isfield(cached.pop.metadata, 'config_hash') && strcmp(cached.pop.metadata.config_hash, configHash)
        pop = cached.pop;
        progress_cb(100, sprintf('Loaded cached population profiles: %s', cacheFile));
        drawnow('limitrate');
        fprintf('[simulate_population] Loaded cached population profiles: %s\n', cacheFile);
        return;
    end
end

% --- Section 2: Preallocate outputs ---
pop = struct();
pop.L_house_w = zeros(Tsteps, H);
pop.L_fixed_w = zeros(Tsteps, H);
pop.L_ctrl_w = zeros(Tsteps, H);
pop.L_hvac_w = zeros(Tsteps, H);
pop.EV = cell(H, 1);
pop.flexibility = cell(H, 1);

fprintf('[simulate_population] Simulating %d households x %d days at dt=%d min...\n', ...
    H, numDays, cfg.simulation.dt_min);

% --- Section 3: Day-by-day, household-by-household simulation ---
for day = 1:numDays
    pct = round(100 * day / max(numDays, 1));
    progress_cb(pct, sprintf('Simulating day %d / %d', day, numDays));
    drawnow('limitrate');
    if mod(day, 10) == 0 || day == 1 || day == numDays
        fprintf('  [simulate_population] Day %d / %d\n', day, numDays);
    end
    tStart = (day - 1) * stepsPerDay + 1;
    tEnd = day * stepsPerDay;
    calDay = build_cal_day(cal_struct, tStart);
    weatherDay = weather.temp_C(tStart:tEnd);
    for h = 1:H
        hh = simulate_household(h, assignment, data, weatherDay, calDay, cfg);
        pop.L_house_w(tStart:tEnd, h) = hh.p_total_w;
        pop.L_fixed_w(tStart:tEnd, h) = hh.p_fixed_w;
        pop.L_ctrl_w(tStart:tEnd, h) = hh.p_controllable_w;
        pop.L_hvac_w(tStart:tEnd, h) = hh.p_hvac_w;
        if day == 1
            pop.EV{h} = hh.ev;
            pop.flexibility{h} = hh.flexibility;
        end
    end
end

% --- Section 4: Metadata and cache save ---
pop.metadata.config_hash = configHash;
pop.metadata.model_version = modelVersion;
pop.metadata.created_on = datestr(now, 31);
pop.metadata.dt_min = cfg.simulation.dt_min;
pop.metadata.num_households = H;
pop.metadata.num_days = numDays;
pop.metadata.energy_kwh_total = sum(pop.L_house_w(:)) * cfg.simulation.dt_hr / 1000;

save(cacheFile, 'pop', '-v7.3');
progress_cb(100, sprintf('Population simulation complete. Saved to %s', cacheFile));
drawnow('limitrate');
fprintf('[simulate_population] Done. Saved to %s | total energy %.1f kWh\n', ...
    cacheFile, pop.metadata.energy_kwh_total);
end

function calDay = build_cal_day(calStruct, idx)
% BUILD_CAL_DAY Extract scalar day metadata at simulation index idx.
calDay = struct();
calDay.daytype = calStruct.daytype(idx);
calDay.season = calStruct.season(idx);
calDay.is_ramadan = calStruct.is_ramadan(idx);
calDay.timestamp = calStruct.timestamps(idx);
end

function hash = build_population_hash(cfg, assignment, modelVersion)
% BUILD_POPULATION_HASH Lightweight cache key based on key settings.
raw = sprintf('%s|%s|%d|%d|%d|%.4f|%d|%s', cfg.simulation.start_date, ...
    cfg.simulation.end_date, cfg.simulation.dt_min, cfg.simulation.Tsteps, ...
    cfg.feeder.num_households, cfg.ev.penetration_rate, sum(assignment.phase_id), modelVersion);
hash = char(matlab.lang.makeValidName(['h_' raw]));
end

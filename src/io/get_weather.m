function weather = get_weather(cfg)
% GET_WEATHER Fetch or synthesize Assiut hourly temperature and interpolate to dt_min.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration returned by config_loader.m. Required fields:
%       cfg.location.city
%       cfg.location.country
%       cfg.location.latitude
%       cfg.location.longitude
%       cfg.simulation.d1
%       cfg.simulation.d2
%       cfg.simulation.Tsteps
%       cfg.simulation.dt_min
%       cfg.simulation.tvec_min
%       cfg.root_folder
%
% Outputs:
%   weather (struct): Weather data with fields:
%       weather.timestamps - Tsteps-by-1 datetime vector
%       weather.temp_C     - Tsteps-by-1 outdoor air temperature in deg C
%       weather.meta       - source, city, country, lat, lon, cache_file,
%                            api_url, and fallback_reason
%
% Example:
%   cfg = config_loader();
%   weather = get_weather(cfg);

% --- Section 1: Validate inputs and prepare cache path ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);

lat = cfg.location.latitude;    % Critical: Assiut latitude = 27.1809
lon = cfg.location.longitude;   % Critical: Assiut longitude = 31.1837
validateattributes(lat, {'numeric'}, {'scalar','real','>=',-90,'<=',90}, mfilename, 'latitude');
validateattributes(lon, {'numeric'}, {'scalar','real','>=',-180,'<=',180}, mfilename, 'longitude');

weatherDir = fullfile(cfg.root_folder, 'data', 'weather');
if ~exist(weatherDir, 'dir')
    mkdir(weatherDir);
end

startDate = datestr(cfg.simulation.d1, 'yyyy-mm-dd');
endDate = datestr(cfg.simulation.d2, 'yyyy-mm-dd');
citySafe = regexprep(char(cfg.location.city), '[^A-Za-z0-9_\-]', '_');
countrySafe = regexprep(char(cfg.location.country), '[^A-Za-z0-9_\-]', '_');
cacheFile = fullfile(weatherDir, sprintf('%s_%s_%s_%s.csv', ...
    citySafe, countrySafe, startDate, endDate));

weather.timestamps = cfg.simulation.d1 + minutes(cfg.simulation.tvec_min(:));
weather.temp_C = [];
weather.meta = struct();
weather.meta.city = cfg.location.city;
weather.meta.country = cfg.location.country;
weather.meta.lat = lat;
weather.meta.lon = lon;
weather.meta.cache_file = cacheFile;
weather.meta.fallback_reason = '';
weather.meta.years = unique(year(weather.timestamps));

% --- Section 2: Load cached weather when available ---
if isfile(cacheFile)
    try
        cached = readtable(cacheFile, 'VariableNamingRule', 'preserve');
        weather.temp_C = double(cached.temp_C);
        if height(cached) == cfg.simulation.Tsteps && all(isfinite(weather.temp_C))
            weather.meta.source = 'cache';
            fprintf('[get_weather] Loaded cached weather | %s | rows=%d\n', cacheFile, height(cached));
            return;
        end
    catch ME
        weather.meta.fallback_reason = sprintf('Cache read failed: %s', ME.message);
    end
end

% --- Section 3: Try NASA POWER API ---
try
    [hourlyTime, hourlyTemp, apiUrl] = fetch_nasa_power_temperature(cfg, lat, lon);
    weather.temp_C = interpolate_temperature(hourlyTime, hourlyTemp, weather.timestamps);
    weather.meta.source = 'NASA POWER API';
    weather.meta.api_url = apiUrl;
catch ME
    weather.meta.source = 'synthetic_fallback';
    weather.meta.fallback_reason = ME.message;
    weather.temp_C = synthetic_assiut_temperature(weather.timestamps);
    weather.meta.api_url = '';
    warning('get_weather:fallback', ...
        'NASA POWER fetch failed. Using synthetic Assiut temperature. Reason: %s', ME.message);
end

% --- Section 4: Final validation and cache write ---
weather.temp_C = weather.temp_C(:);
if numel(weather.temp_C) ~= cfg.simulation.Tsteps
    error('get_weather:lengthMismatch', 'weather.temp_C length does not match cfg.simulation.Tsteps.');
end
if any(~isfinite(weather.temp_C))
    error('get_weather:nonFiniteTemperature', 'weather.temp_C contains NaN or Inf values.');
end

outTable = table(weather.timestamps(:), weather.temp_C(:), ...
    'VariableNames', {'timestamp','temp_C'});
writetable(outTable, cacheFile);

fprintf('[get_weather] OK | source=%s | min=%.1f C | max=%.1f C | rows=%d\n', ...
    weather.meta.source, min(weather.temp_C), max(weather.temp_C), numel(weather.temp_C));
end

function [hourlyTime, hourlyTemp, apiUrl] = fetch_nasa_power_temperature(cfg, lat, lon)
% FETCH_NASA_POWER_TEMPERATURE Download hourly T2M temperature from NASA POWER.
startStr = datestr(cfg.simulation.d1, 'yyyymmdd');
% NASA POWER end is inclusive. Use the final simulated day, not cfg.simulation.d2 exclusive.
lastTimestamp = cfg.simulation.d1 + minutes(cfg.simulation.tvec_min(end));
endStr = datestr(lastTimestamp, 'yyyymmdd');

apiUrl = sprintf(['https://power.larc.nasa.gov/api/temporal/hourly/point?' ...
    'parameters=T2M&community=RE&longitude=%.6f&latitude=%.6f&start=%s&end=%s&format=JSON&time-standard=UTC'], ...
    lon, lat, startStr, endStr);

opts = weboptions('Timeout', 20);
apiData = webread(apiUrl, opts);

if ~isfield(apiData, 'properties') || ~isfield(apiData.properties, 'parameter') || ...
        ~isfield(apiData.properties.parameter, 'T2M')
    error('get_weather:badApiResponse', 'NASA POWER response does not contain properties.parameter.T2M.');
end

t2m = apiData.properties.parameter.T2M;
fields = fieldnames(t2m);
if isempty(fields)
    error('get_weather:noApiRows', 'NASA POWER returned no temperature rows.');
end

hourlyTime = NaT(numel(fields), 1);
hourlyTemp = nan(numel(fields), 1);
for i = 1:numel(fields)
    key = fields{i};
    numericKey = regexprep(key, '^x', '');
    numericKey = regexprep(numericKey, '[^0-9]', '');
    if numel(numericKey) < 10
        continue;
    end
    hourlyTime(i) = datetime(numericKey(1:10), 'InputFormat', 'yyyyMMddHH');
    hourlyTemp(i) = double(t2m.(key));
end

valid = ~isnat(hourlyTime) & isfinite(hourlyTemp) & hourlyTemp > -50 & hourlyTemp < 70;
hourlyTime = hourlyTime(valid);
hourlyTemp = hourlyTemp(valid);

[hourlyTime, sortIdx] = sort(hourlyTime);
hourlyTemp = hourlyTemp(sortIdx);

if numel(hourlyTemp) < 24
    error('get_weather:tooFewApiRows', 'NASA POWER returned fewer than 24 valid hourly temperature rows.');
end
end

function temp = interpolate_temperature(hourlyTime, hourlyTemp, targetTime)
% INTERPOLATE_TEMPERATURE Interpolate hourly temperatures to simulation timestep.
x = datenum(hourlyTime);
y = hourlyTemp(:);
xq = datenum(targetTime(:));
[x, uniqueIdx] = unique(x, 'stable');
y = y(uniqueIdx);
temp = interp1(x, y, xq, 'linear', 'extrap');
end

function temp = synthetic_assiut_temperature(timestamps)
% SYNTHETIC_ASSIUT_TEMPERATURE Deterministic Assiut weather fallback.
% Formula follows the Phase 0 contract and clamps extremes to realistic
% Egyptian LV-feeder study bounds: winter lows around 5 C and summer peaks
% around 42-45 C.
doy = day(timestamps, 'dayofyear');
hourOfDay = hour(timestamps) + minute(timestamps) / 60 + second(timestamps) / 3600;
Tmean = 22 + 18 * sin(2*pi*(doy - 80) / 365);
Tdiurnal = 12;
temp = Tmean + Tdiurnal * sin(pi*(hourOfDay - 6) / 12);
temp = min(max(temp, 5), 45);
end

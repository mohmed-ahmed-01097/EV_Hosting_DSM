function test_phase0_io()
% TEST_PHASE0_IO Validate Phase 0 IO functions end-to-end.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation results for data_loader, daytype_calendar,
%   and get_weather.
%
% Example:
%   test_phase0_io()

fprintf('\n[test_phase0_io] Starting Phase 0 IO validation...\n');

thisFile = mfilename('fullpath');
testsDir = fileparts(thisFile);
rootDir = fileparts(testsDir);
addpath(genpath(fullfile(rootDir, 'src')));

cfg = config_loader();

% --- Test 1: data_loader runs and returns all required tables ---
data = data_loader(cfg);
requiredFields = {'household','residents','occ_pmf','activities','appliances','hvac','ev','meta'};
for i = 1:numel(requiredFields)
    assert(isfield(data, requiredFields{i}), 'Missing data.%s', requiredFields{i});
end
assert(height(data.household) > 0, 'Household table is empty.');
assert(height(data.occ_pmf) > 0, 'OccupancyPMF table is empty.');
assert(data.meta.max_pmf_error <= 0.01, 'Occupancy PMF max error exceeds tolerance.');
fprintf('  PASS: data_loader returned all required tables | households=%d | PMF error=%.6g\n', ...
    height(data.household), data.meta.max_pmf_error);

% --- Test 2: daytype_calendar vector sizes and Egypt rules ---
cal = daytype_calendar(cfg);
assert(numel(cal.timestamps) == cfg.simulation.Tsteps, 'Calendar timestamp length mismatch.');
assert(numel(cal.daytype) == cfg.simulation.Tsteps, 'Calendar daytype length mismatch.');
assert(numel(cal.season) == cfg.simulation.Tsteps, 'Calendar season length mismatch.');
assert(numel(cal.is_ramadan) == cfg.simulation.Tsteps, 'Calendar Ramadan length mismatch.');

idxJan10 = find(dateshift(cal.timestamps, 'start', 'day') == datetime(2025, 1, 10), 1, 'first');
if ~isempty(idxJan10)
    assert(cal.daytype(idxJan10) == 1, '2025-01-10 is Friday and should be weekend in Egypt.');
end

idxJan7 = find(dateshift(cal.timestamps, 'start', 'day') == datetime(2025, 1, 7), 1, 'first');
if ~isempty(idxJan7)
    assert(cal.daytype(idxJan7) == 2, '2025-01-07 should be marked as an Egyptian holiday.');
end

idxJul7 = find(dateshift(cal.timestamps, 'start', 'day') == datetime(2025, 7, 7), 1, 'first');
if ~isempty(idxJul7)
    assert(string(cal.season(idxJul7)) == "summer", 'July should be summer.');
end

assert(any(cal.is_ramadan), 'Ramadan flag should be true for part of the 2025 simulation.');
fprintf('  PASS: daytype_calendar vectors and Egypt calendar rules validated\n');

% --- Test 3: get_weather returns full vector or graceful fallback ---
weather = get_weather(cfg);
assert(isfield(weather, 'timestamps') && isfield(weather, 'temp_C') && isfield(weather, 'meta'), ...
    'Weather struct missing required fields.');
assert(numel(weather.timestamps) == cfg.simulation.Tsteps, 'Weather timestamp length mismatch.');
assert(numel(weather.temp_C) == cfg.simulation.Tsteps, 'Weather temperature length mismatch.');
assert(all(isfinite(weather.temp_C)), 'Weather contains non-finite values.');
assert(min(weather.temp_C) >= -10, 'Weather minimum is implausibly low for Assiut.');
assert(max(weather.temp_C) <= 55, 'Weather maximum is implausibly high for Assiut.');
fprintf('  PASS: get_weather returned valid temperature vector | source=%s | range=%.1f..%.1f C\n', ...
    weather.meta.source, min(weather.temp_C), max(weather.temp_C));

fprintf('[test_phase0_io] Complete. Phase 0 IO validation passed.\n');
end

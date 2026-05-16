function main(config_path, varargin)
% MAIN Top-level runner for the implemented Phase 0 IO layer.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   config_path (char/string, optional): JSON config path.
%   varargin: use 'validate' to run configuration validation tests.
%
% Outputs:
%   None.
%
% Example:
%   main([], 'validate')
%   main('config/scenario_configs/scenario1.json')

if nargin < 1
    config_path = '';
end

thisFile = mfilename('fullpath');
srcDir = fileparts(thisFile);
rootDir = fileparts(srcDir);
addpath(genpath(fullfile(rootDir, 'src')));
addpath(genpath(fullfile(rootDir, 'tests')));

if any(strcmpi(varargin, 'validate'))
    run_config_tests();
    return;
end

cfg = config_loader(config_path);

data = data_loader(cfg);
cal_struct = daytype_calendar(cfg);
weather = get_weather(cfg);

fprintf('[main] Phase 0 complete: config, survey data, calendar, and weather loaded successfully.\n');
fprintf('[main] Data rows: households=%d, residents=%d, occupancy=%d, activities=%d, appliances=%d, HVAC=%d, EV=%d.\n', ...
    height(data.household), height(data.residents), height(data.occ_pmf), height(data.activities), ...
    height(data.appliances), height(data.hvac), height(data.ev));
fprintf('[main] Calendar/weather: steps=%d, weather source=%s.\n', cfg.simulation.Tsteps, weather.meta.source);
fprintf('[main] Next implementation step: Phase 1 feeder model.\n');
end

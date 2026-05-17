function cfg = config_loader(config_path)
% CONFIG_LOADER Load, merge, validate, and extend configuration.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   config_path (char/string, optional): Path to JSON override config.
%
% Outputs:
%   cfg (struct): Validated configuration with defaults and computed fields.
%
% Computed fields:
%   cfg.root_folder
%   cfg.simulation.d1
%   cfg.simulation.d2
%   cfg.simulation.horizon_days
%   cfg.simulation.dt_hr
%   cfg.simulation.Tsteps
%   cfg.simulation.tvec_min
%   cfg.feeder_params_path
%   cfg.output_dir
%   cfg.figs_dir
%   cfg.tables_dir
%   cfg.loaded_on
%
% Example:
%   cfg = config_loader();
%   cfg = config_loader('config/scenario_configs/scenario1.json');

% --- Section 1: Locate project root ---
ioDir = fileparts(mfilename('fullpath'));     % EV_Hosting_DSM/src/io
srcDir = fileparts(ioDir);                    % EV_Hosting_DSM/src
rootDir = fileparts(srcDir);                  % EV_Hosting_DSM

% --- Section 2: Load default configuration ---
defaultPath = fullfile(rootDir, 'config', 'default_config.json');

if ~isfile(defaultPath)
    error('config_loader:missingDefault', ...
        'default_config.json not found at: %s', defaultPath);
end

cfg = jsondecode(fileread(defaultPath));
cfg.root_folder = rootDir;

% --- Section 3: Load optional override configuration ---
if nargin < 1
    config_path = '';
end

if isstring(config_path)
    config_path = char(config_path);
end

if ~isempty(config_path)
    if ~isfile(config_path)
        config_path = fullfile(rootDir, config_path);
    end

    if ~isfile(config_path)
        error('config_loader:missingOverride', ...
            'Override config file not found: %s', config_path);
    end

    userCfg = jsondecode(fileread(config_path));
    cfg = merge_structs_recursive(cfg, userCfg);
    cfg.root_folder = rootDir;
end

% --- Section 4: Validate seed ---
if ~isfield(cfg, 'seed') || isempty(cfg.seed) || cfg.seed < 0
    cfg.seed = 42;
end
rng(cfg.seed, 'twister');

% --- Section 5: Validate simulation timestep before derived fields ---
validDtMin = [1 5 10 15];

if ~isfield(cfg.simulation, 'dt_min') || ...
        ~ismember(cfg.simulation.dt_min, validDtMin)
    warning('config_loader:invalidDt', ...
        'Invalid dt_min. Defaulting to 15 minutes.');
    cfg.simulation.dt_min = 15;
end

% --- Section 6: Parse dates and compute simulation fields ---
try
    d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
    d2 = datetime(cfg.simulation.end_date,   'InputFormat', 'yyyy-MM-dd');
catch
    error('config_loader:invalidDate', ...
        'Invalid date format. Use yyyy-MM-dd.');
end

if d2 <= d1
    error('config_loader:dateOrder', ...
        'simulation.end_date must be after simulation.start_date.');
end

cfg.simulation.d1 = d1;
cfg.simulation.d2 = d2;
cfg.simulation.horizon_days = days(d2 - d1);
cfg.simulation.dt_hr = cfg.simulation.dt_min / 60;

stepsPerDay = 24 * 60 / cfg.simulation.dt_min;

if abs(stepsPerDay - round(stepsPerDay)) > eps
    error('config_loader:invalidStepsPerDay', ...
        'dt_min must divide 1440 minutes exactly.');
end

cfg.simulation.Tsteps = cfg.simulation.horizon_days * stepsPerDay;
cfg.simulation.tvec_min = ...
    (0 : cfg.simulation.Tsteps - 1)' * cfg.simulation.dt_min;

% --- Section 7: Validate feeder configuration ---
if sum(cfg.feeder.households_per_zone) ~= cfg.feeder.num_households
    error('config_loader:householdZoneMismatch', ...
        'sum(households_per_zone) must equal feeder.num_households.');
end

if cfg.feeder.num_transformer_zones ~= numel(cfg.feeder.households_per_zone)
    error('config_loader:zoneCountMismatch', ...
        'num_transformer_zones must match length(households_per_zone).');
end

% --- Section 8: Validate EV configuration ---
if cfg.ev.soc_min_pct >= cfg.ev.soc_target_pct
    error('config_loader:invalidSoc', ...
        'ev.soc_min_pct must be less than ev.soc_target_pct.');
end

if cfg.ev.soc_v2g_reserve_pct < cfg.ev.soc_min_pct
    error('config_loader:invalidV2GReserve', ...
        'ev.soc_v2g_reserve_pct must be greater than or equal to soc_min_pct.');
end

if cfg.ev.penetration_rate < 0 || cfg.ev.penetration_rate > 1
    error('config_loader:invalidEvPenetration', ...
        'ev.penetration_rate must be between 0 and 1.');
end

% --- Section 9: Validate PQ limits ---
if cfg.pq_limits.voltage_min_pu >= cfg.pq_limits.voltage_max_pu
    error('config_loader:invalidVoltageLimits', ...
        'voltage_min_pu must be less than voltage_max_pu.');
end

if cfg.pq_limits.vuf_max_pct <= 0
    error('config_loader:invalidVufLimit', ...
        'vuf_max_pct must be positive.');
end

% --- Section 10: Validate pricing configuration ---
if numel(cfg.pricing.tou_rates_24h) ~= 24
    error('config_loader:invalidTouRates', ...
        'pricing.tou_rates_24h must contain exactly 24 hourly rates.');
end

if numel(cfg.pricing.block_rates_egp) ~= ...
        numel(cfg.pricing.block_slabs_kwh) + 1
    error('config_loader:invalidBlockTariff', ...
        'block_rates_egp must have one more element than block_slabs_kwh.');
end

% --- Section 11: Resolve important paths dynamically from the project root ---
cfg.survey_paths.xlsx = resolve_project_path(rootDir, cfg.survey_paths.xlsx);
cfg.survey_paths.mat  = resolve_project_path(rootDir, cfg.survey_paths.mat);
cfg.feeder_params_path = resolve_project_path(rootDir, fullfile('config', 'feeder_params.json'));

if ~isfile(cfg.feeder_params_path)
    error('config_loader:missingFeederParams', ...
        'feeder_params.json not found at: %s', cfg.feeder_params_path);
end

% --- Section 12: Output directory setup ---
% The configured output_dir is normally the relative folder "results".
% Resolve it dynamically so the project can be moved to any drive or PC
% without hardcoded local paths. Absolute override paths are preserved.
cfg.output_dir = resolve_project_path(rootDir, cfg.output_dir);
cfg.figs_dir = fullfile(cfg.output_dir, 'figures');
cfg.tables_dir = fullfile(cfg.output_dir, 'tables');

dirsToCreate = {cfg.output_dir, cfg.figs_dir, cfg.tables_dir};

for k = 1:numel(dirsToCreate)
    if ~exist(dirsToCreate{k}, 'dir')
        mkdir(dirsToCreate{k});
    end
end

cfg.loaded_on = datestr(now, 31);

fprintf('[config_loader] OK: %s to %s | %d days | dt=%d min | %d steps\n', ...
    cfg.simulation.start_date, ...
    cfg.simulation.end_date, ...
    cfg.simulation.horizon_days, ...
    cfg.simulation.dt_min, ...
    cfg.simulation.Tsteps);

end


function absPath = resolve_project_path(rootDir, pathValue)
% RESOLVE_PROJECT_PATH Resolve relative paths against the MATLAB project root.
% Absolute paths are preserved. Relative paths are anchored at rootDir.

if isstring(pathValue)
    pathValue = char(pathValue);
end

if isempty(pathValue)
    absPath = rootDir;
    return;
end

if is_absolute_path(pathValue)
    absPath = pathValue;
else
    absPath = fullfile(rootDir, pathValue);
end
end

function tf = is_absolute_path(pathValue)
% IS_ABSOLUTE_PATH True for Windows, UNC, and Unix absolute paths.

if isstring(pathValue)
    pathValue = char(pathValue);
end

tf = false;
if isempty(pathValue)
    return;
end

% Windows drive path, for example C:\folder or D:/folder.
if numel(pathValue) >= 2 && pathValue(2) == ':'
    tf = true;
    return;
end

% UNC path, for example \server\share.
if numel(pathValue) >= 2 && pathValue(1) == '\' && pathValue(2) == '\'
    tf = true;
    return;
end

% Unix/macOS absolute path.
if pathValue(1) == '/'
    tf = true;
end
end

function out = merge_structs_recursive(base, override)
% MERGE_STRUCTS_RECURSIVE Recursively merge override struct into base struct.

out = base;
overrideFields = fieldnames(override);

for i = 1:numel(overrideFields)
    fieldName = overrideFields{i};

    if isfield(out, fieldName) && ...
            isstruct(out.(fieldName)) && ...
            isstruct(override.(fieldName))
        out.(fieldName) = merge_structs_recursive( ...
            out.(fieldName), override.(fieldName));
    else
        out.(fieldName) = override.(fieldName);
    end
end

end

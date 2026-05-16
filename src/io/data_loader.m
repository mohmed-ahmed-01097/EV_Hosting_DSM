function data = data_loader(cfg)
% DATA_LOADER Load, validate, normalize, and cache the Phase 0 survey workbook.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration returned by config_loader.m. Required fields:
%       cfg.survey_paths.xlsx - absolute path to Household_Energy_Survey.xlsx
%       cfg.survey_paths.mat  - absolute path to cache MAT file
%
% Outputs:
%   data (struct): Survey data tables with fields:
%       data.household  - Household sheet table
%       data.residents  - Residents sheet table
%       data.occ_pmf    - OccupancyPMF sheet table
%       data.activities - Activities sheet table
%       data.appliances - Appliances sheet table
%       data.hvac       - HVAC_Thermal sheet table
%       data.ev         - EV sheet table
%       data.meta       - loader metadata: source_file, cache_file, loaded_on,
%                         sheet_row_counts, and max_pmf_error
%
% Example:
%   cfg = config_loader();
%   data = data_loader(cfg);

% --- Section 1: Validate inputs and paths ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);

if ~isfield(cfg, 'survey_paths') || ~isfield(cfg.survey_paths, 'xlsx')
    error('data_loader:missingConfigPath', 'cfg.survey_paths.xlsx is required.');
end

surveyFile = cfg.survey_paths.xlsx;
if ~isfile(surveyFile)
    error('data_loader:missingSurvey', 'Survey workbook not found: %s', surveyFile);
end

if isfield(cfg.survey_paths, 'mat') && ~isempty(cfg.survey_paths.mat)
    cacheFile = cfg.survey_paths.mat;
else
    [surveyDir, surveyBase] = fileparts(surveyFile);
    cacheFile = fullfile(surveyDir, [surveyBase '.mat']);
end

% --- Section 2: Load from cache when valid ---
if is_cache_current(cacheFile, surveyFile)
    cache = load(cacheFile, 'data');
    if isfield(cache, 'data')
        data = cache.data;
        fprintf('[data_loader] Loaded cached survey data: %s\n', cacheFile);
        print_row_counts(data);
        return;
    end
end

% --- Section 3: Define Phase 0 sheet and column contract ---
requiredSheets = {'Household', 'Residents', 'OccupancyPMF', 'Activities', ...
    'Appliances', 'HVAC_Thermal', 'EV'};

requiredColumns = get_required_columns();
availableSheets = cellstr(sheetnames(surveyFile));
missingSheets = setdiff(requiredSheets, availableSheets, 'stable');
if ~isempty(missingSheets)
    error('data_loader:missingSheets', 'Missing required survey sheets: %s', ...
        strjoin(missingSheets, ', '));
end

% --- Section 4: Read, alias, and validate all sheets ---
sheetTables = struct();
for i = 1:numel(requiredSheets)
    sheetName = requiredSheets{i};
    T = readtable(surveyFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    T = apply_column_aliases(T, sheetName);
    T = normalize_sheet_types(T, sheetName);
    validate_required_columns(T, requiredColumns.(sheetName), sheetName);
    sheetTables.(sheetName) = T;
    fprintf('[data_loader] %-14s rows=%d\n', sheetName, height(T));
end

% --- Section 5: Validate cross-sheet consistency and probabilities ---
data.household  = sheetTables.Household;
data.residents  = sheetTables.Residents;
data.occ_pmf    = sheetTables.OccupancyPMF;
data.activities = sheetTables.Activities;
data.appliances = sheetTables.Appliances;
data.hvac       = sheetTables.HVAC_Thermal;
data.ev         = sheetTables.EV;

validate_cross_sheet_ids(data);
maxPmfError = validate_occupancy_pmf(data.occ_pmf);
validate_activity_bins(data.activities);
validate_ev_domain(data.ev);

% Add optional compatibility columns expected by later Phase 2 skeletons.
data.appliances = add_optional_appliance_defaults(data.appliances);

% --- Section 6: Attach metadata and cache ---
data.meta.source_file = surveyFile;
data.meta.cache_file = cacheFile;
data.meta.loaded_on = datestr(now, 31);
data.meta.required_sheets = requiredSheets;
data.meta.max_pmf_error = maxPmfError;
data.meta.sheet_row_counts = struct( ...
    'household', height(data.household), ...
    'residents', height(data.residents), ...
    'occ_pmf', height(data.occ_pmf), ...
    'activities', height(data.activities), ...
    'appliances', height(data.appliances), ...
    'hvac', height(data.hvac), ...
    'ev', height(data.ev));

cacheDir = fileparts(cacheFile);
if ~exist(cacheDir, 'dir')
    mkdir(cacheDir);
end
save(cacheFile, 'data', '-v7.3');

fprintf('[data_loader] Survey validation OK | max PMF error=%.6g | cache=%s\n', ...
    maxPmfError, cacheFile);
end

function requiredColumns = get_required_columns()
% GET_REQUIRED_COLUMNS Return the Phase 0 minimum workbook schema.
requiredColumns = struct();
requiredColumns.Household = {'Household_ID','Dwelling_Type','Floor_Area_m2', ...
    'Num_Residents','Income_Level'};
requiredColumns.Residents = {'Household_ID','Person_ID','Age','Role','Work_Status'};
requiredColumns.OccupancyPMF = {'Household_ID','Day_Type','Hour','P_Away', ...
    'P_Home_Awake','P_Asleep'};
requiredColumns.Activities = {'Household_ID','Activity','Frequency_Unit','Frequency_Value', ...
    'StartBin_00_06_%','StartBin_06_09_%','StartBin_09_12_%', ...
    'StartBin_12_17_%','StartBin_17_21_%','StartBin_21_24_%', ...
    'Avg_Duration_min','Weekend_Different'};
requiredColumns.Appliances = {'Household_ID','Appliance','Count','Rated_Power_W', ...
    'Standby_W','Is_Controllable','Flexibility_Window_hr','Preferred_Start_hr'};
requiredColumns.HVAC_Thermal = {'Household_ID','AC_Present','AC_Units_Count', ...
    'AC_Power_kW','Summer_Setpoint_C','Winter_Setpoint_C'};
requiredColumns.EV = {'Household_ID','Has_EV','EV_Battery_kWh','Charger_Type'};
end

function tf = is_cache_current(cacheFile, sourceFile)
% IS_CACHE_CURRENT True if MAT cache exists and is newer than XLSX source.
tf = false;
if ~isfile(cacheFile) || ~isfile(sourceFile)
    return;
end
cacheInfo = dir(cacheFile);
sourceInfo = dir(sourceFile);
tf = cacheInfo.datenum >= sourceInfo.datenum;
end

function T = apply_column_aliases(T, sheetName)
% APPLY_COLUMN_ALIASES Rename known legacy survey columns to Phase 0 names.
vars = T.Properties.VariableNames;
aliases = get_aliases(sheetName);
for i = 1:size(aliases, 1)
    canonical = aliases{i, 1};
    candidates = aliases{i, 2};
    if ismember(canonical, vars)
        continue;
    end
    matchIdx = find(ismember(vars, candidates), 1, 'first');
    if ~isempty(matchIdx)
        vars{matchIdx} = canonical;
    end
end
T.Properties.VariableNames = vars;
end

function aliases = get_aliases(sheetName)
% GET_ALIASES Return common old-survey aliases for a given sheet.
switch sheetName
    case 'Household'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id','ID'};
            'Dwelling_Type', {'Dwelling_Type(flat/house/duplex/other)','DwellingType','Housing_Type'};
            'Floor_Area_m2', {'Floor_Area','Area_m2','Home_Area_m2'};
            'Num_Residents', {'Residents','No_Residents','Household_Size'};
            'Income_Level', {'Income','Income_Band','Monthly_Income_Level'}};
    case 'Residents'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'Person_ID', {'Resident_ID','PersonID','Member_ID'};
            'Age', {'Age_Years','Age_Band_Midpoint'};
            'Role', {'Resident_Role','Relation'};
            'Work_Status', {'Status','Employment_Status','WorkSchool_Status'}};
    case 'OccupancyPMF'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'Day_Type', {'DayType','Day type','day_type'};
            'Hour', {'Hour_Of_Day','hour'};
            'P_Away', {'Away','Probability_Away','pAway'};
            'P_Home_Awake', {'Home_Awake','Probability_Home_Awake','pHomeAwake'};
            'P_Asleep', {'Asleep','Probability_Asleep','pSleep'}};
    case 'Activities'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'Activity', {'Activity_Name','Action'};
            'Frequency_Unit', {'Frequency_Unit(per_day/per_week)','Freq_Unit'};
            'Frequency_Value', {'Frequency','Freq_Value'};
            'Avg_Duration_min', {'Duration_min','Average_Duration_min'};
            'Weekend_Different', {'WeekendDifferent','Weekend_Diff'}};
    case 'Appliances'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'Appliance', {'Appliance_Name','Device'};
            'Count', {'Quantity','No_Units'};
            'Rated_Power_W', {'Power_W','RatedPower_W','Rated_Power'};
            'Standby_W', {'StandbyPower_W','Standby'};
            'Is_Controllable', {'Controllable','DSM_Controllable'};
            'Flexibility_Window_hr', {'Flex_Window_hr','Shift_Window_hr'};
            'Preferred_Start_hr', {'PreferredStart_hr','Preferred_Hour'}};
    case 'HVAC_Thermal'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'AC_Present', {'AC_Present(0/1)','Has_AC'};
            'AC_Units_Count', {'AC_Count','Num_AC_Units'};
            'AC_Power_kW', {'Power_AC_kW','AC_Rated_Power_kW'};
            'Summer_Setpoint_C', {'Cooling_Setpoint_C','AC_Setpoint_Summer'};
            'Winter_Setpoint_C', {'Heating_Setpoint_C','AC_Setpoint_Winter'}};
    case 'EV'
        aliases = {
            'Household_ID', {'HH_ID','HouseholdID','household_id'};
            'Has_EV', {'EV_Present(0/1)','EV_Present','Owns_EV'};
            'EV_Battery_kWh', {'Battery_kWh','EV_Battery'};
            'Charger_Type', {'EV_Charger_Type','Charging_Type'}};
    otherwise
        aliases = cell(0, 2);
end
end

function T = normalize_sheet_types(T, sheetName)
% NORMALIZE_SHEET_TYPES Apply safe type/domain cleanup after loading.
switch sheetName
    case 'OccupancyPMF'
        T.Day_Type = normalize_day_type(T.Day_Type);
        T.Hour = double(T.Hour);
        T.P_Away = double(T.P_Away);
        T.P_Home_Awake = double(T.P_Home_Awake);
        T.P_Asleep = double(T.P_Asleep);
    case 'Activities'
        T.Activity = cellstr(string(T.Activity));
        T.Frequency_Unit = lower(strtrim(cellstr(string(T.Frequency_Unit))));
        T.Weekend_Different = normalize_yes_no(T.Weekend_Different);
    case 'Appliances'
        T.Appliance = cellstr(string(T.Appliance));
        T.Is_Controllable = normalize_logical(T.Is_Controllable);
    case 'HVAC_Thermal'
        T.AC_Present = normalize_logical(T.AC_Present);
    case 'EV'
        T.Has_EV = normalize_logical(T.Has_EV);
        T.Charger_Type = lower(strtrim(cellstr(string(T.Charger_Type))));
end
end

function dayType = normalize_day_type(value)
% NORMALIZE_DAY_TYPE Convert day type labels to uint8 codes 0/1/2.
if isnumeric(value) || islogical(value)
    dayType = uint8(value);
    return;
end
labels = lower(strtrim(string(value)));
dayType = zeros(numel(labels), 1, 'uint8');
dayType(ismember(labels, ["weekend","1","fri_sat"])) = uint8(1);
dayType(ismember(labels, ["holiday","2"])) = uint8(2);
end

function yn = normalize_yes_no(value)
% NORMALIZE_YES_NO Convert yes/no-like values to logical.
if isnumeric(value) || islogical(value)
    yn = double(value) ~= 0;
    return;
end
labels = lower(strtrim(string(value)));
yn = ismember(labels, ["yes","y","true","1","different"]);
end


function flag = normalize_logical(value)
% NORMALIZE_LOGICAL Convert numeric or text flags to logical column vector.
if isnumeric(value) || islogical(value)
    flag = double(value) ~= 0;
    return;
end
labels = lower(strtrim(string(value)));
flag = ismember(labels, ["yes","y","true","1","present","owned","available"]);
end

function validate_required_columns(T, required, sheetName)
% VALIDATE_REQUIRED_COLUMNS Error if any required columns are absent.
missing = setdiff(required, T.Properties.VariableNames, 'stable');
if ~isempty(missing)
    error('data_loader:missingColumns', 'Sheet %s is missing columns: %s', ...
        sheetName, strjoin(missing, ', '));
end
end

function validate_cross_sheet_ids(data)
% VALIDATE_CROSS_SHEET_IDS Ensure dependent sheets reference known households.
householdIds = data.household.Household_ID;
sheetsToCheck = {'residents','occ_pmf','activities','appliances','hvac','ev'};
for i = 1:numel(sheetsToCheck)
    name = sheetsToCheck{i};
    ids = unique(data.(name).Household_ID);
    unknown = setdiff(ids, householdIds);
    if ~isempty(unknown)
        error('data_loader:unknownHouseholdId', ...
            'Sheet %s references Household_ID values not in Household sheet. First missing ID: %s', ...
            name, num2str(unknown(1)));
    end
end
end

function maxErr = validate_occupancy_pmf(occ)
% VALIDATE_OCCUPANCY_PMF Ensure probability rows are valid and sum to one.
if any(occ.Hour < 0 | occ.Hour > 23 | isnan(occ.Hour))
    error('data_loader:badHour', 'OccupancyPMF.Hour must be in the range 0..23.');
end
if any(~ismember(unique(occ.Day_Type), uint8([0; 1; 2])))
    error('data_loader:badDayType', 'OccupancyPMF.Day_Type must use 0=weekday, 1=weekend, 2=holiday.');
end
pmf = [occ.P_Away, occ.P_Home_Awake, occ.P_Asleep];
if any(pmf(:) < -1e-9 | pmf(:) > 1 + 1e-9 | isnan(pmf(:)))
    error('data_loader:badPMFValue', 'OccupancyPMF probability values must be within [0, 1].');
end
rowSum = sum(pmf, 2);
maxErr = max(abs(rowSum - 1.0));
if maxErr > 0.01
    error('data_loader:badPMFSum', ...
        'OccupancyPMF rows must sum to 1.0 +/-0.01. Max error = %.6g', maxErr);
end
end

function validate_activity_bins(act)
% VALIDATE_ACTIVITY_BINS Ensure start-bin columns form a valid PMF in percent.
binColumns = {'StartBin_00_06_%','StartBin_06_09_%','StartBin_09_12_%', ...
    'StartBin_12_17_%','StartBin_17_21_%','StartBin_21_24_%'};
bins = zeros(height(act), numel(binColumns));
for i = 1:numel(binColumns)
    bins(:, i) = double(act.(binColumns{i}));
end
if any(bins(:) < -1e-9 | bins(:) > 100 + 1e-9 | isnan(bins(:)))
    error('data_loader:badActivityBinValue', 'Activity start-bin percentages must be in [0, 100].');
end
binSum = sum(bins, 2);
maxErr = max(abs(binSum - 100));
if maxErr > 0.01
    error('data_loader:badActivityBins', ...
        'Activity start-bin percentages must sum to 100. Max error = %.6g', maxErr);
end
end

function validate_ev_domain(ev)
% VALIDATE_EV_DOMAIN Validate EV charger labels and battery values.
allowed = {'none','slow','fast','v2g'};
charger = lower(strtrim(cellstr(string(ev.Charger_Type))));
if any(~ismember(charger, allowed))
    error('data_loader:badChargerType', ...
        'EV.Charger_Type must be one of: none, slow, fast, v2g.');
end
battery = double(ev.EV_Battery_kWh);
if any(battery < 0 | isnan(battery))
    error('data_loader:badBattery', 'EV.EV_Battery_kWh must be non-negative.');
end
end

function T = add_optional_appliance_defaults(T)
% ADD_OPTIONAL_APPLIANCE_DEFAULTS Add compatibility defaults for later phases.
if ~ismember('Standby_Always_On', T.Properties.VariableNames)
    alwaysOnNames = {'Refrigerator','Router','Set_Top_Box'};
    T.Standby_Always_On = ismember(string(T.Appliance), string(alwaysOnNames)) | T.Standby_W > 0;
end
end

function print_row_counts(data)
% PRINT_ROW_COUNTS Print row counts for cached data.
fields = {'household','residents','occ_pmf','activities','appliances','hvac','ev'};
for i = 1:numel(fields)
    name = fields{i};
    if isfield(data, name)
        fprintf('[data_loader] %-14s rows=%d\n', name, height(data.(name)));
    end
end
end

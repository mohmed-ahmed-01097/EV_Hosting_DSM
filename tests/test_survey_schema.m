function test_survey_schema()
% TEST_SURVEY_SCHEMA Validate the Phase 0 survey workbook schema.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation results for the survey workbook required by
%   data_loader.m before Phase 0 implementation starts.
%
% Example:
%   test_survey_schema()

fprintf('\n[test_survey_schema] Starting survey workbook validation...\n');

thisFile = mfilename('fullpath');
testsDir = fileparts(thisFile);
rootDir = fileparts(testsDir);
addpath(genpath(fullfile(rootDir, 'src')));

cfg = config_loader();
surveyFile = cfg.survey_paths.xlsx;

if ~isfile(surveyFile)
    error('test_survey_schema:missingSurvey', 'Survey workbook not found: %s', surveyFile);
end

availableSheets = cellstr(sheetnames(surveyFile));

requiredSheets = { ...
    'Household', ...
    'Residents', ...
    'OccupancyPMF', ...
    'Activities', ...
    'Appliances', ...
    'HVAC_Thermal', ...
    'EV'};

requiredColumns = struct();
requiredColumns.Household = {'Household_ID','Dwelling_Type','Floor_Area_m2','Num_Residents','Income_Level'};
requiredColumns.Residents = {'Household_ID','Person_ID','Age','Role','Work_Status'};
requiredColumns.OccupancyPMF = {'Household_ID','Day_Type','Hour','P_Away','P_Home_Awake','P_Asleep'};
requiredColumns.Activities = {'Household_ID','Activity','Frequency_Unit','Frequency_Value', ...
    'StartBin_00_06_%','StartBin_06_09_%','StartBin_09_12_%', ...
    'StartBin_12_17_%','StartBin_17_21_%','StartBin_21_24_%', ...
    'Avg_Duration_min','Weekend_Different'};
requiredColumns.Appliances = {'Household_ID','Appliance','Count','Rated_Power_W','Standby_W', ...
    'Is_Controllable','Flexibility_Window_hr','Preferred_Start_hr'};
requiredColumns.HVAC_Thermal = {'Household_ID','AC_Present','AC_Units_Count','AC_Power_kW', ...
    'Summer_Setpoint_C','Winter_Setpoint_C'};
requiredColumns.EV = {'Household_ID','Has_EV','EV_Battery_kWh','Charger_Type'};

for i = 1:numel(requiredSheets)
    sheetName = requiredSheets{i};
    if ~ismember(sheetName, availableSheets)
        error('test_survey_schema:missingSheet', 'Missing required sheet: %s', sheetName);
    end

    T = readtable(surveyFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    vars = T.Properties.VariableNames;
    missing = setdiff(requiredColumns.(sheetName), vars, 'stable');

    if ~isempty(missing)
        error('test_survey_schema:missingColumns', ...
            'Sheet %s is missing columns: %s', sheetName, strjoin(missing, ', '));
    end

    fprintf('  PASS: %-14s | rows=%d | required columns OK\n', sheetName, height(T));
end

% --- Validate OccupancyPMF probabilities ---
occ = readtable(surveyFile, 'Sheet', 'OccupancyPMF', 'VariableNamingRule', 'preserve');
pmfSum = occ.P_Away + occ.P_Home_Awake + occ.P_Asleep;
maxErr = max(abs(pmfSum - 1.0));

if maxErr > 0.01
    error('test_survey_schema:badPMF', ...
        'OccupancyPMF rows must sum to 1.0 +/-0.01. Max error = %.6f', maxErr);
end

validDayTypes = all(ismember(unique(occ.Day_Type), [0; 1; 2]));
if ~validDayTypes
    error('test_survey_schema:badDayType', ...
        'OccupancyPMF.Day_Type must use numeric coding 0=weekday, 1=weekend, 2=holiday.');
end

% --- Validate activity start-bin percentages ---
act = readtable(surveyFile, 'Sheet', 'Activities', 'VariableNamingRule', 'preserve');
startBinSum = act.("StartBin_00_06_%") + act.("StartBin_06_09_%") + ...
    act.("StartBin_09_12_%") + act.("StartBin_12_17_%") + ...
    act.("StartBin_17_21_%") + act.("StartBin_21_24_%");
maxBinErr = max(abs(startBinSum - 100));

if maxBinErr > 0.01
    error('test_survey_schema:badActivityBins', ...
        'Activity start-bin percentages must sum to 100. Max error = %.6f', maxBinErr);
end

% --- Validate EV charger types ---
ev = readtable(surveyFile, 'Sheet', 'EV', 'VariableNamingRule', 'preserve');
chargerTypes = string(ev.Charger_Type);
allowedChargerTypes = ["none", "slow", "fast", "v2g"];
if any(~ismember(chargerTypes, allowedChargerTypes))
    error('test_survey_schema:badChargerType', ...
        'EV.Charger_Type contains values outside: none, slow, fast, v2g.');
end

fprintf('  PASS: OccupancyPMF probability sums | max error = %.6g\n', maxErr);
fprintf('  PASS: Activities start-bin sums     | max error = %.6g\n', maxBinErr);
fprintf('  PASS: EV charger type domain        | EV households = %d\n', sum(ev.Has_EV == 1));
fprintf('[test_survey_schema] Complete. Survey workbook is Phase 0 ready.\n');
end

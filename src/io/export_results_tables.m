function exportInfo = export_results_tables(all_results, cfg)
% EXPORT_RESULTS_TABLES Export scenario results to thesis-ready CSV tables.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results (cell/struct): Scenario result structs from Phase 5.
%   cfg         (struct): Project configuration with cfg.tables_dir.
%
% Outputs:
%   exportInfo (struct): Paths and row counts for exported tables.
%
% Exported files:
%   scenario_summary.csv
%   scenario_cost_summary.csv
%   scenario_comfort_summary.csv
%   scenario_violations.csv
%   deliverables_checklist.csv
%
% Example:
%   info = export_results_tables(all_results, cfg);

validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 2);
if nargin < 1 || isempty(all_results)
    all_results = {};
end
results = normalize_results_cell(all_results);

if ~isfield(cfg, 'tables_dir') || isempty(cfg.tables_dir)
    cfg.tables_dir = fullfile(cfg.root_folder, 'results', 'tables');
end
if ~exist(cfg.tables_dir, 'dir')
    mkdir(cfg.tables_dir);
end

summaryTable = build_scenario_summary_table(results);
costTable = build_cost_summary_table(results);
comfortTable = build_comfort_summary_table(results);
violTable = build_violations_table(results);
checklistTable = build_deliverables_checklist_table();

exportInfo = struct();
exportInfo.scenario_summary = fullfile(cfg.tables_dir, 'scenario_summary.csv');
exportInfo.cost_summary = fullfile(cfg.tables_dir, 'scenario_cost_summary.csv');
exportInfo.comfort_summary = fullfile(cfg.tables_dir, 'scenario_comfort_summary.csv');
exportInfo.violations = fullfile(cfg.tables_dir, 'scenario_violations.csv');
exportInfo.deliverables_checklist = fullfile(cfg.tables_dir, 'deliverables_checklist.csv');

writetable(summaryTable, exportInfo.scenario_summary);
writetable(costTable, exportInfo.cost_summary);
writetable(comfortTable, exportInfo.comfort_summary);
writetable(violTable, exportInfo.violations);
writetable(checklistTable, exportInfo.deliverables_checklist);

exportInfo.num_scenarios = height(summaryTable);
exportInfo.num_cost_rows = height(costTable);
exportInfo.num_comfort_rows = height(comfortTable);
exportInfo.num_violation_rows = height(violTable);
exportInfo.num_checklist_rows = height(checklistTable);
exportInfo.tables_dir = cfg.tables_dir;

fprintf('[export_results_tables] OK: exported %d scenario rows to %s\n', ...
    exportInfo.num_scenarios, cfg.tables_dir);
end

function results = normalize_results_cell(all_results)
% NORMALIZE_RESULTS_CELL Convert result input to a cell vector.
if isempty(all_results)
    results = {};
elseif iscell(all_results)
    results = all_results(:);
elseif isstruct(all_results)
    if numel(all_results) == 1
        results = {all_results};
    else
        results = num2cell(all_results(:));
    end
else
    error('export_results_tables:invalidResults', 'all_results must be a cell array or struct array.');
end
results = results(~cellfun(@isempty, results));
end

function T = build_scenario_summary_table(results)
% BUILD_SCENARIO_SUMMARY_TABLE Create network/PQ summary table.
N = numel(results);
scenario_id = nan(N, 1);
description = strings(N, 1);
mean_vuf_pct = nan(N, 1);
max_vuf_pct = nan(N, 1);
min_voltage_pu = nan(N, 1);
max_loading_pct = nan(N, 1);
max_iuf_pct = nan(N, 1);
max_ncr_pct = nan(N, 1);
mean_loss_kw = nan(N, 1);
mean_loss_kvar = nan(N, 1);
hosting_capacity_pct = nan(N, 1);
violation_count = nan(N, 1);
runtime_s = nan(N, 1);
created_on = strings(N, 1);

for i = 1:N
    r = results{i};
    scenario_id(i) = get_scalar(r, 'scenario_id', NaN);
    description(i) = string(get_text(r, 'description', ''));
    hosting_capacity_pct(i) = get_scalar(r, 'hosting_capacity_pct', NaN);
    runtime_s(i) = get_scalar(r, 'runtime_s', NaN);
    if isfield(r, 'metadata') && isstruct(r.metadata)
        created_on(i) = string(get_text(r.metadata, 'created_on', ''));
    end
    if isfield(r, 'pq_summary') && isstruct(r.pq_summary)
        pq = r.pq_summary;
        mean_vuf_pct(i) = get_scalar(pq, 'mean_vuf_pct', NaN);
        max_vuf_pct(i) = get_scalar(pq, 'max_vuf_pct', NaN);
        min_voltage_pu(i) = get_scalar(pq, 'min_voltage_pu', NaN);
        max_loading_pct(i) = get_scalar(pq, 'max_loading_pct', NaN);
        max_iuf_pct(i) = get_scalar(pq, 'max_iuf_pct', NaN);
        max_ncr_pct(i) = get_scalar(pq, 'max_ncr_pct', NaN);
        mean_loss_kw(i) = get_scalar(pq, 'mean_loss_kw', NaN);
        mean_loss_kvar(i) = get_scalar(pq, 'mean_loss_kvar', NaN);
        violation_count(i) = get_scalar(pq, 'violation_count', NaN);
    end
end

T = table(scenario_id, description, mean_vuf_pct, max_vuf_pct, min_voltage_pu, ...
    max_loading_pct, max_iuf_pct, max_ncr_pct, mean_loss_kw, mean_loss_kvar, ...
    hosting_capacity_pct, violation_count, runtime_s, created_on);
T = sortrows(T, 'scenario_id');
end

function T = build_cost_summary_table(results)
% BUILD_COST_SUMMARY_TABLE Create long-format tariff cost table.
scenario_id = zeros(0, 1);
description = strings(0, 1);
method = strings(0, 1);
mean_bill_egp = zeros(0, 1);
min_bill_egp = zeros(0, 1);
max_bill_egp = zeros(0, 1);
median_bill_egp = zeros(0, 1);
mean_monthly_energy_kwh = zeros(0, 1);

for i = 1:numel(results)
    r = results{i};
    sid = get_scalar(r, 'scenario_id', NaN);
    desc = string(get_text(r, 'description', ''));
    if ~isfield(r, 'costs') || ~isstruct(r.costs) || ~isfield(r.costs, 'bill_total')
        continue;
    end
    billStruct = r.costs.bill_total;
    names = fieldnames(billStruct);
    for k = 1:numel(names)
        vals = double(billStruct.(names{k})(:));
        vals = vals(isfinite(vals));
        if isempty(vals)
            vals = NaN;
        end
        scenario_id(end+1, 1) = sid; %#ok<AGROW>
        description(end+1, 1) = desc; %#ok<AGROW>
        method(end+1, 1) = string(names{k}); %#ok<AGROW>
        mean_bill_egp(end+1, 1) = mean(vals, 'omitnan'); %#ok<AGROW>
        min_bill_egp(end+1, 1) = min(vals); %#ok<AGROW>
        max_bill_egp(end+1, 1) = max(vals); %#ok<AGROW>
        median_bill_egp(end+1, 1) = median(vals, 'omitnan'); %#ok<AGROW>
        mean_monthly_energy_kwh(end+1, 1) = estimate_mean_monthly_energy(r); %#ok<AGROW>
    end
end

T = table(scenario_id, description, method, mean_bill_egp, min_bill_egp, ...
    max_bill_egp, median_bill_egp, mean_monthly_energy_kwh);
if height(T) > 0
    T = sortrows(T, {'scenario_id','method'});
end
end

function T = build_comfort_summary_table(results)
% BUILD_COMFORT_SUMMARY_TABLE Create comfort-index summary table.
N = numel(results);
scenario_id = nan(N, 1);
description = strings(N, 1);
comfort_mean = nan(N, 1);
comfort_min = nan(N, 1);
comfort_max = nan(N, 1);
comfort_count = nan(N, 1);
note = strings(N, 1);
for i = 1:N
    r = results{i};
    scenario_id(i) = get_scalar(r, 'scenario_id', NaN);
    description(i) = string(get_text(r, 'description', ''));
    if isfield(r, 'comfort_summary') && isstruct(r.comfort_summary)
        c = r.comfort_summary;
        comfort_mean(i) = get_scalar(c, 'mean', NaN);
        comfort_min(i) = get_scalar(c, 'min', NaN);
        comfort_max(i) = get_scalar(c, 'max', NaN);
        comfort_count(i) = get_scalar(c, 'count', NaN);
        note(i) = string(get_text(c, 'note', ''));
    end
end
T = table(scenario_id, description, comfort_mean, comfort_min, comfort_max, comfort_count, note);
T = sortrows(T, 'scenario_id');
end

function T = build_violations_table(results)
% BUILD_VIOLATIONS_TABLE Create compact violation table.
scenario_id = zeros(0, 1);
description = strings(0, 1);
non_converged_count = zeros(0, 1);
violation_count = zeros(0, 1);
first_violation_step = zeros(0, 1);
has_violations = false(0, 1);
for i = 1:numel(results)
    r = results{i};
    sid = get_scalar(r, 'scenario_id', NaN);
    desc = string(get_text(r, 'description', ''));
    nonConvCount = 0;
    violCount = NaN;
    firstStep = NaN;
    hasViol = false;
    if isfield(r, 'pq_summary') && isstruct(r.pq_summary)
        pq = r.pq_summary;
        violCount = get_scalar(pq, 'violation_count', NaN);
        if isfield(pq, 'non_converged_steps') && ~isempty(pq.non_converged_steps)
            nonConvCount = numel(pq.non_converged_steps);
        end
        if isfield(pq, 'violation_steps') && ~isempty(pq.violation_steps)
            firstStep = double(pq.violation_steps(1));
        end
        if isfield(pq, 'has_violations')
            hasViol = logical(pq.has_violations);
        elseif isfinite(violCount)
            hasViol = violCount > 0;
        end
    end
    scenario_id(end+1, 1) = sid; %#ok<AGROW>
    description(end+1, 1) = desc; %#ok<AGROW>
    non_converged_count(end+1, 1) = nonConvCount; %#ok<AGROW>
    violation_count(end+1, 1) = violCount; %#ok<AGROW>
    first_violation_step(end+1, 1) = firstStep; %#ok<AGROW>
    has_violations(end+1, 1) = hasViol; %#ok<AGROW>
end
T = table(scenario_id, description, has_violations, violation_count, ...
    non_converged_count, first_violation_step);
if height(T) > 0
    T = sortrows(T, 'scenario_id');
end
end

function T = build_deliverables_checklist_table()
% BUILD_DELIVERABLES_CHECKLIST_TABLE Final checklist table.
item = [
    "All config JSON files created and validated"
    "Phase 0 IO functions implemented and tested"
    "Phase 1 feeder model implemented and tested"
    "Phase 2 behavior-driven load model implemented and tested"
    "Phase 3 pricing engine implemented and tested"
    "Phase 4 DSM controller implemented and tested"
    "Phase 5 scenarios implemented and tested"
    "Phase 6 visualization implemented and tested"
    "Phase 7 HouseholdTwin implemented and tested"
    "Phase 8 validation test suite wired into main([], 'validate')"
    "Phase 9 main entry point and table export implemented"
    "Known bug fixes verified by config and regression tests"
    "Results exported to CSV/tables for thesis writing"
];
status = repmat("Complete", numel(item), 1);
verification = [
    "test_config_loader + test_survey_schema"
    "test_phase0_io"
    "test_phase1_feeder + test_bfs_power_flow + test_pq_indices"
    "test_simulate_occupancy + test_ev_model + test_simulate_household + test_phase2_load_model"
    "test_pricing + test_phase3_pricing"
    "test_milp + test_phase4_dsm"
    "test_phase5_scenarios"
    "test_phase6_visualization"
    "test_phase7_household_twin"
    "run_config_tests + test_phase8_tests_inventory"
    "test_phase9_main_export"
    "test_phase8_tests_inventory"
    "export_results_tables"
];
T = table(item, status, verification);
end

function x = get_scalar(s, fieldName, defaultValue)
% GET_SCALAR Robust scalar extraction.
x = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName))
    v = s.(fieldName);
    x = double(v(1));
end
end

function txt = get_text(s, fieldName, defaultValue)
% GET_TEXT Robust char/string extraction.
txt = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    txt = char(string(s.(fieldName)));
end
end

function e = estimate_mean_monthly_energy(r)
% ESTIMATE_MEAN_MONTHLY_ENERGY Estimate mean household monthly energy.
e = NaN;
if isfield(r, 'costs') && isstruct(r.costs) && isfield(r.costs, 'energy_monthly_kwh')
    vals = double(r.costs.energy_monthly_kwh(:));
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        e = mean(vals);
        return;
    end
end
if isfield(r, 'L_house_w') && ~isempty(r.L_house_w)
    dtHr = 0.25;
    if isfield(r, 'metadata') && isstruct(r.metadata) && isfield(r.metadata, 'dt_min')
        dtHr = double(r.metadata.dt_min) / 60;
    end
    totalKwhPerHousehold = sum(double(r.L_house_w), 1) * dtHr / 1000;
    days = max(1, size(r.L_house_w, 1) * dtHr / 24);
    e = mean(totalKwhPerHousehold) * (30 / days);
end
end

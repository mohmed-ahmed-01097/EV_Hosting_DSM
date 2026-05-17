function M = viz_result_metrics(all_results)
% VIZ_RESULT_METRICS Extract scalar plotting metrics from Phase 5 results.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results: Phase 5 result structs.
%
% Outputs:
%   M (struct): Vectorized scenario metrics:
%       .ids, .labels, .mean_vuf_pct, .max_vuf_pct, .min_voltage_pu,
%       .max_loading_pct, .hosting_capacity_pct, .comfort_mean,
%       .mean_loss_kw, .violation_count, .flat_bill_mean, .block_bill_mean
%
% Example:
%   M = viz_result_metrics(all_results);

results = viz_normalize_results(all_results);
N = numel(results);
M = struct();
M.ids = nan(1, N);
M.labels = cell(1, N);
M.mean_vuf_pct = nan(1, N);
M.max_vuf_pct = nan(1, N);
M.min_voltage_pu = nan(1, N);
M.max_loading_pct = nan(1, N);
M.hosting_capacity_pct = nan(1, N);
M.comfort_mean = nan(1, N);
M.mean_loss_kw = nan(1, N);
M.violation_count = nan(1, N);
M.flat_bill_mean = nan(1, N);
M.block_bill_mean = nan(1, N);
M.total_energy_kwh = nan(1, N);

for i = 1:N
    r = results{i};
    M.ids(i) = get_scalar(r, 'scenario_id', i);
    M.labels{i} = scenario_label(r);
    if isfield(r, 'pq_summary') && isstruct(r.pq_summary)
        M.mean_vuf_pct(i) = get_scalar(r.pq_summary, 'mean_vuf_pct', NaN);
        M.max_vuf_pct(i) = get_scalar(r.pq_summary, 'max_vuf_pct', NaN);
        M.min_voltage_pu(i) = get_scalar(r.pq_summary, 'min_voltage_pu', NaN);
        M.max_loading_pct(i) = get_scalar(r.pq_summary, 'max_loading_pct', NaN);
        M.mean_loss_kw(i) = get_scalar(r.pq_summary, 'mean_loss_kw', NaN);
        M.violation_count(i) = get_scalar(r.pq_summary, 'violation_count', NaN);
    end
    M.hosting_capacity_pct(i) = get_scalar(r, 'hosting_capacity_pct', NaN);
    if isfield(r, 'comfort_summary') && isstruct(r.comfort_summary)
        M.comfort_mean(i) = get_scalar(r.comfort_summary, 'mean', NaN);
    end
    if isfield(r, 'costs') && isstruct(r.costs) && isfield(r.costs, 'bill_total')
        bt = r.costs.bill_total;
        if isfield(bt, 'Flat'), M.flat_bill_mean(i) = mean_valid(bt.Flat); end
        if isfield(bt, 'Block'), M.block_bill_mean(i) = mean_valid(bt.Block); end
    end
    if isfield(r, 'L_house_w') && ~isempty(r.L_house_w)
        M.total_energy_kwh(i) = sum(r.L_house_w(:)) * default_dt_hr(r) / 1000;
    end
end

% Sort by scenario ID for consistent presentation.
[~, order] = sort(M.ids);
fields = fieldnames(M);
for k = 1:numel(fields)
    f = fields{k};
    if iscell(M.(f))
        M.(f) = M.(f)(order);
    else
        M.(f) = M.(f)(order);
    end
end
end

function label = scenario_label(r)
% SCENARIO_LABEL Human-readable compact scenario label.
id = get_scalar(r, 'scenario_id', NaN);
if isfield(r, 'description') && ~isempty(r.description)
    desc = char(string(r.description));
else
    desc = sprintf('Scenario %g', id);
end
if id == -1
    prefix = 'B0';
else
    prefix = sprintf('S%g', id);
end
label = sprintf('%s: %s', prefix, desc);
if strlength(string(label)) > 34
    label = char(extractBefore(string(label), 34) + "...");
end
end

function x = get_scalar(s, fieldName, defaultValue)
% GET_SCALAR Robust scalar field extraction.
x = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName))
    v = s.(fieldName);
    x = double(v(1));
end
end

function m = mean_valid(v)
% MEAN_VALID Mean of finite values.
v = double(v(:));
v = v(isfinite(v));
if isempty(v), m = NaN; else, m = mean(v); end
end

function dtHr = default_dt_hr(r)
% DEFAULT_DT_HR Infer timestep from result metadata.
dtHr = 0.25;
if isfield(r, 'metadata') && isstruct(r.metadata) && isfield(r.metadata, 'dt_min')
    dtHr = double(r.metadata.dt_min) / 60;
end
end

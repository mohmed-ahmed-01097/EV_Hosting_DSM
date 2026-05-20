function summaryTable = app_scenario_comparison(results, metric, ax)
% APP_SCENARIO_COMPARISON Plot and tabulate multi-scenario KPI comparison.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   results - cell array or struct array of scenario result structs
%   metric  - KPI name, e.g. 'mean_vuf_pct', default 'mean_vuf_pct'
%   ax      - target axes/UIAxes, optional
%
% Outputs:
%   summaryTable - table with Scenario, Description, and selected KPI
%
% Example:
%   T = app_scenario_comparison(all_results, 'mean_vuf_pct', app.CompareAxes);

if nargin < 2 || isempty(metric)
    metric = 'mean_vuf_pct';
end
if nargin < 3
    ax = [];
end

items = normalize_results(results);
n = numel(items);
scenario = strings(n,1);
description = strings(n,1);
value = nan(n,1);

for i = 1:n
    r = items{i};
    scenario(i) = string(get_result_field(r, 'scenario_id', i));
    description(i) = string(get_result_field(r, 'description', ''));
    value(i) = get_pq_metric(r, metric);
end

summaryTable = table(scenario, description, value, ...
    'VariableNames', {'Scenario', 'Description', matlab.lang.makeValidName(metric)});

if ~isempty(ax)
    try
        cla(ax);
style_app_axes(ax);
        bar(ax, value);
        grid(ax, 'on');
style_app_axes(ax);
        xlabel(ax, 'Scenario');
        ylabel(ax, strrep(metric, '_', ' '));
        title(ax, 'Scenario Comparison');
        xticks(ax, 1:n);
        xticklabels(ax, cellstr(scenario));
    catch
    end
end
end

function items = normalize_results(results)
if isempty(results)
    items = {};
elseif iscell(results)
    items = results(:);
elseif isstruct(results) && numel(results) > 1
    items = arrayfun(@(r) r, results(:), 'UniformOutput', false);
elseif isstruct(results)
    items = {results};
else
    items = {};
end
items = items(~cellfun(@isempty, items));
end

function v = get_pq_metric(r, metric)
v = NaN;
try
    if isfield(r, 'pq_summary') && isfield(r.pq_summary, metric)
        x = r.pq_summary.(metric);
        v = mean(x(:), 'omitnan');
    end
catch
end
end

function v = get_result_field(r, name, default)
if isstruct(r) && isfield(r, name)
    v = r.(name);
else
    v = default;
end
end

function results = viz_normalize_results(all_results)
% VIZ_NORMALIZE_RESULTS Convert scenario output to a row cell array of structs.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   all_results: Scenario results from Phase 5. Supported forms:
%       - cell array of result structs
%       - struct array of result structs
%       - single result struct
%
% Outputs:
%   results (1xN cell): Non-empty scenario result structs.
%
% Example:
%   results = viz_normalize_results(all_results);

if nargin < 1 || isempty(all_results)
    error('viz_normalize_results:empty', 'No scenario results were provided.');
end

if iscell(all_results)
    raw = all_results(:)';
elseif isstruct(all_results)
    if numel(all_results) == 1 && isfield(all_results, 'scenario_id')
        raw = {all_results};
    else
        raw = num2cell(all_results(:)');
    end
else
    error('viz_normalize_results:unsupported', 'Unsupported all_results type: %s', class(all_results));
end

keep = false(size(raw));
for i = 1:numel(raw)
    keep(i) = isstruct(raw{i}) && isfield(raw{i}, 'scenario_id');
end
results = raw(keep);

if isempty(results)
    error('viz_normalize_results:noScenarioStructs', 'No valid scenario result structs were found.');
end
end

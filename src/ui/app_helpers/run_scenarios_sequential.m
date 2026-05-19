function allResults = run_scenarios_sequential(ctx, scenarioIds, progress_cb)
% RUN_SCENARIOS_SEQUENTIAL Run selected scenarios sequentially with UI-safe progress.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   ctx         - struct context with fields cfg, data, net, assignment, pop,
%                 cal_struct, weather. This helper is intentionally struct-based
%                 so it can be used from tests, scripts, or app wrapper methods.
%   scenarioIds - numeric vector. Use -1 for Baseline 0, 0..6 for scenarios.
%   progress_cb - optional callback @(pct,msg,sid) for UI/log updates.
%
% Outputs:
%   allResults - cell array of scenario results in input order.
%
% Example:
%   ctx = struct('cfg',cfg,'data',data,'net',net,'assignment',assignment, ...
%                'pop',pop,'cal_struct',cal_struct,'weather',weather);
%   r = run_scenarios_sequential(ctx, [-1 1 4 6], @(p,m,s) fprintf('%g%% %s\n',p,m));
%
% Notes:
%   No parfeval/parfor is used. drawnow('limitrate') keeps compiled apps responsive.

if nargin < 2 || isempty(scenarioIds)
    scenarioIds = [-1 0 1 2 3 4 5 6];
end
if nargin < 3 || isempty(progress_cb) || ~isa(progress_cb, 'function_handle')
    progress_cb = @(pct, msg, sid) [];
end

required = {'cfg','data','net','assignment','pop','cal_struct','weather'};
for k = 1:numel(required)
    if ~isfield(ctx, required{k})
        error('run_scenarios_sequential:missingContext', ...
            'Context is missing required field: %s', required{k});
    end
end

scenarioIds = scenarioIds(:)';
allResults = cell(numel(scenarioIds), 1);

for k = 1:numel(scenarioIds)
    sid = scenarioIds(k);
    batchPctBase = 100 * (k-1) / max(numel(scenarioIds), 1);
    batchPctSpan = 100 / max(numel(scenarioIds), 1);
    progress_cb(round(batchPctBase), sprintf('Scenario %g starting...', sid), sid);
    scenario_cb = @(pct, msg) nested_progress(progress_cb, batchPctBase, batchPctSpan, pct, msg, sid);
    try
        if sid == -1
            result = run_baseline0(ctx.cfg, ctx.data, ctx.net, ctx.assignment, ...
                ctx.pop, ctx.cal_struct, ctx.weather, scenario_cb);
        else
            runFn = str2func(sprintf('run_scenario%d', sid));
            result = runFn(ctx.cfg, ctx.data, ctx.net, ctx.assignment, ...
                ctx.pop, ctx.cal_struct, ctx.weather, scenario_cb);
        end
        allResults{k} = result;
        progress_cb(round(batchPctBase + batchPctSpan), sprintf('Scenario %g complete.', sid), sid);
    catch ME
        allResults{k} = struct('scenario_id', sid, 'error', ME.message);
        progress_cb(round(batchPctBase + batchPctSpan), sprintf('Scenario %g failed: %s', sid, ME.message), sid);
    end
    drawnow('limitrate');
end
end

function nested_progress(progress_cb, basePct, spanPct, pct, msg, sid)
% NESTED_PROGRESS Convert scenario-local percent into batch percent.
batchPct = round(basePct + spanPct * max(0, min(100, pct)) / 100);
progress_cb(batchPct, msg, sid);
drawnow('limitrate');
end

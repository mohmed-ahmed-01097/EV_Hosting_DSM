function allResults = run_scenarios_sequential(appOrContext, scenarioIds)
% RUN_SCENARIOS_SEQUENTIAL Run selected scenarios with drawnow progress updates.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   appOrContext - App object or struct with cfg, data, net, assignment, pop,
%                  cal_struct, weather, and optional log/update methods.
%   scenarioIds  - vector of scenario IDs. Use -1 for Baseline 0.
%
% Outputs:
%   allResults   - cell array of scenario results in input order
%
% Example:
%   r = run_scenarios_sequential(ctx, [-1 1 4 6]);

if nargin < 2 || isempty(scenarioIds)
    scenarioIds = [-1, 0, 1, 2, 3, 4, 5, 6];
end

ctx = appOrContext;
allResults = cell(numel(scenarioIds), 1);

for k = 1:numel(scenarioIds)
    sid = scenarioIds(k);
    set_status(ctx, sid, 'running');
    progressCb = @(pct, msg) handle_progress(ctx, pct, msg, sid);
    try
        if sid == -1
            r = run_baseline0(ctx.cfg, ctx.data, ctx.net, ctx.assignment, ...
                ctx.pop, ctx.cal_struct, ctx.weather, progressCb);
        else
            runFn = str2func(sprintf('run_scenario%d', sid));
            r = runFn(ctx.cfg, ctx.data, ctx.net, ctx.assignment, ...
                ctx.pop, ctx.cal_struct, ctx.weather, progressCb);
        end
        allResults{k} = r;
        set_status(ctx, sid, 'complete');
        write_log(ctx, sprintf('Scenario %g complete.', sid));
    catch ME
        set_status(ctx, sid, 'failed');
        write_log(ctx, sprintf('ERROR Scenario %g: %s', sid, ME.message));
        allResults{k} = struct('scenario_id', sid, 'error', ME.message);
    end
    drawnow('limitrate');
end
end

function handle_progress(ctx, pct, msg, sid)
try
    if isprop(ctx, 'ProgressLabel')
        ctx.ProgressLabel.Text = sprintf('S%g: %d%% - %s', sid, pct, msg);
    elseif isfield(ctx, 'ProgressLabel') && isobject(ctx.ProgressLabel)
        ctx.ProgressLabel.Text = sprintf('S%g: %d%% - %s', sid, pct, msg);
    end
catch
end
try
    if isprop(ctx, 'ProgressBar') && isprop(ctx.ProgressBar, 'Value')
        ctx.ProgressBar.Value = min(max(pct, 0), 100);
    elseif isfield(ctx, 'ProgressBar') && isobject(ctx.ProgressBar) && isprop(ctx.ProgressBar, 'Value')
        ctx.ProgressBar.Value = min(max(pct, 0), 100);
    end
catch
end
write_log(ctx, msg);
drawnow('limitrate');
end

function set_status(ctx, sid, status)
try
    if ismethod(ctx, 'update_card_status')
        ctx.update_card_status(sid, status);
    elseif isfield(ctx, 'scenario_status')
        ctx.scenario_status.(matlab.lang.makeValidName(sprintf('S%g', sid))) = status; %#ok<NASGU>
    end
catch
end
end

function write_log(ctx, msg)
try
    if ismethod(ctx, 'log')
        ctx.log(msg);
    elseif isprop(ctx, 'ExecutionLog')
        app_log(ctx.ExecutionLog, msg);
    elseif isfield(ctx, 'ExecutionLog')
        app_log(ctx.ExecutionLog, msg);
    else
        fprintf('[UI] %s\n', msg);
    end
catch
    fprintf('[UI] %s\n', msg);
end
end

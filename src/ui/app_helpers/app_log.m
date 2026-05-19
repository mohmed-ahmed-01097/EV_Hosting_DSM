function logLines = app_log(target, msg, maxLines)
% APP_LOG Append a timestamped message to a UI TextArea or cellstr log.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   target   - matlab.ui.control.TextArea, cell array, char/string, or []
%   msg      - message to append
%   maxLines - maximum retained lines, default 200
%
% Outputs:
%   logLines - updated cell array of log lines
%
% Example:
%   logLines = app_log({}, 'Scenario 4 started');

if nargin < 3 || isempty(maxLines)
    maxLines = 200;
end
if nargin < 2
    msg = '';
end

line = sprintf('> [%s] %s', datestr(now, 'HH:MM:SS'), char(string(msg)));

if isempty(target)
    logLines = {line};
elseif iscell(target)
    logLines = target(:);
    logLines{end+1, 1} = line;
elseif isstring(target) || ischar(target)
    logLines = cellstr(target);
    logLines{end+1, 1} = line;
elseif isobject(target) && isprop(target, 'Value')
    currentValue = target.Value;
    if ischar(currentValue) || isstring(currentValue)
        logLines = cellstr(currentValue);
    else
        logLines = currentValue(:);
    end
    logLines{end+1, 1} = line;
else
    logLines = {line};
end

if numel(logLines) > maxLines
    logLines = logLines(end-maxLines+1:end);
end

if isobject(target) && isprop(target, 'Value')
    try
        target.Value = logLines;
        try
            scroll(target, 'bottom');
        catch
            % Older MATLAB releases may not support scroll for TextArea.
        end
    catch
        % Keep function safe for non-UI tests and partially constructed apps.
    end
end
end

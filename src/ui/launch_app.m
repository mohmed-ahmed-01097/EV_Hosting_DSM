function app = launch_app()
% LAUNCH_APP Start the EV Hosting DSM MATLAB UI.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   app (EVHostingDSM_App): App handle when requested.
%
% Example:
%   launch_app()
%   app = launch_app();

rootDir = get_root_dir();
addpath(genpath(fullfile(rootDir, 'src')));

if exist('EVHostingDSM_App', 'class') ~= 8
    error('launch_app:missingApp', ...
        'EVHostingDSM_App class was not found on the MATLAB path. Run startup.m first.');
end

appObj = EVHostingDSM_App();

if nargout > 0
    app = appObj;
end
end

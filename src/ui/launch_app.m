function launch_app()
% LAUNCH_APP Start the EV Hosting DSM App Designer UI.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Opens the App Designer UI once EVHostingDSM_App is implemented.
%
% Example:
%   launch_app()
%
% Notes:
%   PART B Step 9 prepares the UI folder and helper layer only. The actual
%   EVHostingDSM_App class is added in Step 10, so this launcher gives a
%   clear message until that file exists.

rootDir = get_root_dir();
addpath(genpath(fullfile(rootDir, 'src')));

appFileMlapp = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.mlapp');
appFileM     = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');

if exist(appFileMlapp, 'file') == 2 || exist(appFileM, 'file') == 2 || exist('EVHostingDSM_App', 'class') == 8
    EVHostingDSM_App();
else
    error('launch_app:notImplemented', ...
        ['EVHostingDSM_App is not implemented yet. ', ...
         'PART B Step 9 created the UI scaffold and helpers. ', ...
         'Implement Step 10 before launching the app.']);
end
end

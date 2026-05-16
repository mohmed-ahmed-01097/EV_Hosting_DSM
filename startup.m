% STARTUP Add project source and test folders to MATLAB path.
% This file is executed automatically when MATLAB starts in this folder.

rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootDir, 'src')));
addpath(genpath(fullfile(rootDir, 'tests')));
fprintf('[startup] EV_Hosting_DSM paths added. Root: %s\n', rootDir);

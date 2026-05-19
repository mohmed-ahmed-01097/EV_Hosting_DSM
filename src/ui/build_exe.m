function build_exe()
% BUILD_EXE Compile EVHostingDSM_App to a standalone Windows executable.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Creates exe/EVHostingDSM_Simulator.exe when MATLAB Compiler is available.
%
% Example:
%   run startup.m
%   build_exe()

rootDir = get_root_dir();
appFileMlapp = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.mlapp');
appFileM     = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');

if exist(appFileMlapp, 'file') == 2
    appFile = appFileMlapp;
elseif exist(appFileM, 'file') == 2
    appFile = appFileM;
else
    error('build_exe:missingApp', ...
        'Neither EVHostingDSM_App.mlapp nor EVHostingDSM_App.m was found.');
end

if exist('compiler.build.standaloneApplication', 'file') ~= 2
    error('build_exe:noCompiler', ...
        'MATLAB Compiler build API is not available in this MATLAB installation.');
end

outDir = fullfile(rootDir, 'exe');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

opts = compiler.build.StandaloneApplicationOptions(appFile, ...
    'OutputDir', outDir, ...
    'ExecutableName', 'EVHostingDSM_Simulator', ...
    'TreatInputsAsNumeric', false);

opts.AdditionalFiles = { ...
    fullfile(rootDir, 'src'), ...
    fullfile(rootDir, 'config'), ...
    fullfile(rootDir, 'data', 'survey', 'Household_Energy_Survey.xlsx'), ...
    fullfile(rootDir, 'data', 'weather') ...
};

compiler.build.standaloneApplication(opts);

fprintf('[build_exe] Done. Executable folder: %s\n', outDir);
end

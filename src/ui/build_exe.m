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
%   Creates exe/EVHostingDSM_Simulator.exe after Step 10+ app implementation.
%
% Example:
%   run startup.m
%   build_exe()
%
% Notes:
%   PART B Step 9 only prepares the UI folder/helper scaffold. Compilation
%   is enabled after the App Designer app exists.

rootDir = get_root_dir();
appFile = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.mlapp');

if exist(appFile, 'file') ~= 2
    error('build_exe:missingApp', ...
        ['EVHostingDSM_App.mlapp was not found. ', ...
         'Complete PART B Step 10 before compiling.']);
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

function build_exe(varargin)
% BUILD_EXE Compile the EV Hosting DSM UI to a standalone executable.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   Optional name-value pairs:
%     'dry_run' (logical): If true, validate the build manifest without compiling.
%
% Outputs:
%   Creates exe/EVHostingDSM_Simulator.exe when MATLAB Compiler is available.
%
% Example:
%   run startup.m
%   build_exe()
%   build_exe('dry_run', true)
%
% Notes:
%   The compiled entry point is launch_app.m, not the class file directly.
%   This is important because EVHostingDSM_App.m is a classdef file and should
%   be included as a dependency/support file, while launch_app.m is the
%   executable startup function.

optsLocal = parse_build_options(varargin{:});
rootDir = resolve_build_root();

srcDir = fullfile(rootDir, 'src');
if exist(srcDir, 'dir') == 7
    addpath(genpath(srcDir));
end

mainFile = fullfile(rootDir, 'src', 'ui', 'launch_app.m');
appClassFile = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');

if exist(mainFile, 'file') ~= 2
    error('build_exe:missingEntryPoint', 'Missing UI entry point: %s', mainFile);
end
if exist(appClassFile, 'file') ~= 2
    error('build_exe:missingAppClass', 'Missing app class file: %s', appClassFile);
end

outDir = fullfile(rootDir, 'exe');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

additionalFiles = collect_additional_files(rootDir);
manifest = write_build_manifest(rootDir, outDir, mainFile, additionalFiles);
write_distribution_readme(outDir, manifest);

fprintf('[build_exe] Project root : %s\n', rootDir);
fprintf('[build_exe] Entry point  : %s\n', mainFile);
fprintf('[build_exe] Output dir   : %s\n', outDir);
fprintf('[build_exe] Add files    : %d item(s)\n', numel(additionalFiles));

if optsLocal.dry_run
    fprintf('[build_exe] Dry run only. Build manifest written to exe/build_manifest.json\n');
    return;
end

if has_compiler_build_api()
    build_with_compiler_api(mainFile, outDir, additionalFiles);
elseif has_mcc_fallback()
    build_with_mcc(mainFile, outDir, additionalFiles);
else
    error('build_exe:noCompiler', ...
        ['MATLAB Compiler is not available. Install/activate MATLAB Compiler, ' ...
         'then run build_exe() again.']);
end

fprintf('[build_exe] Done.\n');
fprintf('[build_exe] Executable folder: %s\n', outDir);
fprintf('[build_exe] Distribute the whole exe folder, not only the .exe file.\n');
fprintf('[build_exe] Users need MATLAB Runtime matching your MATLAB release.\n');
end

function optsLocal = parse_build_options(varargin)
% PARSE_BUILD_OPTIONS Parse small name-value option set.
optsLocal.dry_run = false;

if mod(numel(varargin), 2) ~= 0
    error('build_exe:invalidOptions', 'Options must be name-value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case {'dry_run', 'dryrun'}
            optsLocal.dry_run = logical(value);
        otherwise
            error('build_exe:unknownOption', 'Unknown option: %s', name);
    end
end
end

function rootDir = resolve_build_root()
% RESOLVE_BUILD_ROOT Resolve project root from helper or from this file.
try
    rootDir = get_root_dir();
catch
    thisFile = mfilename('fullpath');
    uiDir = fileparts(thisFile);          % .../src/ui
    srcDir = fileparts(uiDir);            % .../src
    rootDir = fileparts(srcDir);          % project root
end
end

function files = collect_additional_files(rootDir)
% COLLECT_ADDITIONAL_FILES Support files bundled into the compiled CTF.
files = {};

candidates = { ...
    fullfile(rootDir, 'src'), ...
    fullfile(rootDir, 'config'), ...
    fullfile(rootDir, 'data', 'survey', 'Household_Energy_Survey.xlsx'), ...
    fullfile(rootDir, 'data', 'weather') ...
};

for k = 1:numel(candidates)
    if exist(candidates{k}, 'dir') == 7 || exist(candidates{k}, 'file') == 2
        files{end + 1, 1} = candidates{k}; %#ok<AGROW>
    end
end
end

function manifest = write_build_manifest(rootDir, outDir, mainFile, additionalFiles)
% WRITE_BUILD_MANIFEST Write machine-readable build metadata.
manifest = struct();
manifest.project = 'EV_Hosting_DSM';
manifest.executable_name = 'EVHostingDSM_Simulator';
manifest.root_dir = rootDir;
manifest.output_dir = outDir;
manifest.entry_point = mainFile;
manifest.additional_files = additionalFiles;
manifest.created_on = datestr(now, 31);
manifest.matlab_version = version;
manifest.runtime_note = 'Requires MATLAB Runtime matching the MATLAB release used for compilation.';
manifest.results_location_deployed = fullfile(get_userpath_safe(), 'EV_DSM_Results');
manifest.config_location_deployed = fullfile(get_userpath_safe(), 'EV_DSM_config.json');

jsonText = jsonencode(manifest, 'PrettyPrint', true);
fid = fopen(fullfile(outDir, 'build_manifest.json'), 'w');
if fid < 0
    error('build_exe:manifestWriteFailed', 'Could not write build manifest.');
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonText);
clear cleanupObj;
end

function write_distribution_readme(outDir, manifest)
% WRITE_DISTRIBUTION_README Write concise deployment notes.
readmePath = fullfile(outDir, 'README_DISTRIBUTION.txt');
fid = fopen(readmePath, 'w');
if fid < 0
    warning('build_exe:readmeWriteFailed', 'Could not write distribution README.');
    return;
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'EV Hosting DSM Simulator - Distribution Notes\n');
fprintf(fid, '=============================================\n\n');
fprintf(fid, 'Executable name: %s.exe\n', manifest.executable_name);
fprintf(fid, 'Built on       : %s\n', manifest.created_on);
fprintf(fid, 'MATLAB version : %s\n\n', manifest.matlab_version);
fprintf(fid, 'Distribute the entire exe folder generated by MATLAB Compiler.\n');
fprintf(fid, 'Do not distribute only the .exe file.\n\n');
fprintf(fid, 'Compiled-app user output folder:\n  %s\n\n', manifest.results_location_deployed);
fprintf(fid, 'Compiled-app user config file:\n  %s\n\n', manifest.config_location_deployed);
fprintf(fid, 'Users need the MATLAB Runtime matching the compiler MATLAB release.\n');
clear cleanupObj;
end

function tf = has_compiler_build_api()
% HAS_COMPILER_BUILD_API True when the newer compiler.build API is available.
tf = exist('compiler.build.standaloneApplication', 'file') == 2 || ...
     exist('compiler.build.standaloneApplication', 'builtin') == 5;
end

function tf = has_mcc_fallback()
% HAS_MCC_FALLBACK True when mcc command is available.
tf = exist('mcc', 'file') == 2;
end

function build_with_compiler_api(mainFile, outDir, additionalFiles)
% BUILD_WITH_COMPILER_API Build using compiler.build standalone API.
options = compiler.build.StandaloneApplicationOptions(mainFile, ...
    'OutputDir', outDir, ...
    'ExecutableName', 'EVHostingDSM_Simulator', ...
    'TreatInputsAsNumeric', false);

options.AdditionalFiles = additionalFiles;
compiler.build.standaloneApplication(options);
end

function build_with_mcc(mainFile, outDir, additionalFiles)
% BUILD_WITH_MCC Fallback build for older MATLAB Compiler installations.
args = {'-m', mainFile, '-o', 'EVHostingDSM_Simulator', '-d', outDir};
for k = 1:numel(additionalFiles)
    args = [args, {'-a', additionalFiles{k}}]; %#ok<AGROW>
end
mcc(args{:});
end

function up = get_userpath_safe()
% GET_USERPATH_SAFE Return a writable user folder without requiring deployment.
up = userpath;
if iscell(up)
    up = up{1};
end
if isstring(up)
    up = char(up);
end
if isempty(up)
    up = fullfile(tempdir, 'EV_Hosting_DSM_User');
else
    parts = strsplit(up, pathsep);
    up = parts{1};
end
if isempty(up)
    up = fullfile(tempdir, 'EV_Hosting_DSM_User');
end
end

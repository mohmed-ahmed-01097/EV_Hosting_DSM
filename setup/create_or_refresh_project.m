function create_or_refresh_project()
% CREATE_OR_REFRESH_PROJECT Create or refresh the MATLAB Project definition.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Creates EV_Hosting_DSM.prj using MATLAB Project API when available.
%
% Example:
%   create_or_refresh_project()

rootDir = fileparts(fileparts(mfilename('fullpath')));
projectName = 'EV_Hosting_DSM';
prjFile = fullfile(rootDir, [projectName '.prj']);

try
    if isfile(prjFile)
        proj = openProject(prjFile);
    else
        proj = matlab.project.createProject(rootDir);
        proj.Name = projectName;
    end

    addPath(proj, 'src');
    addPath(proj, 'src/io');
    addPath(proj, 'src/feeder');
    addPath(proj, 'src/models');
    addPath(proj, 'src/pricing');
    addPath(proj, 'src/dsm');
    addPath(proj, 'src/scenarios');
    addPath(proj, 'src/twin');
    addPath(proj, 'src/uq');
    addPath(proj, 'src/viz');
    addPath(proj, 'tests');

    proj.StartupFiles = {'startup.m'};

    save(proj);
    fprintf('[create_or_refresh_project] MATLAB Project ready: %s\n', prjFile);
catch ME
    warning('create_or_refresh_project:apiUnavailable', ...
        'Could not create project using MATLAB Project API: %s', ME.message);
    fprintf('You can still use this folder by running startup.m manually.\n');
end
end

function rootDir = get_root_dir()
% GET_ROOT_DIR Return project root in MATLAB and compiled applications.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Outputs:
%   rootDir (char): Project root folder in MATLAB, or CTF root in compiled mode.
%
% Example:
%   rootDir = get_root_dir();
if isdeployed
    rootDir = ctfroot;
else
    thisFile = mfilename('fullpath');
    % .../src/ui/app_helpers/get_root_dir.m -> project root
    rootDir = fileparts(fileparts(fileparts(fileparts(thisFile))));
end
end

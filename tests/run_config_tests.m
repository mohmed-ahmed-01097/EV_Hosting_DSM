function run_config_tests()
% RUN_CONFIG_TESTS Run all Step 1 and pre-Phase 0 readiness tests.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL results.
%
% Example:
%   run_config_tests()

thisFile = mfilename('fullpath');
testsDir = fileparts(thisFile);
rootDir = fileparts(testsDir);
addpath(genpath(fullfile(rootDir, 'src')));
addpath(testsDir);

test_config_loader();
test_survey_schema();

fprintf('\n[run_config_tests] Step 1 + survey readiness are valid. You can now implement Phase 0 IO functions.\n');
end

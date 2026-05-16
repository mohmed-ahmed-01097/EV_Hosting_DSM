function run_config_tests()
% RUN_CONFIG_TESTS Run all Step 1, survey, and Phase 0 IO tests.
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
test_phase0_io();

fprintf('\n[run_config_tests] Step 1 + Phase 0 IO deliverables are valid. You can now start Phase 1 feeder modeling.\n');
end

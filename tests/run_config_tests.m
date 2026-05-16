function run_config_tests()
% RUN_CONFIG_TESTS Run Step 1, survey, Phase 0 IO, and Phase 1 feeder tests.
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
test_phase1_feeder();
test_bfs_power_flow();
test_pq_indices();

fprintf('\n[run_config_tests] Step 1 + Phase 0 + Phase 1 deliverables are valid. You can now start Phase 2 load modeling.\n');
end

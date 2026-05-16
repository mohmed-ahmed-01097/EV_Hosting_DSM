function test_config_loader()
% TEST_CONFIG_LOADER Validate configuration JSON files and loader behavior.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation results.
%
% Example:
%   test_config_loader()

fprintf('\n[test_config_loader] Starting configuration validation...\n');

thisFile = mfilename('fullpath');
testsDir = fileparts(thisFile);
rootDir = fileparts(testsDir);
addpath(genpath(fullfile(rootDir, 'src')));

scenarioFiles = {
    ''
    fullfile('config', 'scenario_configs', 'baseline0.json')
    fullfile('config', 'scenario_configs', 'scenario0.json')
    fullfile('config', 'scenario_configs', 'scenario1.json')
    fullfile('config', 'scenario_configs', 'scenario2.json')
    fullfile('config', 'scenario_configs', 'scenario3.json')
    fullfile('config', 'scenario_configs', 'scenario4.json')
    fullfile('config', 'scenario_configs', 'scenario5.json')
    fullfile('config', 'scenario_configs', 'scenario6.json')
};

passCount = 0;
failCount = 0;

for i = 1:numel(scenarioFiles)
    try
        cfg = config_loader(scenarioFiles{i});

        assert(isfield(cfg, 'location'));
        assert(isfield(cfg, 'simulation'));
        assert(isfield(cfg, 'feeder'));
        assert(isfield(cfg, 'ev'));
        assert(isfield(cfg, 'pricing'));
        assert(isfield(cfg, 'pq_limits'));
        assert(isfield(cfg, 'dsm'));

        assert(ismember(cfg.simulation.dt_min, [1 5 10 15]));
        assert(cfg.simulation.Tsteps > 0);
        assert(cfg.simulation.dt_hr > 0);
        assert(numel(cfg.simulation.tvec_min) == cfg.simulation.Tsteps);

        assert(sum(cfg.feeder.households_per_zone) == cfg.feeder.num_households);
        assert(cfg.ev.soc_min_pct < cfg.ev.soc_target_pct);
        assert(cfg.pq_limits.voltage_min_pu < cfg.pq_limits.voltage_max_pu);
        assert(numel(cfg.pricing.tou_rates_24h) == 24);
        assert(isfile(cfg.feeder_params_path));
        assert(exist(cfg.output_dir, 'dir') == 7);
        assert(exist(cfg.figs_dir, 'dir') == 7);
        assert(exist(cfg.tables_dir, 'dir') == 7);
        assert(validate_feeder_params(cfg.feeder_params_path));

        fprintf('  PASS: %s\n', scenario_label(scenarioFiles{i}));
        passCount = passCount + 1;

    catch ME
        fprintf('  FAIL: %s\n', scenario_label(scenarioFiles{i}));
        fprintf('        %s\n', ME.message);
        failCount = failCount + 1;
    end
end

fprintf('[test_config_loader] Complete. PASS=%d | FAIL=%d\n', passCount, failCount);

if failCount > 0
    error('test_config_loader:failed', '%d configuration validation(s) failed.', failCount);
end

end

function label = scenario_label(pathValue)
if isempty(pathValue)
    label = 'default_config.json';
else
    label = pathValue;
end
end

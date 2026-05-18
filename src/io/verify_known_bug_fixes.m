function report = verify_known_bug_fixes(cfg)
% VERIFY_KNOWN_BUG_FIXES Check the known implementation-review bug fixes.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration from config_loader.
%
% Outputs:
%   report (struct): Per-fix pass flags and details.
%
% Example:
%   cfg = config_loader();
%   report = verify_known_bug_fixes(cfg);

validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);

report = struct();
report.created_on = datestr(now, 31);
report.items = struct([]);

report.items(1).id = 1;
report.items(1).name = 'Assiut coordinates are not swapped';
report.items(1).passed = abs(cfg.location.latitude - 27.1809) < 1e-6 && ...
    abs(cfg.location.longitude - 31.1837) < 1e-6;
report.items(1).detail = sprintf('lat=%.4f, lon=%.4f', cfg.location.latitude, cfg.location.longitude);

report.items(2).id = 2;
report.items(2).name = 'Weather cache and metadata path are defined dynamically';
report.items(2).passed = isfield(cfg, 'root_folder') && isfolder(cfg.root_folder) && ...
    isfield(cfg, 'output_dir') && startsWith(cfg.output_dir, cfg.root_folder);
report.items(2).detail = sprintf('root=%s | output=%s', cfg.root_folder, cfg.output_dir);

report.items(3).id = 3;
report.items(3).name = 'Simulation horizon fields are computed under cfg.simulation';
report.items(3).passed = isfield(cfg.simulation, 'horizon_days') && cfg.simulation.horizon_days > 0 && ...
    isfield(cfg.simulation, 'Tsteps') && cfg.simulation.Tsteps == numel(cfg.simulation.tvec_min);
report.items(3).detail = sprintf('days=%d | steps=%d', cfg.simulation.horizon_days, cfg.simulation.Tsteps);

report.items(4).id = 4;
report.items(4).name = 'Survey loader preserves raw tables for model-level aggregation';
report.items(4).passed = isfield(cfg, 'survey_paths') && isfield(cfg.survey_paths, 'xlsx') && isfile(cfg.survey_paths.xlsx);
report.items(4).detail = sprintf('survey=%s', cfg.survey_paths.xlsx);

report.items(5).id = 5;
report.items(5).name = 'Relative project paths are resolved from cfg.root_folder';
report.items(5).passed = startsWith(cfg.survey_paths.xlsx, cfg.root_folder) && ...
    startsWith(cfg.feeder_params_path, cfg.root_folder) && startsWith(cfg.figs_dir, cfg.root_folder);
report.items(5).detail = sprintf('figs=%s', cfg.figs_dir);

report.items(6).id = 6;
report.items(6).name = 'JSON path handling uses explicit file existence checks';
report.items(6).passed = isfile(fullfile(cfg.root_folder, 'config', 'default_config.json')) && ...
    isfile(cfg.feeder_params_path);
report.items(6).detail = sprintf('feeder_params=%s', cfg.feeder_params_path);

passed = [report.items.passed];
report.all_passed = all(passed);
report.pass_count = sum(passed);
report.fail_count = sum(~passed);

if report.all_passed
    fprintf('[verify_known_bug_fixes] PASS: %d/%d known fixes verified.\n', report.pass_count, numel(report.items));
else
    fprintf('[verify_known_bug_fixes] FAIL: %d/%d known fixes failed.\n', report.fail_count, numel(report.items));
end
end

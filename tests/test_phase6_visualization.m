function test_phase6_visualization()
% TEST_PHASE6_VISUALIZATION Validate Phase 6 visualization functions.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation messages.
%
% Example:
%   test_phase6_visualization()

fprintf('\n[test_phase6_visualization] Starting Phase 6 visualization validation...\n');

cfg = config_loader();
% Use the dynamic output paths produced by config_loader.
% Do not override cfg.output_dir here: default_config.json controls the output
% folder, and config_loader resolves it against cfg.root_folder at runtime.
if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figs_dir, 'dir'), mkdir(cfg.figs_dir); end
if ~exist(cfg.tables_dir, 'dir'), mkdir(cfg.tables_dir); end

all_results = build_synthetic_results(cfg);

out1 = plot_scenario_comparison(all_results, cfg);
assert_file_set(out1.files, 'scenario comparison');
assert_pass(startsWith(out1.files.png, cfg.figs_dir), ...
    sprintf('Phase 6 PNG exports use dynamic project results path: %s', cfg.figs_dir));
fprintf('  PASS: plot_scenario_comparison exported PNG/EPS/FIG\n');

out2 = plot_pq_indices(all_results, cfg);
assert_file_set(out2.files, 'PQ indices');
fprintf('  PASS: plot_pq_indices exported PNG/EPS/FIG\n');

out3 = plot_load_profiles(all_results, cfg);
assert_file_set(out3.files, 'load profiles');
fprintf('  PASS: plot_load_profiles exported PNG/EPS/FIG\n');

out4 = plot_hosting_capacity(all_results, cfg);
assert_file_set(out4.files, 'hosting capacity');
fprintf('  PASS: plot_hosting_capacity exported PNG/EPS/FIG\n');

assert_pass(isfield(out1.metrics, 'max_vuf_pct'), 'Scenario metrics include max VUF');
assert_pass(numel(out3.profile_data.labels) >= 1, 'Load-profile figure retained plotted profile data');

fprintf('[test_phase6_visualization] Complete. Phase 6 visualization validation passed.\n');
end

function all_results = build_synthetic_results(cfg)
% BUILD_SYNTHETIC_RESULTS Create small Phase 5-like result structs.
stepsPerDay = 24 * 60 / cfg.simulation.dt_min;
T = stepsPerDay * 2;
H = 6;
hour = mod((0:T-1)' * cfg.simulation.dt_min / 60, 24);
baseShape = 600 + 400 * exp(-((hour - 20) / 3).^2) + 250 * exp(-((hour - 14) / 4).^2);
phaseSplit = [0.34 0.33 0.33; 0.38 0.31 0.31; 0.34 0.34 0.32];
ids = [-1 1 4 6];
desc = {'Baseline 0', 'Uncontrolled EV', 'MILP loads plus EV', 'Full hierarchical AI-DSM'};
vuf = [0.8 3.1 1.7 1.2];
tl = [72 116 93 86];
hc = [0 20 35 45];
ci = [NaN NaN 0.78 0.70];
all_results = cell(1, numel(ids));
for k = 1:numel(ids)
    L_feeder_w = zeros(T, 3);
    scale = 1 + 0.16 * (k - 1);
    for ph = 1:3
        L_feeder_w(:, ph) = scale * phaseSplit(min(k, 3), ph) * baseShape * 100;
    end
    L_house_w = repmat(sum(L_feeder_w, 2) / H, 1, H);
    pqCells = cell(T, 1);
    for t = 1:T
        pq = struct();
        pq.VUF_pct = vuf(k) * ones(1, 8) * (0.8 + 0.2 * sin(2*pi*t/T)^2);
        pq.IUF_pct = 0.5 * pq.VUF_pct;
        pq.NCR_pct = 5 + 2 * k;
        pq.TL_pct = tl(k) * ones(1, 5) * (0.75 + 0.25 * sin(2*pi*t/T)^2);
        pq.V_min_pu = 1.0 - 0.02 * k - 0.01 * sin(2*pi*t/T)^2;
        pq.Ploss_kW = 1 + 0.3 * k;
        pq.Ploss_kvar = 0.8 + 0.2 * k;
        pqCells{t} = pq;
    end
    costs = struct();
    costs.bill_total = struct();
    costs.bill_total.Flat = (80 + 15*k) * ones(H, 1);
    costs.bill_total.Block = (90 + 18*k) * ones(H, 1);
    r = struct();
    r.scenario_id = ids(k);
    r.description = desc{k};
    r.pq_summary = struct('mean_vuf_pct', 0.7*vuf(k), 'max_vuf_pct', vuf(k), ...
        'min_voltage_pu', 1.0 - 0.025*k, 'max_loading_pct', tl(k), ...
        'mean_loss_kw', 1 + 0.3*k, 'mean_loss_kvar', 0.8 + 0.2*k, ...
        'violation_count', max(0, round((tl(k)-100)/5)), 'has_violations', tl(k) > 100);
    r.pq_timeseries = pqCells;
    r.costs = costs;
    r.hosting_capacity_pct = hc(k);
    r.comfort_summary = struct('mean', ci(k), 'min', max(0, ci(k)-0.1), 'max', min(1, ci(k)+0.1), 'count', H);
    r.L_feeder_w = L_feeder_w;
    r.L_house_w = L_house_w;
    r.runtime_s = 1.0 + k;
    r.metadata = struct('dt_min', cfg.simulation.dt_min, 'num_steps', T);
    all_results{k} = r;
end
end

function assert_file_set(files, label)
% ASSERT_FILE_SET Verify exported files exist.
assert_pass(isstruct(files), sprintf('%s export returned a file struct', label));
assert_pass(isfile(files.png), sprintf('%s PNG exists: %s', label, files.png));
assert_pass(isfile(files.eps), sprintf('%s EPS exists: %s', label, files.eps));
assert_pass(isfile(files.fig), sprintf('%s FIG exists: %s', label, files.fig));
end

function assert_pass(condition, message)
% ASSERT_PASS Print PASS/FAIL and throw on failure.
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase6_visualization:assertionFailed', '%s', message);
end
end

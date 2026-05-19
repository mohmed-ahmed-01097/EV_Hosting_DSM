function test_part_a_bug_fixes()
% TEST_PART_A_BUG_FIXES Validate Phase 10 PART A bug-fix hooks.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs: none. Outputs: PASS/FAIL messages.
%
% Example:
%   test_part_a_bug_fixes()

fprintf('\n[test_part_a_bug_fixes] Starting Phase 10 PART A bug-fix validation...\n');
cfg = config_loader();

assert_pass(isfield(cfg.dsm, 'lambda_comfort') && abs(cfg.dsm.lambda_comfort - 0.001) < 1e-12, ...
    sprintf('BUG-01 lambda_comfort present: %.4g', cfg.dsm.lambda_comfort));
assert_pass(isfield(cfg.dsm, 'comfort_ci_threshold') && abs(cfg.dsm.comfort_ci_threshold - 0.30) < 1e-12, ...
    sprintf('BUG-01 comfort_ci_threshold present: %.2f', cfg.dsm.comfort_ci_threshold));
assert_pass(isfield(cfg.ev, 'v2g_revenue_fraction') && abs(cfg.ev.v2g_revenue_fraction - 0.50) < 1e-12, ...
    sprintf('BUG-03 v2g_revenue_fraction present: %.2f', cfg.ev.v2g_revenue_fraction));

net = build_feeder_network(cfg);
params = jsondecode(fileread(cfg.feeder_params_path));
branch = params.branches(1);
neutral = params.conductors.neutral;
expectedZn = neutral.multiplier * complex(neutral.r_ohm_per_km, neutral.x_ohm_per_km) * branch.length_m / 1000;
assert_pass(abs(net.Zneutral(1) - expectedZn) < 1e-9, ...
    sprintf('BUG-02 neutral multiplier used: |Zn1|=%.6f ohm', abs(net.Zneutral(1))));

assert_pass(exist(fullfile(cfg.root_folder, 'src', 'feeder', 'compute_harmonic_pq.m'), 'file') == 2, ...
    'BUG-05 compute_harmonic_pq.m exists');
assert_pass(exist(fullfile(cfg.root_folder, 'src', 'uq', 'sensitivity_analysis.m'), 'file') == 2 && ...
    exist(fullfile(cfg.root_folder, 'src', 'uq', 'monte_carlo_runner.m'), 'file') == 2, ...
    'BUG-06 UQ utilities exist');
assert_pass(exist(fullfile(cfg.root_folder, 'src', 'ui', 'app_helpers', 'get_root_dir.m'), 'file') == 2, ...
    'BUG-08 get_root_dir.m exists');

S = zeros(3, net.n_buses);
S(1,1) = 3000 + 1j * 900;
[V, I, In, ok] = bfs_power_flow(net, S, struct());
pq = compute_pq_indices(V, I, In, S, net, cfg);
pq = compute_harmonic_pq(pq, 3700 * ones(1, net.n_buses), struct(), net, cfg);
assert_pass(ok, 'BUG-05 harmonic fixture BFS converged');
assert_pass(max(pq.THDi_pct(:)) > 0, sprintf('BUG-05 THDi populated: %.3f%%', max(pq.THDi_pct(:))));
assert_pass(max(pq.Kfactor(:)) > 1, sprintf('BUG-05 K-factor populated: %.3f', max(pq.Kfactor(:))));

% Static signature check for progress callbacks to avoid long population runs.
assert_pass(contains(fileread(fullfile(cfg.root_folder, 'src', 'models', 'simulate_population.m')), 'progress_cb'), ...
    'BUG-04 simulate_population has progress_cb hook');
assert_pass(contains(fileread(fullfile(cfg.root_folder, 'src', 'dsm', 'feeder_supervisor.m')), 'progress_cb'), ...
    'BUG-04 feeder_supervisor has progress_cb hook');
assert_pass(contains(fileread(fullfile(cfg.root_folder, 'src', 'scenarios', 'run_scenario_core.m')), 'progress_cb'), ...
    'BUG-04 run_scenario_core has progress_cb hook');

scenario2Text = fileread(fullfile(cfg.root_folder, 'src', 'scenarios', 'run_scenario2.m'));
assert_pass(contains(scenario2Text, 'results.slow') && contains(scenario2Text, 'results.fast'), ...
    'BUG-07 run_scenario2 returns slow and fast sub-results');

fprintf('[test_part_a_bug_fixes] Complete. PART A bug-fix hooks validated.\n');
end

function assert_pass(cond, msg)
% ASSERT_PASS Print PASS or throw FAIL.
if cond
    fprintf('  PASS: %s\n', msg);
else
    fprintf('  FAIL: %s\n', msg);
    error('test_part_a_bug_fixes:assertion', msg);
end
end

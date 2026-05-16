function test_bfs_power_flow()
% TEST_BFS_POWER_FLOW Validate Phase 1 BFS power-flow implementation.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL results with quantified values.
%
% Example:
%   test_bfs_power_flow()

fprintf('\n[test_bfs_power_flow] Starting Phase 1 BFS tests...\n');
cfg = config_loader();
net = build_feeder_network(cfg);

% --- Test 1: Balanced load gives near-zero VUF ---
S_bal = (3500 + 1j * 900) * ones(3, net.n_buses);
[V, I, In, ok] = bfs_power_flow(net, S_bal, struct());
pq = compute_pq_indices(V, I, In, S_bal, net, cfg);
assert_pass(ok, 'BFS converged for balanced load');
assert_pass(max(pq.VUF_pct) < 0.10, sprintf('Balanced VUF < 0.1%%: %.4f%%', max(pq.VUF_pct)));

% --- Test 2: Phase A unbalance is measurable and positive ---
S_unbal = S_bal;
S_unbal(1,:) = 1.30 * S_unbal(1,:);
[V2, I2, In2, ok2] = bfs_power_flow(net, S_unbal, struct());
pq2 = compute_pq_indices(V2, I2, In2, S_unbal, net, cfg);
assert_pass(ok2, 'BFS converged for 30% phase-A unbalance');
assert_pass(max(pq2.VUF_pct) > 0.01, sprintf('30%% phase-A unbalance gives measurable VUF: %.4f%%', max(pq2.VUF_pct)));
assert_pass(max(In2) > 0.1, sprintf('30%% phase-A unbalance gives neutral current: %.2f A', max(In2)));

% --- Test 3: No load leaves buses at source voltage ---
S_zero = zeros(3, net.n_buses);
[V0, I0, In0, ok0] = bfs_power_flow(net, S_zero, struct());
sourceV = net.Vsource_pu(:) * net.Vbase_ln;
errPu = max(abs(V0 - repmat(sourceV, 1, net.n_buses)), [], 'all') / net.Vbase_ln;
assert_pass(ok0, 'BFS converged for no-load case');
assert_pass(errPu < 1e-9, sprintf('No-load voltages equal source: error %.3e pu', errPu));
assert_pass(max(abs(I0(:))) < 1e-9 && max(In0) < 1e-9, 'No-load currents are zero');

% --- Test 4: Heavy end-of-feeder load causes voltage drop ---
S_heavy = zeros(3, net.n_buses);
endBuses = find(cellfun(@(s) endsWith(s, 'B') || strcmp(s, 'Bus_5A'), net.bus_names));
if isempty(endBuses)
    endBuses = net.n_buses;
end
S_heavy(:, endBuses) = (28000 + 1j * 9000);
[Vh, Ih, Inh, okh] = bfs_power_flow(net, S_heavy, struct());
pqh = compute_pq_indices(Vh, Ih, Inh, S_heavy, net, cfg);
assert_pass(okh, 'BFS converged for heavy end-of-feeder load');
assert_pass(pqh.V_min_pu < 0.98, sprintf('Heavy end load reduces voltage: Vmin %.4f pu', pqh.V_min_pu));

% --- Test 5: Losses are positive under load ---
assert_pass(pq.Ploss_kW > 0, sprintf('Balanced-load active losses are positive: %.4f kW', pq.Ploss_kW));
assert_pass(pq.Qloss_kvar > 0, sprintf('Balanced-load reactive losses are positive: %.4f kvar', pq.Qloss_kvar));

fprintf('[test_bfs_power_flow] Complete.\n');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_bfs_power_flow:assertionFailed', message);
end
end

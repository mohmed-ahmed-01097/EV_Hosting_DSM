function test_pq_indices()
% TEST_PQ_INDICES Validate Phase 1 PQ index calculations.
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
%   test_pq_indices()

fprintf('\n[test_pq_indices] Starting Phase 1 PQ tests...\n');
cfg = config_loader();
net = build_feeder_network(cfg);

% --- Test 1: Balanced VUF/IUF/NCR are near zero ---
S_bal = (4000 + 1j * 1200) * ones(3, net.n_buses);
[V, I, In, ok] = bfs_power_flow(net, S_bal, struct());
pq = compute_pq_indices(V, I, In, S_bal, net, cfg);
assert_pass(ok, 'BFS converged before PQ checks');
assert_pass(max(pq.VUF_pct) < 0.10, sprintf('Balanced VUF near zero: %.5f%%', max(pq.VUF_pct)));
assert_pass(max(pq.IUF_pct) < 0.10, sprintf('Balanced IUF near zero: %.5f%%', max(pq.IUF_pct)));
assert_pass(max(pq.NCR_pct) < 0.10, sprintf('Balanced NCR near zero: %.5f%%', max(pq.NCR_pct)));

% --- Test 2: Purely resistive load has PF = 1 ---
S_res = 3500 * ones(3, net.n_buses);
[Vr, Ir, Inr, okr] = bfs_power_flow(net, S_res, struct());
pqr = compute_pq_indices(Vr, Ir, Inr, S_res, net, cfg);
assert_pass(okr, 'BFS converged for resistive load');
assert_pass(max(abs(pqr.PF_phase(:) - 1)) < 1e-12, ...
    sprintf('Purely resistive PF = 1, max error %.3e', max(abs(pqr.PF_phase(:) - 1))));

% --- Test 3: Boundary violation flags fire for voltage and loading ---
% Use a severe but still numerically solvable end-of-feeder loading case.
% The previous version loaded every bus with 55 kVA/phase, which drove the
% fixed-point BFS iteration outside a physically meaningful operating region
% and made the test fail on solver convergence rather than PQ flag behavior.
S_heavy = zeros(3, net.n_buses);
endBuses = find(cellfun(@(s) endsWith(s, 'B') || strcmp(s, 'Bus_5A'), net.bus_names));
if isempty(endBuses)
    endBuses = net.n_buses;
end
S_heavy(:, endBuses) = (28000 + 1j * 9000);
[Vh, Ih, Inh, okh] = bfs_power_flow(net, S_heavy, struct());
pqh = compute_pq_indices(Vh, Ih, Inh, S_heavy, net, cfg);
assert_pass(okh, 'BFS converged for heavy but solvable PQ violation case');
assert_pass(islogical(pqh.violations.voltage) || isnumeric(pqh.violations.voltage), ...
    'Voltage violation flag exists');
assert_pass(islogical(pqh.violations.loading) || isnumeric(pqh.violations.loading), ...
    'Loading violation flag exists');
assert_pass(pqh.violations.voltage, sprintf('Voltage violation flag fires: Vmin %.4f pu', pqh.V_min_pu));
assert_pass(pqh.violations.loading, sprintf('Loading violation flag fires: max TL %.2f%%', max(pqh.TL_pct)));
assert_pass(pqh.V_min_pu < pq.V_min_pu, sprintf('Heavy case voltage lower than nominal-load case: %.4f < %.4f pu', pqh.V_min_pu, pq.V_min_pu));

% --- Test 4: PQ struct has no NaN/Inf values ---
assert_pass(~contains_bad_numeric(pq), 'PQ struct for balanced load has no NaN/Inf');
assert_pass(~contains_bad_numeric(pqh), 'PQ struct for heavy load has no NaN/Inf');

fprintf('[test_pq_indices] Complete.\n');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_pq_indices:assertionFailed', message);
end
end

function tf = contains_bad_numeric(value)
tf = false;
if isnumeric(value)
    tf = any(isnan(value(:)) | isinf(value(:)));
elseif isstruct(value)
    fields = fieldnames(value);
    for k = 1:numel(fields)
        tf = tf || contains_bad_numeric(value.(fields{k}));
        if tf
            return;
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        tf = tf || contains_bad_numeric(value{k});
        if tf
            return;
        end
    end
end
end

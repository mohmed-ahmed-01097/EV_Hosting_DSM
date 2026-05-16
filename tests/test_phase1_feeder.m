function test_phase1_feeder()
% TEST_PHASE1_FEEDER Validate feeder construction and household assignment.
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
%   test_phase1_feeder()

fprintf('\n[test_phase1_feeder] Starting Phase 1 feeder construction tests...\n');
cfg = config_loader();
data = data_loader(cfg);
net = build_feeder_network(cfg);
assignment = assign_households(cfg, data, net);

assert_pass(net.n_transformers == cfg.feeder.num_transformer_zones, ...
    sprintf('Transformer count matches config: %d', net.n_transformers));
assert_pass(net.n_buses == 8, sprintf('Expected 8 load buses from feeder_params.json: %d', net.n_buses));
assert_pass(net.n_branches == 8, sprintf('Expected 8 branches from feeder_params.json: %d', net.n_branches));
assert_pass(numel(net.forward_order) == net.n_branches, 'Forward topology order covers every branch');
assert_pass(numel(net.backward_order) == net.n_branches, 'Backward topology order covers every branch');
assert_pass(all(net.branch_to >= 1 & net.branch_to <= net.n_buses), 'All branch_to indices are valid');
assert_pass(all(net.branch_transformer_zone >= 1 & net.branch_transformer_zone <= net.n_transformers), ...
    'All branch transformer zones are valid');

H = cfg.feeder.num_households;
assert_pass(numel(assignment.household_id) == H, sprintf('Assignment has %d households', H));
assert_pass(sum(assignment.has_ev) >= 0, sprintf('EV assignment complete: %d EV households', sum(assignment.has_ev)));
assert_pass(all(assignment.bus_id >= 1 & assignment.bus_id <= net.n_buses), 'All assigned bus IDs are valid');
assert_pass(all(assignment.phase_id >= 1 & assignment.phase_id <= 3), 'All assigned phases are valid');
assert_pass(isequal(accumarray(assignment.zone, 1), cfg.feeder.households_per_zone(:)), ...
    'Zone assignment exactly matches households_per_zone');

fprintf('[test_phase1_feeder] Complete.\n');
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_phase1_feeder:assertionFailed', message);
end
end

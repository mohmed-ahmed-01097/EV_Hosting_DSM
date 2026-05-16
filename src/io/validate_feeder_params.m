function ok = validate_feeder_params(feeder_path)
% VALIDATE_FEEDER_PARAMS Validate feeder_params.json structural consistency.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   feeder_path (char/string): Path to config/feeder_params.json.
%
% Outputs:
%   ok (logical): true when all checks pass.
%
% Example:
%   ok = validate_feeder_params('config/feeder_params.json');

if isstring(feeder_path)
    feeder_path = char(feeder_path);
end

if ~isfile(feeder_path)
    error('validate_feeder_params:missingFile', ...
        'Feeder params file not found: %s', feeder_path);
end

fp = jsondecode(fileread(feeder_path));

requiredTop = {'transformers', 'branches', 'conductors', 'base_values'};
for k = 1:numel(requiredTop)
    assert(isfield(fp, requiredTop{k}), 'Missing top-level field: %s', requiredTop{k});
end

assert(numel(fp.transformers) == 5, 'Expected exactly 5 transformer zones.');
assert(numel(fp.branches) >= 1, 'Expected at least one branch.');
assert(isfield(fp.conductors, 'neutral'), 'Missing neutral conductor definition.');

conductorNames = fieldnames(fp.conductors);
for b = 1:numel(fp.branches)
    conductorName = fp.branches(b).conductor;
    assert(any(strcmp(conductorNames, conductorName)), ...
        'Branch %s uses undefined conductor %s.', fp.branches(b).id, conductorName);
    assert(fp.branches(b).length_m > 0, ...
        'Branch %s must have positive length.', fp.branches(b).id);
end

for t = 1:numel(fp.transformers)
    assert(fp.transformers(t).kva > 0, 'Transformer %s kva must be positive.', fp.transformers(t).id);
    assert(fp.transformers(t).vlv_kv > 0, 'Transformer %s vlv_kv must be positive.', fp.transformers(t).id);
    assert(fp.transformers(t).r_pu > 0, 'Transformer %s r_pu must be positive.', fp.transformers(t).id);
    assert(fp.transformers(t).x_pu > 0, 'Transformer %s x_pu must be positive.', fp.transformers(t).id);
end

ok = true;
fprintf('[validate_feeder_params] PASS: %s\n', feeder_path);
end

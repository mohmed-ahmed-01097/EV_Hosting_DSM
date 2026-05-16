function net = build_feeder_network(cfg)
% BUILD_FEEDER_NETWORK Build a three-phase four-wire radial LV feeder model.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration struct from config_loader. Required fields:
%       cfg.feeder_params_path
%
% Outputs:
%   net (struct): Feeder model with these documented fields:
%       n_buses                  - number of LV load buses
%       n_branches               - number of radial branch sections
%       n_transformers           - number of transformer zones
%       Zbase                    - system base impedance [ohm]
%       bus_names                - n_buses-by-1 cellstr of bus names
%       transformer_id           - n_buses-by-1 zone ID per bus
%       branch_id                - n_branches-by-1 cellstr branch IDs
%       branch_from              - n_branches-by-1 parent bus index, 0 = transformer secondary source
%       branch_to                - n_branches-by-1 child bus index
%       branch_transformer_zone  - n_branches-by-1 transformer zone ID
%       branch_length_m          - n_branches-by-1 branch length [m]
%       branch_conductor         - n_branches-by-1 conductor names
%       Zabc                     - n_branches-by-1 cell of 3x3 phase impedance matrices [ohm]
%       Zneutral                 - n_branches-by-1 complex neutral impedance [ohm]
%       transformer              - n_transformers-by-1 struct array of transformer data
%       I_rated_a                - n_transformers-by-1 rated LV line current [A]
%       Vbase_ll                 - line-line base voltage [V]
%       Vbase_ln                 - line-neutral base voltage [V]
%       Vsource_pu               - 3x1 balanced source phase voltage phasors [pu]
%       transformer_source_branches - n_transformers-by-1 cell of source branch indices
%       child_branches_by_bus    - n_buses-by-1 cell of downstream branch indices
%       parent_branch_by_bus     - n_buses-by-1 parent branch index
%       forward_order            - branch traversal order from source to leaves
%       backward_order           - branch traversal order from leaves to source
%
% Example:
%   cfg = config_loader();
%   net = build_feeder_network(cfg);

% --- Section 1: Validate inputs and load JSON ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
if ~isfield(cfg, 'feeder_params_path') || ~isfile(cfg.feeder_params_path)
    error('build_feeder_network:missingParams', ...
        'cfg.feeder_params_path is missing or invalid.');
end

params = jsondecode(fileread(cfg.feeder_params_path));

requiredFields = {'transformers', 'branches', 'conductors', 'base_values'};
for k = 1:numel(requiredFields)
    if ~isfield(params, requiredFields{k})
        error('build_feeder_network:invalidParams', ...
            'feeder_params.json is missing field: %s', requiredFields{k});
    end
end

% --- Section 2: Physical base values ---
VbaseLl = params.base_values.v_base_kv * 1000;  % [V]
VbaseLn = VbaseLl / sqrt(3);                    % [V], approximately 220 V
SbaseVa = params.base_values.s_base_kva * 1000; % [VA]
Zbase = (VbaseLl ^ 2) / SbaseVa;                % [ohm]

net = struct();
net.Vbase_ll = VbaseLl;
net.Vbase_ln = VbaseLn;
net.Zbase = Zbase;
net.Sbase_va = SbaseVa;
net.frequency_hz = cfg.feeder.frequency_hz;
net.Vsource_pu = params.base_values.v_source_pu * ...
    [1; exp(-1j * 2*pi/3); exp(1j * 2*pi/3)];

% --- Section 3: Transformer data ---
transformers = params.transformers;
net.n_transformers = numel(transformers);
net.transformer = repmat(struct( ...
    'id', '', 'kva', 0, 'vhv_kv', 0, 'vlv_kv', 0, ...
    'r_pu', 0, 'x_pu', 0, 'Zt_ohm', zeros(3,3)), net.n_transformers, 1);
net.I_rated_a = zeros(net.n_transformers, 1);

for t = 1:net.n_transformers
    tr = transformers(t);
    zBaseTr = (tr.vlv_kv * 1000)^2 / (tr.kva * 1000);
    zTr = (tr.r_pu + 1j * tr.x_pu) * zBaseTr;

    net.transformer(t).id = tr.id;
    net.transformer(t).kva = tr.kva;
    net.transformer(t).vhv_kv = tr.vhv_kv;
    net.transformer(t).vlv_kv = tr.vlv_kv;
    net.transformer(t).r_pu = tr.r_pu;
    net.transformer(t).x_pu = tr.x_pu;
    net.transformer(t).Zt_ohm = diag(repmat(zTr, 3, 1));
    net.I_rated_a(t) = (tr.kva * 1000) / (sqrt(3) * tr.vlv_kv * 1000);
end

% --- Section 4: Bus indexing ---
branches = params.branches;
net.n_branches = numel(branches);
busNames = cell(net.n_branches, 1);
for br = 1:net.n_branches
    busNames{br} = branches(br).to;
end
busNames = unique_stable(busNames);
net.bus_names = busNames(:);
net.n_buses = numel(net.bus_names);

net.transformer_id = zeros(net.n_buses, 1);
for b = 1:net.n_buses
    net.transformer_id(b) = parse_zone_id(net.bus_names{b});
end

% --- Section 5: Branch impedance and topology arrays ---
net.branch_id = cell(net.n_branches, 1);
net.branch_from = zeros(net.n_branches, 1);
net.branch_to = zeros(net.n_branches, 1);
net.branch_transformer_zone = zeros(net.n_branches, 1);
net.branch_length_m = zeros(net.n_branches, 1);
net.branch_conductor = cell(net.n_branches, 1);
net.branch_i_max_a = zeros(net.n_branches, 1);
net.Zabc = cell(net.n_branches, 1);
net.Zneutral = zeros(net.n_branches, 1);

for br = 1:net.n_branches
    branch = branches(br);
    net.branch_id{br} = branch.id;
    net.branch_length_m(br) = branch.length_m;
    net.branch_conductor{br} = branch.conductor;

    fromIdx = find(strcmp(net.bus_names, branch.from), 1);
    if isempty(fromIdx)
        fromIdx = 0;  % transformer secondary source node
    end
    toIdx = find(strcmp(net.bus_names, branch.to), 1);
    if isempty(toIdx)
        error('build_feeder_network:missingToBus', ...
            'Branch %s has unknown to-bus %s.', branch.id, branch.to);
    end

    zoneId = parse_zone_id(branch.from);
    if isnan(zoneId)
        zoneId = parse_zone_id(branch.to);
    end
    if isnan(zoneId) || zoneId < 1 || zoneId > net.n_transformers
        error('build_feeder_network:invalidZone', ...
            'Could not determine transformer zone for branch %s.', branch.id);
    end

    if ~isfield(params.conductors, branch.conductor)
        error('build_feeder_network:invalidConductor', ...
            'Branch %s uses undefined conductor %s.', branch.id, branch.conductor);
    end

    conductor = params.conductors.(branch.conductor);
    zPhase = (conductor.r_ohm_per_km + 1j * conductor.x_ohm_per_km) * ...
        branch.length_m / 1000;
    zMutual = 0.1 * zPhase;
    zabc = zMutual * ones(3,3) + (zPhase - zMutual) * eye(3);

    % Source branches include transformer leakage impedance in series.
    if fromIdx == 0
        zabc = zabc + net.transformer(zoneId).Zt_ohm;
    end

    neutralConductor = params.conductors.neutral;
    zNeutralPerKm = neutralConductor.r_ohm_per_km + 1j * neutralConductor.x_ohm_per_km;
    zNeutral = 1.2 * zNeutralPerKm * branch.length_m / 1000;

    net.branch_from(br) = fromIdx;
    net.branch_to(br) = toIdx;
    net.branch_transformer_zone(br) = zoneId;
    net.branch_i_max_a(br) = conductor.i_max_a;
    net.Zabc{br} = zabc;
    net.Zneutral(br) = zNeutral;
end

% --- Section 6: Derived topology metadata ---
net.transformer_source_branches = cell(net.n_transformers, 1);
for t = 1:net.n_transformers
    net.transformer_source_branches{t} = find(net.branch_from == 0 & ...
        net.branch_transformer_zone == t);
end

net.child_branches_by_bus = cell(net.n_buses, 1);
net.parent_branch_by_bus = zeros(net.n_buses, 1);
for b = 1:net.n_buses
    net.child_branches_by_bus{b} = find(net.branch_from == b);
    parent = find(net.branch_to == b, 1);
    if ~isempty(parent)
        net.parent_branch_by_bus(b) = parent;
    end
end

net.forward_order = topological_branch_order(net.branch_from, net.branch_to, net.n_branches);
net.backward_order = fliplr(net.forward_order);

if numel(net.forward_order) ~= net.n_branches
    error('build_feeder_network:topology', ...
        'Could not build a complete radial traversal order. Check feeder topology.');
end

% --- Section 7: Report summary ---
fprintf('[build_feeder_network] OK: %d transformers | %d buses | %d branches | Vbase=%.1f/%.1f V\n', ...
    net.n_transformers, net.n_buses, net.n_branches, net.Vbase_ll, net.Vbase_ln);
end

function out = unique_stable(values)
% UNIQUE_STABLE Return unique cellstr values while preserving first occurrence order.
out = {};
for k = 1:numel(values)
    if ~any(strcmp(out, values{k}))
        out{end+1,1} = values{k}; %#ok<AGROW>
    end
end
end

function zoneId = parse_zone_id(name)
% PARSE_ZONE_ID Extract transformer/zone number from names like T1_sec or Bus_1A.
zoneId = NaN;
if isempty(name)
    return;
end
exprs = {'T(\d+)_sec', 'Bus_(\d+)'};
for k = 1:numel(exprs)
    token = regexp(name, exprs{k}, 'tokens', 'once');
    if ~isempty(token)
        zoneId = str2double(token{1});
        return;
    end
end
end

function order = topological_branch_order(branchFrom, branchTo, nBranches)
% TOPOLOGICAL_BRANCH_ORDER Return source-to-leaf branch order for a radial graph.
order = [];
frontierBuses = [];
sourceBranches = find(branchFrom == 0)';
order = [order, sourceBranches]; %#ok<AGROW>
frontierBuses = [frontierBuses, branchTo(sourceBranches)']; %#ok<AGROW>
visited = false(nBranches, 1);
visited(sourceBranches) = true;

while ~isempty(frontierBuses)
    currentBus = frontierBuses(1);
    frontierBuses(1) = [];
    childBranches = find(branchFrom == currentBus)';
    for k = 1:numel(childBranches)
        br = childBranches(k);
        if ~visited(br)
            order = [order, br]; %#ok<AGROW>
            visited(br) = true;
            frontierBuses = [frontierBuses, branchTo(br)]; %#ok<AGROW>
        end
    end
end
end

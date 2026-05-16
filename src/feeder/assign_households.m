function assignment = assign_households(cfg, data, net)
% ASSIGN_HOUSEHOLDS Assign households to transformer zones, buses, phases, and EV metadata.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration from config_loader.
%   data (struct): Survey data from data_loader. Must include household table.
%   net (struct, optional): Feeder network from build_feeder_network. If supplied,
%       bus_id values are assigned to actual buses in the selected transformer zone.
%
% Outputs:
%   assignment (struct): Assignment result with fields:
%       household_id    - H-by-1 integer IDs 1..H
%       zone            - H-by-1 transformer zone IDs
%       phase           - H-by-1 cellstr phase labels {'A','B','C'}
%       phase_id        - H-by-1 numeric phase IDs 1=A, 2=B, 3=C
%       bus_id          - H-by-1 bus index in net
%       survey_row      - H-by-1 source survey row index
%       has_ev          - H-by-1 logical EV ownership flags
%       charger_type    - H-by-1 cellstr {'slow','fast','v2g','none'}
%       ev_battery_kwh  - H-by-1 EV battery capacity [kWh], zero if no EV
%
% Example:
%   cfg = config_loader();
%   data = data_loader(cfg);
%   net = build_feeder_network(cfg);
%   assignment = assign_households(cfg, data, net);

% --- Section 1: Validate inputs ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
validateattributes(data, {'struct'}, {'scalar'}, mfilename, 'data', 2);
if nargin < 3
    net = [];
end

if ~isfield(data, 'household') || isempty(data.household)
    error('assign_households:missingData', 'data.household is required.');
end

rng(cfg.feeder.seed_phase_assignment, 'twister');
H = cfg.feeder.num_households;
householdsPerZone = cfg.feeder.households_per_zone(:);

if sum(householdsPerZone) ~= H
    error('assign_households:zoneMismatch', ...
        'households_per_zone must sum to feeder.num_households.');
end

% --- Section 2: Assign transformer zones ---
zoneVec = zeros(H, 1);
cursor = 1;
for z = 1:numel(householdsPerZone)
    idx = cursor:(cursor + householdsPerZone(z) - 1);
    zoneVec(idx) = z;
    cursor = cursor + householdsPerZone(z);
end

% --- Section 3: Assign phases with slight random imbalance per zone ---
phaseVec = zeros(H, 1);
for z = 1:numel(householdsPerZone)
    idx = find(zoneVec == z);
    n = numel(idx);
    basePhases = repmat((1:3)', ceil(n/3), 1);
    basePhases = basePhases(1:n);
    phaseVec(idx) = basePhases(randperm(n));
end
phaseLabels = {'A', 'B', 'C'};
phaseCell = cell(H, 1);
for h = 1:H
    phaseCell{h} = phaseLabels{phaseVec(h)};
end

% --- Section 4: Assign bus IDs within each transformer zone ---
busId = ones(H, 1);
if ~isempty(net)
    for z = 1:numel(householdsPerZone)
        hhIdx = find(zoneVec == z);
        zoneBuses = find(net.transformer_id == z);
        if isempty(zoneBuses)
            error('assign_households:noZoneBus', ...
                'No feeder bus exists for transformer zone %d.', z);
        end
        shuffled = zoneBuses(mod(randperm(numel(hhIdx)) - 1, numel(zoneBuses)) + 1);
        if numel(shuffled) < numel(hhIdx)
            shuffled = zoneBuses(mod(0:numel(hhIdx)-1, numel(zoneBuses)) + 1);
            shuffled = shuffled(randperm(numel(shuffled)));
        end
        busId(hhIdx) = shuffled(:);
    end
end

% --- Section 5: Map to available survey rows ---
nSurvey = height(data.household);
if nSurvey < 1
    error('assign_households:noSurveyRows', 'Survey household table is empty.');
end
surveyRow = randi(nSurvey, H, 1);

% --- Section 6: Assign EV ownership and charger metadata ---
hasEv = rand(H, 1) < cfg.ev.penetration_rate;
chargerType = repmat({'none'}, H, 1);
evBatteryKwh = zeros(H, 1);
chargerTypes = {'slow', 'fast', 'v2g'};
chargerProb = [0.50, 0.35, 0.15];
chargerCdf = cumsum(chargerProb);

for h = 1:H
    if hasEv(h)
        r = rand();
        chargerIdx = find(r <= chargerCdf, 1, 'first');
        chargerType{h} = chargerTypes{chargerIdx};
        batteryOptions = cfg.ev.battery_kwh_options(:);
        evBatteryKwh(h) = batteryOptions(randi(numel(batteryOptions)));
    end
end

% --- Section 7: Output struct and reporting ---
assignment = struct();
assignment.household_id = (1:H)';
assignment.zone = zoneVec;
assignment.phase = phaseCell;
assignment.phase_id = phaseVec;
assignment.bus_id = busId;
assignment.survey_row = surveyRow;
assignment.has_ev = hasEv;
assignment.charger_type = chargerType;
assignment.ev_battery_kwh = evBatteryKwh;

phaseCounts = [sum(phaseVec == 1), sum(phaseVec == 2), sum(phaseVec == 3)];
fprintf('[assign_households] OK: %d HH | EV=%d (%.1f%%) | phases A/B/C=%d/%d/%d | zones=%s\n', ...
    H, sum(hasEv), 100 * mean(hasEv), phaseCounts(1), phaseCounts(2), phaseCounts(3), ...
    mat2str(householdsPerZone'));
end

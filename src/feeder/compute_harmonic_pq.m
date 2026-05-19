function pq = compute_harmonic_pq(pq, L_ev_w_per_bus, assignment, net, cfg)
% COMPUTE_HARMONIC_PQ Augment PQ struct with EV charger harmonic indices.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   pq (struct): PQ struct returned by compute_pq_indices.
%   L_ev_w_per_bus (1 x n_buses double): EV active charging power proxy per bus [W].
%   assignment (struct): Household assignment metadata. Reserved for future spectra.
%   net (struct): Feeder network from build_feeder_network.
%   cfg (struct): Project configuration with pq_limits.
%
% Outputs:
%   pq (struct): Input PQ struct with THDi_pct, THDv_pct, Kfactor, and
%       harmonic violation flags populated from EV charger harmonic injection.
%
% Example:
%   pq = compute_harmonic_pq(pq, 3700*ones(1,net.n_buses), assignment, net, cfg);

% --- Section 1: Constants and input normalization ---
validateattributes(pq, {'struct'}, {'scalar'}, mfilename, 'pq', 1);
validateattributes(net, {'struct'}, {'scalar'}, mfilename, 'net', 4);
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 5);
if nargin < 3 || isempty(assignment)
    assignment = struct(); %#ok<NASGU>
end

harmOrders = [1, 3, 5, 7, 9, 11, 13];
harmSpectrum = [1.0, 0.70, 0.40, 0.25, 0.15, 0.10, 0.08];
Vbase = net.Vbase_ln;
L_ev_w_per_bus = double(L_ev_w_per_bus(:)).';
if numel(L_ev_w_per_bus) < net.n_buses
    L_ev_w_per_bus(end+1:net.n_buses) = 0;
elseif numel(L_ev_w_per_bus) > net.n_buses
    L_ev_w_per_bus = L_ev_w_per_bus(1:net.n_buses);
end
L_ev_w_per_bus(~isfinite(L_ev_w_per_bus)) = 0;

% --- Section 2: Per-bus fundamental and harmonic currents ---
I_harm = zeros(net.n_buses, numel(harmOrders));
for b = 1:net.n_buses
    Pev = max(0, L_ev_w_per_bus(b));
    if Pev < 1.0
        continue;
    end
    if isfield(pq, 'V_pu') && size(pq.V_pu, 2) >= b
        Vmag = max(abs(pq.V_pu(1, b)) * Vbase, 1);
    else
        Vmag = Vbase;
    end
    I1 = Pev / Vmag;
    I_harm(b, :) = I1 * harmSpectrum;
end

% --- Section 3: THDi and K-factor ---
THDi = zeros(1, net.n_buses);
Kfac = ones(1, net.n_buses);
for b = 1:net.n_buses
    I1b = I_harm(b, 1);
    if I1b < 1e-9
        continue;
    end
    IhSq = I_harm(b, 2:end).^2;
    THDi(b) = 100 * sqrt(sum(IhSq)) / I1b;
    Kfac(b) = sum((harmOrders.^2) .* I_harm(b, :).^2) / ...
        max(sum(I_harm(b, :).^2), 1e-12);
end
pq.THDi_pct = repmat(THDi, 3, 1);
pq.Kfactor = repmat(Kfac, 3, 1);

% --- Section 4: THDv from harmonic current and inductive impedance scaling ---
THDv = zeros(1, net.n_buses);
for br = 1:net.n_branches
    b = net.branch_to(br);
    if b < 1 || b > net.n_buses
        continue;
    end
    Z1 = abs(net.Zabc{br}(1, 1));
    for k = 2:numel(harmOrders)
        Zh = harmOrders(k) * Z1;
        Vh = Zh * I_harm(b, k);
        THDv(b) = THDv(b) + (Vh / Vbase)^2;
    end
end
THDv = 100 * sqrt(THDv);
pq.THDv_pct = repmat(THDv, 3, 1);

% --- Section 5: Violation flags and metadata ---
if ~isfield(pq, 'violations') || ~isstruct(pq.violations)
    pq.violations = struct();
end
pq.violations.thdv = any(pq.THDv_pct(:) > cfg.pq_limits.thdv_max_pct);
pq.violations.thdi = any(pq.THDi_pct(:) > cfg.pq_limits.thdi_max_pct);
if ~isfield(pq, 'notes') || ~isstruct(pq.notes)
    pq.notes = struct();
end
pq.notes.harmonics = ...
    'THDv, THDi, and K-factor from EV charger harmonic injection spectrum.';
pq.harmonic_orders = harmOrders;
pq.harmonic_spectrum = harmSpectrum;
end

function pq = compute_pq_indices(V_bus, I_branch, I_neutral, S_load, net, cfg)
% COMPUTE_PQ_INDICES Compute Phase 1 power quality indices.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   V_bus (3 x n_buses complex double): Phase-to-neutral voltages [V].
%   I_branch (3 x n_branches complex double): Branch phase currents [A].
%   I_neutral (1 x n_branches double): Neutral current magnitudes [A].
%   S_load (3 x n_buses complex double): Per-phase complex load [VA].
%   net (struct): Feeder network struct.
%   cfg (struct): Configuration with pq_limits.
%
% Outputs:
%   pq (struct): PQ index result with fields:
%       V_pu, VUF_pct, LVUR_pct, PVUR_pct, V_dev_pct, V_min_pu,
%       V_sag_depth, PF_phase, IUF_pct, PUI, NCR_pct, THDi_pct,
%       TL_pct, TLU_pct, Ploss_kW, Qloss_kvar, THDv_pct, Kfactor,
%       violations, notes.
%
% Example:
%   pq = compute_pq_indices(V, I, In, S, net, cfg);

% --- Section 1: Validate inputs and initialize constants ---
validateattributes(V_bus, {'double'}, {'size', [3, net.n_buses]}, mfilename, 'V_bus', 1);
validateattributes(I_branch, {'double'}, {'size', [3, net.n_branches]}, mfilename, 'I_branch', 2);
validateattributes(I_neutral, {'double'}, {'numel', net.n_branches}, mfilename, 'I_neutral', 3);
validateattributes(S_load, {'double'}, {'size', [3, net.n_buses]}, mfilename, 'S_load', 4);

VbaseLn = net.Vbase_ln;
VbaseLl = net.Vbase_ll;
a = exp(1j * 2*pi/3);
% Fortescue sequence transformation for ABC phase order with
% Vsource = [1 angle 0; 1 angle -120; 1 angle +120].
% Row order is [zero; positive; negative]. The previous row ordering
% swapped positive and negative sequence, causing balanced cases to divide
% by a near-zero positive-sequence magnitude and report enormous VUF/IUF.
Aseq = [1, 1, 1; 1, a, a^2; 1, a^2, a];

% --- Section 2: Per-bus voltage metrics ---
pq = struct();
pq.V_pu = abs(V_bus) / VbaseLn;
pq.VUF_pct = zeros(1, net.n_buses);
pq.LVUR_pct = zeros(1, net.n_buses);
pq.PVUR_pct = zeros(1, net.n_buses);
pq.V_dev_pct = 100 * abs(abs(V_bus) - VbaseLn) / VbaseLn;
pq.V_min_pu = min(pq.V_pu(:));
pq.V_sag_depth = max(0, 100 * (1 - min(pq.V_pu, [], 1)));

for b = 1:net.n_buses
    Vseq = (1/3) * Aseq * V_bus(:, b);
    Vpos = abs(Vseq(2));
    Vneg = abs(Vseq(3));
    pq.VUF_pct(b) = 100 * Vneg / max(Vpos, 1e-9);

    Va = V_bus(1,b);
    Vb = V_bus(2,b);
    Vc = V_bus(3,b);
    Vll = [abs(Va - Vb), abs(Vb - Vc), abs(Vc - Va)];
    VllMean = mean(Vll);
    pq.LVUR_pct(b) = 100 * max(abs(Vll - VllMean)) / max(VllMean, 1e-9);

    Vph = abs(V_bus(:, b));
    VphMean = mean(Vph);
    pq.PVUR_pct(b) = 100 * max(abs(Vph - VphMean)) / max(VphMean, 1e-9);
end

% --- Section 3: Per-phase power factor ---
pq.PF_phase = ones(3, net.n_buses);
for b = 1:net.n_buses
    P = real(S_load(:, b));
    Smag = abs(S_load(:, b));
    nonzero = Smag > 1e-9;
    pq.PF_phase(nonzero, b) = P(nonzero) ./ Smag(nonzero);
end

% --- Section 4: Per-branch current unbalance and neutral current ---
pq.IUF_pct = zeros(1, net.n_branches);
pq.PUI = zeros(1, net.n_branches);
pq.NCR_pct = zeros(1, net.n_branches);

for br = 1:net.n_branches
    Iseq = (1/3) * Aseq * I_branch(:, br);
    Ipos = abs(Iseq(2));
    Ineg = abs(Iseq(3));
    pq.IUF_pct(br) = 100 * Ineg / max(Ipos, 1e-9);

    Iabc = abs(I_branch(:, br));
    Imean = mean(Iabc);
    pq.PUI(br) = max(abs(Iabc - Imean)) / max(Imean, 1e-9);

    zoneId = net.branch_transformer_zone(br);
    pq.NCR_pct(br) = 100 * I_neutral(br) / max(net.I_rated_a(zoneId), 1e-9);
end

% --- Section 5: Transformer loading and loading unbalance ---
pq.TL_pct = zeros(1, net.n_transformers);
pq.TLU_pct = zeros(1, net.n_transformers);

for t = 1:net.n_transformers
    sourceBranches = net.transformer_source_branches{t};
    if isempty(sourceBranches)
        continue;
    end
    Iphase = abs(I_branch(:, sourceBranches));
    Iphase = Iphase(:);
    pq.TL_pct(t) = 100 * max(Iphase) / max(net.I_rated_a(t), 1e-9);
    pq.TLU_pct(t) = 100 * (max(Iphase) - min(Iphase)) / max(net.I_rated_a(t), 1e-9);
end

% --- Section 6: Network losses ---
pq.Ploss_kW = 0;
pq.Qloss_kvar = 0;
for br = 1:net.n_branches
    Ibr = I_branch(:, br);
    Zdiag = diag(net.Zabc{br});
    SlossPh = Zdiag .* (abs(Ibr).^2);
    neutralLoss = net.Zneutral(br) * (I_neutral(br)^2);

    pq.Ploss_kW = pq.Ploss_kW + (sum(real(SlossPh)) + real(neutralLoss)) / 1000;
    pq.Qloss_kvar = pq.Qloss_kvar + (sum(imag(SlossPh)) + imag(neutralLoss)) / 1000;
end

% --- Section 7: Harmonic placeholders for Phase 1 ---
% Phase 1 is a fundamental-frequency feeder model. Harmonic source spectra are
% introduced later by the EV and appliance models. Use zero/nominal values so
% Phase 1 PQ structures are numeric and do not contain NaN.
pq.THDv_pct = zeros(3, net.n_buses);
pq.THDi_pct = zeros(3, net.n_branches);
pq.Kfactor = ones(3, net.n_buses);
pq.notes.harmonics = ['THDv, THDi, and K-factor are Phase 1 numeric placeholders. ', ...
    'They are populated with charger/appliance harmonic spectra in later phases.'];

% --- Section 8: Limit violation flags ---
limits = cfg.pq_limits;
pq.violations = struct();
pq.violations.vuf = any(pq.VUF_pct > limits.vuf_max_pct);
pq.violations.voltage = any(pq.V_pu(:) < limits.voltage_min_pu | ...
    pq.V_pu(:) > limits.voltage_max_pu);
pq.violations.voltage_deviation = any(pq.V_dev_pct(:) > limits.voltage_deviation_max_pct);
pq.violations.ncr = any(pq.NCR_pct > limits.ncr_max_pct);
pq.violations.loading = any(pq.TL_pct > limits.transformer_loading_max_pct);
pq.violations.iuf = any(pq.IUF_pct > limits.iuf_max_pct);
pq.violations.thdv = any(pq.THDv_pct(:) > limits.thdv_max_pct);
pq.violations.thdi = any(pq.THDi_pct(:) > limits.thdi_max_pct);

% --- Section 9: Defensive numeric validation ---
if has_nan_or_inf(pq)
    error('compute_pq_indices:numeric', ...
        'Computed PQ struct contains NaN or Inf values.');
end

fprintf('[compute_pq_indices] OK: Vmin=%.4f pu | max VUF=%.3f%% | max NCR=%.2f%% | max TL=%.2f%%\n', ...
    pq.V_min_pu, max(pq.VUF_pct), max(pq.NCR_pct), max(pq.TL_pct));
end

function tf = has_nan_or_inf(value)
% HAS_NAN_OR_INF Recursively detect NaN/Inf in numeric fields of a struct.
tf = false;
if isnumeric(value)
    tf = any(isnan(value(:)) | isinf(value(:)));
elseif isstruct(value)
    fields = fieldnames(value);
    for k = 1:numel(fields)
        tf = tf || has_nan_or_inf(value.(fields{k}));
        if tf
            return;
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        tf = tf || has_nan_or_inf(value{k});
        if tf
            return;
        end
    end
end
end

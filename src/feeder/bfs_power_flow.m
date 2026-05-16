function [V_bus, I_branch, I_neutral, converged] = bfs_power_flow(net, S_load, household_assignment)
% BFS_POWER_FLOW Solve three-phase four-wire radial power flow by BFS.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   net (struct): Feeder network struct from build_feeder_network.
%   S_load (3 x n_buses complex double): Per-phase complex load [VA].
%       Row 1 = phase A, row 2 = phase B, row 3 = phase C.
%   household_assignment (struct, optional): Included for API compatibility.
%
% Outputs:
%   V_bus (3 x n_buses complex double): Phase-to-neutral bus voltages [V].
%   I_branch (3 x n_branches complex double): Phase branch currents [A].
%   I_neutral (1 x n_branches double): Neutral current magnitudes [A].
%   converged (logical): true if max voltage change is below tolerance.
%
% Example:
%   cfg = config_loader();
%   net = build_feeder_network(cfg);
%   S = (5000 + 1j*1500) * ones(3, net.n_buses);
%   [V, I, In, ok] = bfs_power_flow(net, S, struct());

% --- Section 1: Input validation and constants ---
if nargin < 3
    household_assignment = struct(); %#ok<NASGU>
end
validateattributes(net, {'struct'}, {'scalar'}, mfilename, 'net', 1);
validateattributes(S_load, {'double'}, {'size', [3, net.n_buses]}, mfilename, 'S_load', 2);

VbaseLn = net.Vbase_ln;
tol = 1e-6;
maxIter = 100;
minVoltage = 1e-6;

% --- Section 2: Initialization ---
Vsource = net.Vsource_pu(:) * VbaseLn;
V_bus = repmat(Vsource, 1, net.n_buses);
I_branch = zeros(3, net.n_branches);
I_neutral_complex = zeros(1, net.n_branches);
I_neutral = zeros(1, net.n_branches);
converged = false;
dV = Inf;

% --- Section 3: Iterative backward-forward sweep ---
for iter = 1:maxIter
    V_old = V_bus;

    % --- Section 3.1: Load currents at present voltage estimate ---
    safeVoltage = V_bus;
    lowVoltageMask = abs(safeVoltage) < minVoltage;
    safeVoltage(lowVoltageMask) = minVoltage;
    I_load = conj(S_load ./ safeVoltage);

    % --- Section 3.2: Backward sweep from leaves to source ---
    I_branch(:,:) = 0;
    I_neutral_complex(:) = 0;

    for idx = 1:numel(net.backward_order)
        br = net.backward_order(idx);
        toBus = net.branch_to(br);
        childBranches = net.child_branches_by_bus{toBus};

        downstreamCurrent = zeros(3,1);
        if ~isempty(childBranches)
            downstreamCurrent = sum(I_branch(:, childBranches), 2);
        end

        I_branch(:, br) = I_load(:, toBus) + downstreamCurrent;
        I_neutral_complex(br) = -sum(I_branch(:, br));
    end

    % --- Section 3.3: Forward sweep from source to leaves ---
    for idx = 1:numel(net.forward_order)
        br = net.forward_order(idx);
        fromBus = net.branch_from(br);
        toBus = net.branch_to(br);

        if fromBus == 0
            V_parent = Vsource;
        else
            V_parent = V_bus(:, fromBus);
        end

        phaseDrop = net.Zabc{br} * I_branch(:, br);
        neutralDrop = net.Zneutral(br) * I_neutral_complex(br) * ones(3,1);
        V_bus(:, toBus) = V_parent - phaseDrop - neutralDrop;
    end

    % --- Section 3.4: Convergence check ---
    dV = max(abs(V_bus(:) - V_old(:))) / VbaseLn;
    if dV < tol
        converged = true;
        break;
    end
end

I_neutral = abs(I_neutral_complex);

if ~converged
    warning('bfs_power_flow:notConverged', ...
        'BFS did not converge after %d iterations. Final dV = %.3e pu.', maxIter, dV);
else
    fprintf('[bfs_power_flow] OK: converged in %d iterations | max dV=%.3e pu | Vmin=%.4f pu\n', ...
        iter, dV, min(abs(V_bus(:))) / VbaseLn);
end
end

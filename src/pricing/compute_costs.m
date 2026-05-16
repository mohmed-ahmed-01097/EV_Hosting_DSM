function costs = compute_costs(cfg, L_house_w, tvec_min, cal_struct)
% COMPUTE_COSTS  Compute household electricity costs for all seven tariffs.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - project configuration.
%   L_house_w  (T x H double) - household active power matrix [W].
%   tvec_min   (T x 1 double, optional) - time vector in minutes.
%   cal_struct (struct, optional) - calendar struct from daytype_calendar.
%
% Outputs:
%   costs (struct) with fields:
%     methods                 (cell) - pricing method names.
%     bill_total              (struct) - H x 1 total bills per method [EGP].
%     bill_monthly            (struct) - H x M monthly/period bills [EGP].
%     price_series            (struct) - T x 1 price vectors per method.
%     energy_monthly_kwh      (H x M double) - period energy per household.
%     tariff_slab_reached     (H x M double) - block tariff slab index.
%     ev_cost_increment       (H x 1 double) - placeholder unless baseline is supplied.
%     month_labels            (1 x M cell) - yyyy-mm labels.
%     metadata                (struct) - dt, dimensions, and notes.
%
% Example:
%   cfg = config_loader();
%   L = 500 * ones(96, 2);
%   c = compute_costs(cfg, L, (0:95)' * cfg.simulation.dt_min);

% --- Section 1: Validate inputs and build context ---
if nargin < 3 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end
if nargin < 4
    cal_struct = [];
end

tvec_min = tvec_min(:);
validateattributes(L_house_w, {'numeric'}, {'2d', 'nonnegative', 'finite'}, mfilename, 'L_house_w');

[T, H] = size(L_house_w);
if numel(tvec_min) ~= T
    error('compute_costs:lengthMismatch', 'numel(tvec_min) must match size(L_house_w,1).');
end

ctx = build_pricing_context(cfg, tvec_min, cal_struct);
dt_hr = cfg.simulation.dt_min / 60;
energyStepKwh = L_house_w * (dt_hr / 1000);

% --- Section 2: Period grouping by calendar month ---
monthKeys = year(ctx.timestamps) * 100 + month(ctx.timestamps);
uniqueMonthKeys = unique(monthKeys, 'stable');
M = numel(uniqueMonthKeys);
monthIndex = zeros(T, 1);
monthLabels = cell(1, M);

for m = 1:M
    idx = monthKeys == uniqueMonthKeys(m);
    monthIndex(idx) = m;
    ts = ctx.timestamps(find(idx, 1, 'first'));
    monthLabels{m} = datestr(ts, 'yyyy-mm');
end

energyMonthly = zeros(H, M);
for m = 1:M
    idx = monthIndex == m;
    energyMonthly(:, m) = sum(energyStepKwh(idx, :), 1)';
end

% --- Section 3: Method setup ---
methods = normalize_methods(cfg.pricing.active_methods);
costs.methods = methods;
costs.bill_total = struct();
costs.bill_monthly = struct();
costs.price_series = struct();
costs.energy_monthly_kwh = energyMonthly;
costs.tariff_slab_reached = nan(H, M);
costs.ev_cost_increment = nan(H, 1);
costs.month_labels = monthLabels;

% --- Section 4: Compute cost per method ---
for k = 1:numel(methods)
    method = methods{k};
    fieldName = matlab.lang.makeValidName(method);

    if strcmpi(method, 'Block')
        billMonthly = zeros(H, M);
        slabMonthly = zeros(H, M);

        for m = 1:M
            idx = monthIndex == m;
            periodDays = numel(unique(floor(tvec_min(idx) / (24 * 60)))) + 0.0;
            if periodDays <= 0
                periodDays = sum(idx) * dt_hr / 24;
            end

            for h = 1:H
                block = pricing_block(cfg, tvec_min(idx), energyMonthly(h, m), periodDays);
                billMonthly(h, m) = block.bill_egp;
                slabMonthly(h, m) = block.slab_reached;
            end
        end

        avgMonthlyKwh = mean(sum(energyMonthly, 2) ./ max(M, 1));
        representativeBlock = pricing_block(cfg, tvec_min, avgMonthlyKwh, 30);
        costs.price_series.(fieldName) = representativeBlock.price_series;
        costs.bill_monthly.(fieldName) = billMonthly;
        costs.bill_total.(fieldName) = sum(billMonthly, 2);
        costs.tariff_slab_reached = slabMonthly;
    else
        price = select_pricing(method, cfg, tvec_min, 0, cal_struct);
        if isstruct(price)
            price = price.price_series;
        end
        price = price(:);
        if numel(price) ~= T
            error('compute_costs:priceLength', 'Price vector length mismatch for %s.', method);
        end

        billMonthly = zeros(H, M);
        for m = 1:M
            idx = monthIndex == m;
            billMonthly(:, m) = sum(energyStepKwh(idx, :) .* price(idx), 1)';
        end

        if strcmpi(method, 'RGDP')
            demandMonthly = compute_rgdp_demand_charge(cfg, L_house_w, tvec_min, monthIndex, M);
            billMonthly = billMonthly + demandMonthly;
        end

        costs.price_series.(fieldName) = price;
        costs.bill_monthly.(fieldName) = billMonthly;
        costs.bill_total.(fieldName) = sum(billMonthly, 2);
    end
end

% --- Section 5: Metadata and progress ---
costs.metadata.dt_hr = dt_hr;
costs.metadata.num_steps = T;
costs.metadata.num_households = H;
costs.metadata.num_periods = M;
costs.metadata.note = ['ev_cost_increment is NaN unless a no-EV baseline and EV scenario ' ...
    'are compared by a scenario-level wrapper.'];

fprintf('[compute_costs] OK: %d methods | %d households | %d billing periods | dt=%g h\n', ...
    numel(methods), H, M, dt_hr);
end

function methods = normalize_methods(activeMethods)
% NORMALIZE_METHODS  Convert JSON-decoded method list to a row cellstr.

if ischar(activeMethods)
    methods = {activeMethods};
elseif isstring(activeMethods)
    methods = cellstr(activeMethods(:))';
elseif iscell(activeMethods)
    methods = activeMethods(:)';
    methods = cellfun(@char, methods, 'UniformOutput', false);
else
    error('compute_costs:invalidMethods', 'pricing.active_methods must be a cell, string, or char.');
end
end

function demandMonthly = compute_rgdp_demand_charge(cfg, L_house_w, tvec_min, monthIndex, M)
% COMPUTE_RGDP_DEMAND_CHARGE  Add RGDP daily demand charge.

[T, H] = size(L_house_w);
dayKeys = floor(tvec_min(:) / (24 * 60)) + 1;
uniqueDays = unique(dayKeys, 'stable');
rate = cfg.pricing.rgdp_demand_rate_egp_per_kw_day;
demandMonthly = zeros(H, M);

for d = 1:numel(uniqueDays)
    idx = dayKeys == uniqueDays(d);
    if ~any(idx)
        continue;
    end
    m = monthIndex(find(idx, 1, 'first'));
    dailyPeakKw = max(L_house_w(idx, :), [], 1)' / 1000;
    demandMonthly(:, m) = demandMonthly(:, m) + dailyPeakKw * rate;
end

if T == 0
    demandMonthly = zeros(H, M);
end
end

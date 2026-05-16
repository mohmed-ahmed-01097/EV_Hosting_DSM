function ctx = build_pricing_context(cfg, tvec_min, cal_struct)
% BUILD_PRICING_CONTEXT  Build calendar features used by pricing functions.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg        (struct) - project configuration from config_loader.
%   tvec_min   (T x 1 double, optional) - minutes from simulation start.
%   cal_struct (struct, optional) - calendar struct from daytype_calendar.
%
% Outputs:
%   ctx (struct) with fields:
%     timestamps    (T x 1 datetime) - timestamp for every step.
%     hour_of_day   (T x 1 double) - decimal hour in [0,24).
%     hour_index    (T x 1 integer) - hour bin 1..24.
%     month_index   (T x 1 integer) - month number 1..12.
%     day_index     (T x 1 integer) - day number from simulation start.
%     step_of_day   (T x 1 integer) - step index inside day.
%     daytype       (T x 1 uint8) - 0 weekday, 1 weekend, 2 holiday.
%     is_weekend    (T x 1 logical) - Friday/Saturday or holiday/weekend.
%     is_holiday    (T x 1 logical) - holiday flag.
%     is_ramadan    (T x 1 logical) - Ramadan flag.
%     season        (T x 1 categorical) - winter/spring/summer/autumn.
%     dt_hr         (scalar double) - simulation time step in hours.
%
% Example:
%   cfg = config_loader();
%   ctx = build_pricing_context(cfg, cfg.simulation.tvec_min);

% --- Section 1: Defaults and validation ---
if nargin < 2 || isempty(tvec_min)
    tvec_min = cfg.simulation.tvec_min;
end

tvec_min = tvec_min(:);
validateattributes(tvec_min, {'numeric'}, {'vector', 'nonnegative'}, mfilename, 'tvec_min');

dt_hr = cfg.simulation.dt_min / 60;
T = numel(tvec_min);

% --- Section 2: Use existing calendar when compatible ---
if nargin >= 3 && ~isempty(cal_struct) && isfield(cal_struct, 'timestamps') && numel(cal_struct.timestamps) >= T
    calIdx = round(tvec_min / cfg.simulation.dt_min) + 1;
    if any(calIdx < 1) || any(calIdx > numel(cal_struct.timestamps))
        calIdx = (1:T)';
    end

    ctx.timestamps = cal_struct.timestamps(calIdx);
    ctx.daytype = uint8(cal_struct.daytype(calIdx));
    ctx.season = cal_struct.season(calIdx);
    ctx.day_index = cal_struct.day_index(calIdx);
    ctx.step_of_day = cal_struct.step_of_day(calIdx);
    ctx.hour_of_day = cal_struct.hour_of_day(calIdx);
    if isfield(cal_struct, 'is_ramadan')
        ctx.is_ramadan = logical(cal_struct.is_ramadan(calIdx));
    else
        ctx.is_ramadan = false(T, 1);
    end
else
    % --- Section 3: Reconstruct calendar features from cfg and tvec_min ---
    if isfield(cfg.simulation, 'd1')
        d1 = cfg.simulation.d1;
    else
        d1 = datetime(cfg.simulation.start_date, 'InputFormat', 'yyyy-MM-dd');
    end

    ctx.timestamps = d1 + minutes(tvec_min);
    stepsPerDay = round(24 / dt_hr);
    ctx.day_index = floor(tvec_min / (24 * 60)) + 1;
    ctx.step_of_day = mod(floor(tvec_min / cfg.simulation.dt_min), stepsPerDay) + 1;
    ctx.hour_of_day = mod(tvec_min / 60, 24);

    wd = weekday(ctx.timestamps);
    ctx.is_weekend = (wd == 6) | (wd == 7);  % Egypt: Friday/Saturday
    ctx.is_holiday = false(T, 1);
    ctx.daytype = uint8(ctx.is_weekend);

    mon = month(ctx.timestamps);
    seasonCell = repmat({'spring'}, T, 1);
    isSummer = ismember(mon, [6 7 8 9]);
    isWinter = ismember(mon, [12 1 2]);
    isAutumn = ismember(mon, [10 11]);
    seasonCell(isSummer) = repmat({'summer'}, sum(isSummer), 1);
    seasonCell(isWinter) = repmat({'winter'}, sum(isWinter), 1);
    seasonCell(isAutumn) = repmat({'autumn'}, sum(isAutumn), 1);
    ctx.season = categorical(seasonCell);

    ramadanStart = datetime(2025, 3, 1);
    ramadanEnd = ramadanStart + days(29);
    ctx.is_ramadan = ctx.timestamps >= ramadanStart & ctx.timestamps < ramadanEnd + days(1);
end

% --- Section 4: Derived fields ---
ctx.hour_index = floor(ctx.hour_of_day) + 1;
ctx.hour_index(ctx.hour_index < 1) = 1;
ctx.hour_index(ctx.hour_index > 24) = 24;
ctx.month_index = month(ctx.timestamps);
ctx.dt_hr = dt_hr;

if ~isfield(ctx, 'is_holiday') || isempty(ctx.is_holiday)
    ctx.is_holiday = ctx.daytype == 2;
end
if ~isfield(ctx, 'is_weekend') || isempty(ctx.is_weekend)
    ctx.is_weekend = ctx.daytype > 0;
end
end

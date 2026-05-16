function cal = daytype_calendar(cfg)
% DAYTYPE_CALENDAR Build Egyptian day-type, season, and Ramadan calendar vectors.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Configuration returned by config_loader.m. Required fields:
%       cfg.simulation.d1
%       cfg.simulation.Tsteps
%       cfg.simulation.dt_min
%       cfg.simulation.tvec_min
%
% Outputs:
%   cal (struct): Calendar vectors with fields:
%       cal.timestamps  - Tsteps-by-1 datetime vector
%       cal.daytype     - Tsteps-by-1 uint8: 0=weekday, 1=weekend, 2=holiday
%       cal.season      - Tsteps-by-1 categorical: summer/winter/spring/autumn
%       cal.day_index   - Tsteps-by-1 integer day number from simulation start
%       cal.step_of_day - Tsteps-by-1 integer step index within day
%       cal.hour_of_day - Tsteps-by-1 decimal hour in range [0, 24)
%       cal.is_ramadan  - Tsteps-by-1 logical Ramadan flag
%       cal.meta        - metadata with holiday dates and assumptions
%
% Example:
%   cfg = config_loader();
%   cal = daytype_calendar(cfg);

% --- Section 1: Validate inputs ---
validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 1);
requiredSimulationFields = {'d1','Tsteps','dt_min','tvec_min'};
for i = 1:numel(requiredSimulationFields)
    fieldName = requiredSimulationFields{i};
    if ~isfield(cfg.simulation, fieldName)
        error('daytype_calendar:missingField', 'cfg.simulation.%s is required.', fieldName);
    end
end

Tsteps = cfg.simulation.Tsteps;
dtMin = cfg.simulation.dt_min;
stepsPerDay = 24 * 60 / dtMin;

% --- Section 2: Build time axes ---
cal.timestamps = cfg.simulation.d1 + minutes(cfg.simulation.tvec_min);
cal.timestamps = cal.timestamps(:);
cal.day_index = floor(cfg.simulation.tvec_min(:) / (24 * 60)) + 1;
cal.step_of_day = mod((0:Tsteps-1)', stepsPerDay) + 1;
cal.hour_of_day = mod(cfg.simulation.tvec_min(:) / 60, 24);

% --- Section 3: Weekend and holiday day types ---
cal.daytype = zeros(Tsteps, 1, 'uint8');
weekdayCode = weekday(cal.timestamps);  % MATLAB: Sunday=1, ..., Friday=6, Saturday=7
isWeekend = weekdayCode == 6 | weekdayCode == 7;  % Egypt weekend rule: Friday/Saturday
cal.daytype(isWeekend) = uint8(1);

holidayDates = get_egypt_holidays(cal.timestamps, cfg);
isHoliday = ismember(dateshift(cal.timestamps, 'start', 'day'), holidayDates);
cal.daytype(isHoliday) = uint8(2);

% --- Section 4: Season labels for Egyptian climate ---
monthNum = month(cal.timestamps);
seasonText = strings(Tsteps, 1);
seasonText(ismember(monthNum, [12 1 2])) = "winter";
seasonText(ismember(monthNum, [3 4 5])) = "spring";
seasonText(ismember(monthNum, [6 7 8 9])) = "summer";
seasonText(ismember(monthNum, [10 11])) = "autumn";
cal.season = categorical(seasonText, ["winter","spring","summer","autumn"]);

% --- Section 5: Approximate Ramadan flag ---
cal.is_ramadan = false(Tsteps, 1);
yearsInRun = unique(year(cal.timestamps));
ramadanWindows = strings(0, 1);
for i = 1:numel(yearsInRun)
    y = yearsInRun(i);
    ramadanStart = approximate_ramadan_start(y);
    ramadanEnd = ramadanStart + caldays(29);
    inWindow = cal.timestamps >= ramadanStart & cal.timestamps < ramadanEnd + caldays(1);
    cal.is_ramadan(inWindow) = true;
    ramadanWindows(end+1, 1) = string(sprintf('%04d: %s to %s', y, ...
        datestr(ramadanStart, 'yyyy-mm-dd'), datestr(ramadanEnd, 'yyyy-mm-dd'))); %#ok<AGROW>
end

% --- Section 6: Metadata and summary ---
cal.meta.weekend_rule = 'Egypt: Friday and Saturday';
cal.meta.holiday_dates = holidayDates;
cal.meta.ramadan_windows = ramadanWindows;
cal.meta.season_rule = 'Summer=Jun-Sep; Winter=Dec-Feb; Spring=Mar-May; Autumn=Oct-Nov';

fprintf('[daytype_calendar] OK | steps=%d | weekdays=%d | weekends=%d | holidays=%d | Ramadan steps=%d\n', ...
    Tsteps, sum(cal.daytype == 0), sum(cal.daytype == 1), sum(cal.daytype == 2), sum(cal.is_ramadan));
end

function holidayDates = get_egypt_holidays(timestamps, cfg)
% GET_EGYPT_HOLIDAYS Return holiday dates, trying ICS first then fallback.
startYear = min(year(timestamps));
endYear = max(year(timestamps));
holidayDates = NaT(0, 1);

try
    % Public Google Calendar for Egyptian holidays. If internet is blocked,
    % the catch block below provides deterministic fallback dates.
    url = 'https://calendar.google.com/calendar/ical/en.eg%23holiday%40group.v.calendar.google.com/public/basic.ics';
    opts = weboptions('Timeout', 5);
    icsText = webread(url, opts);
    holidayDates = parse_ics_holiday_dates(icsText, startYear, endYear);
catch
    holidayDates = NaT(0, 1);
end

if isempty(holidayDates)
    holidayDates = fallback_egypt_holidays(startYear, endYear);
end

holidayDates = unique(dateshift(holidayDates(:), 'start', 'day'));

% Keep dates within or near the simulation interval to avoid clutter.
runStart = dateshift(min(timestamps), 'start', 'day');
runEnd = dateshift(max(timestamps), 'start', 'day');
holidayDates = holidayDates(holidayDates >= runStart & holidayDates <= runEnd);

if isfield(cfg, 'country_code') && ~strcmpi(cfg.country_code, 'EG')
    warning('daytype_calendar:countryCode', ...
        'Using Egyptian holiday rules although cfg.country_code is %s.', cfg.country_code);
end
end

function dates = parse_ics_holiday_dates(icsText, startYear, endYear)
% PARSE_ICS_HOLIDAY_DATES Extract all-day DTSTART dates from an ICS file.
lines = splitlines(string(icsText));
dates = NaT(0, 1);
for i = 1:numel(lines)
    line = strtrim(lines(i));
    if startsWith(line, 'DTSTART;VALUE=DATE:')
        token = extractAfter(line, 'DTSTART;VALUE=DATE:');
    elseif startsWith(line, 'DTSTART:')
        token = extractAfter(line, 'DTSTART:');
        token = extractBefore(token, 'T');
    else
        continue;
    end
    if strlength(token) >= 8
        dt = datetime(char(extractBetween(token, 1, 8)), 'InputFormat', 'yyyyMMdd');
        if year(dt) >= startYear && year(dt) <= endYear
            dates(end+1, 1) = dt; %#ok<AGROW>
        end
    end
end
end

function dates = fallback_egypt_holidays(startYear, endYear)
% FALLBACK_EGYPT_HOLIDAYS Hardcoded and approximate Egyptian holidays.
dates = NaT(0, 1);
for y = startYear:endYear
    fixedDates = [ ...
        datetime(y, 1, 7);   ... % Coptic Christmas
        datetime(y, 1, 25);  ... % Revolution Day / Police Day
        datetime(y, 4, 25);  ... % Sinai Liberation Day
        datetime(y, 5, 1);   ... % Labour Day
        datetime(y, 6, 30);  ... % June 30 Revolution
        datetime(y, 7, 23);  ... % Revolution Day
        datetime(y, 10, 6)];     % Armed Forces Day

    if y == 2025
        eidFitr = (datetime(2025, 3, 30):caldays(1):datetime(2025, 4, 1))';
        eidAdha = (datetime(2025, 6, 6):caldays(1):datetime(2025, 6, 10))';
    else
        % Approximate lunar-date shift from the 2025 known holidays.
        yearShift = round(10.875 * (y - 2025));
        eidFitrStart = datetime(2025, 3, 30) - caldays(yearShift) + calyears(y - 2025);
        eidAdhaStart = datetime(2025, 6, 6) - caldays(yearShift) + calyears(y - 2025);
        eidFitr = (eidFitrStart:caldays(1):eidFitrStart + caldays(2))';
        eidAdha = (eidAdhaStart:caldays(1):eidAdhaStart + caldays(4))';
    end

    dates = [dates; fixedDates; eidFitr; eidAdha]; %#ok<AGROW>
end
end

function ramadanStart = approximate_ramadan_start(y)
% APPROXIMATE_RAMADAN_START Estimate Ramadan start date from 2025 reference.
% Reference: Ramadan 2025 starts approximately 2025-03-01.
baseStart = datetime(2025, 3, 1);
yearOffset = y - 2025;
ramadanStart = baseStart + calyears(yearOffset) - caldays(round(10.875 * yearOffset));
end

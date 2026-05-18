classdef HouseholdTwin < handle
% HOUSEHOLDTWIN Configurable digital twin for one Egyptian household.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   h_idx (integer): Household index in the assignment struct.
%   assignment (struct): Output from assign_households.
%   data (struct): Survey data returned by data_loader.
%   cfg (struct): Project configuration.
%
% Properties:
%   config          Struct with survey-derived household metadata.
%   phase_id        Integer phase identifier, 1=A, 2=B, 3=C.
%   zone            Transformer zone identifier.
%   current_state   Runtime state including current step, measurement bias, and command log.
%   daily_profile   Latest simulated household daily profile.
%   flexibility_api Latest flexibility-window API exposed to DSM/smart-meter controller.
%
% Example:
%   twin = HouseholdTwin(1, assignment, data, cfg);
%   twin.generateDayProfile(cal_day, weather_day);
%   windows = twin.getFlexibilityWindows();
%   cmd = struct('appliance','Washing_Machine','new_start',40);
%   [accepted, new_ci, reason] = twin.acceptDSMCommand(cmd);

properties
    config
    phase_id
    zone
    current_state
    daily_profile
    flexibility_api
end

properties (Access = private)
    household_index
    assignment
    data
    cfg
end

methods
    function obj = HouseholdTwin(h_idx, assignment, data, cfg)
        % HOUSEHOLDTWIN Construct one configurable household digital twin.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   h_idx (integer): Household index, 1..H.
        %   assignment (struct): Household assignment metadata.
        %   data (struct): Survey data.
        %   cfg (struct): Configuration.
        %
        % Outputs:
        %   obj (HouseholdTwin): Initialized twin instance.
        %
        % Example:
        %   twin = HouseholdTwin(1, assignment, data, cfg);

        validateattributes(h_idx, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'h_idx', 1);
        validateattributes(assignment, {'struct'}, {'scalar'}, mfilename, 'assignment', 2);
        validateattributes(data, {'struct'}, {'scalar'}, mfilename, 'data', 3);
        validateattributes(cfg, {'struct'}, {'scalar'}, mfilename, 'cfg', 4);

        if h_idx > numel(assignment.phase_id)
            error('HouseholdTwin:badIndex', 'h_idx exceeds assignment size.');
        end

        obj.household_index = h_idx;
        obj.assignment = assignment;
        obj.data = data;
        obj.cfg = cfg;

        obj.phase_id = assignment.phase_id(h_idx);
        obj.zone = assignment.zone(h_idx);
        obj.config = obj.extractHouseholdConfig();
        obj.daily_profile = struct();
        obj.flexibility_api = obj.emptyFlexibilityApi();
        obj.current_state = obj.initializeState();
    end

    function generateDayProfile(obj, cal_day, weather_day)
        % GENERATEDAYPROFILE Simulate and store one-day household profile.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   cal_day (struct): Calendar metadata for one day.
        %   weather_day (steps-by-1 double): Outdoor temperature [deg C].
        %
        % Outputs:
        %   None. Updates obj.daily_profile, obj.flexibility_api, and current_state.
        %
        % Example:
        %   twin.generateDayProfile(cal_day, weather_day);

        validateattributes(cal_day, {'struct'}, {'scalar'}, mfilename, 'cal_day', 1);
        validateattributes(weather_day, {'numeric'}, {'vector','nonempty','finite'}, mfilename, 'weather_day', 2);

        hh = simulate_household(obj.household_index, obj.assignment, obj.data, weather_day(:), cal_day, obj.cfg);
        obj.daily_profile = hh;
        obj.daily_profile.p_commanded_w = hh.p_total_w(:);
        obj.daily_profile.command_schedule = obj.buildPreferredCommandSchedule(hh.flexibility);
        obj.daily_profile.last_command = struct('accepted', false, 'reason', 'No DSM command applied yet.');
        obj.flexibility_api = obj.buildFlexibilityApi(hh.flexibility);

        obj.current_state.current_step = 1;
        obj.current_state.occupancy = hh.occupancy(1);
        obj.current_state.ev = hh.ev;
        obj.current_state.last_generated_on = datestr(now, 31);
        obj.current_state.measurement_bias_w = 0;
        obj.current_state.last_measured_power_w = NaN;
    end

    function windows = getFlexibilityWindows(obj)
        % GETFLEXIBILITYWINDOWS Return current DSM flexibility API.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   None.
        %
        % Outputs:
        %   windows (struct): Controllable-load flexibility fields.
        %
        % Example:
        %   windows = twin.getFlexibilityWindows();

        obj.requireDailyProfile();
        obj.flexibility_api = obj.buildFlexibilityApi(obj.daily_profile.flexibility);
        windows = obj.flexibility_api;
    end

    function [accepted, new_ci, reason] = acceptDSMCommand(obj, cmd)
        % ACCEPTDSMCOMMAND Validate and apply a smart-meter DSM command.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   cmd (struct): Command with fields appliance and new_start.
        %
        % Outputs:
        %   accepted (logical): True if the command is accepted and applied.
        %   new_ci (double): Comfort index after the attempted command.
        %   reason (char): Acceptance or rejection explanation.
        %
        % Example:
        %   cmd = struct('appliance','Washing_Machine','new_start',38);
        %   [accepted, ci, reason] = twin.acceptDSMCommand(cmd);

        obj.requireDailyProfile();
        validateattributes(cmd, {'struct'}, {'scalar'}, mfilename, 'cmd', 1);

        accepted = false;
        new_ci = obj.computeCurrentComfort();
        reason = 'Command not evaluated.';

        if ~isfield(cmd, 'appliance') || ~isfield(cmd, 'new_start')
            reason = 'Rejected: cmd must include appliance and new_start fields.';
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        applianceName = char(string(cmd.appliance));
        newStart = round(double(cmd.new_start));
        if ~isfinite(newStart) || newStart < 1
            reason = 'Rejected: new_start must be a positive finite step index.';
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        flex = obj.daily_profile.flexibility;
        idx = obj.findFlexIndex(flex, applianceName);
        if isempty(idx)
            reason = sprintf('Rejected: appliance %s is not controllable or not scheduled today.', applianceName);
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        earliest = round(double(flex.earliest_start_step(idx)));
        latest = round(double(flex.latest_start_step(idx)));
        duration = max(1, round(double(flex.duration_steps(idx))));
        stepsPerDay = obj.stepsPerDay();
        if newStart < earliest || newStart > latest || newStart + duration - 1 > stepsPerDay
            reason = sprintf('Rejected: %s new_start=%d is outside allowed window [%d,%d].', ...
                applianceName, newStart, earliest, latest);
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        trialSchedule = obj.getCurrentCommandSchedule();
        oldStart = trialSchedule.scheduled_start_step(idx);
        trialSchedule.scheduled_start_step(idx) = newStart;
        [hasConflict, conflictReason] = obj.hasScheduleConflict(trialSchedule, idx);
        if hasConflict
            reason = ['Rejected: ' conflictReason];
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        [new_ci, ciDetail] = comfort_index(trialSchedule, flex, obj.cfg);
        comfortThreshold = obj.getComfortThreshold();
        if new_ci < comfortThreshold
            reason = sprintf('Rejected: comfort index %.3f is below threshold %.3f.', new_ci, comfortThreshold);
            obj.recordCommand(cmd, accepted, new_ci, reason);
            return;
        end

        pCommanded = obj.synthesizeCommandedLoad(trialSchedule);
        accepted = true;
        obj.daily_profile.command_schedule = trialSchedule;
        obj.daily_profile.p_commanded_w = pCommanded;
        obj.daily_profile.last_command = struct('accepted', true, 'appliance', applianceName, ...
            'old_start', oldStart, 'new_start', newStart, 'comfort_idx', new_ci, ...
            'reason', 'Accepted');
        obj.daily_profile.comfort_idx = new_ci;
        obj.daily_profile.comfort_detail = ciDetail;
        obj.current_state.command_count = obj.current_state.command_count + 1;
        reason = sprintf('Accepted: %s moved from step %d to %d. CI=%.3f.', ...
            applianceName, oldStart, newStart, new_ci);
        obj.recordCommand(cmd, accepted, new_ci, reason);
    end

    function ev = getEVStatus(obj)
        % GETEVSTATUS Return current EV availability and SOC metadata.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   None.
        %
        % Outputs:
        %   ev (struct): EV status struct. present=false when no EV/profile.
        %
        % Example:
        %   ev = twin.getEVStatus();

        if isfield(obj.daily_profile, 'ev') && isstruct(obj.daily_profile.ev)
            ev = obj.daily_profile.ev;
        else
            ev = struct('present', false, 'charger_type', 'none', 'available_steps', false(obj.stepsPerDay(), 1));
        end
    end

    function projection = getProjectedLoad(obj, steps_ahead)
        % GETPROJECTEDLOAD Return short-horizon projected household demand.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   steps_ahead (integer): Number of future steps to return.
        %
        % Outputs:
        %   projection (struct): Time-step indices and projected power [W].
        %
        % Example:
        %   proj = twin.getProjectedLoad(8);

        obj.requireDailyProfile();
        validateattributes(steps_ahead, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'steps_ahead', 1);

        p = obj.getActivePowerVector();
        startStep = min(max(1, round(double(obj.current_state.current_step))), numel(p));
        endStep = min(numel(p), startStep + steps_ahead - 1);
        idx = (startStep:endStep)';
        projection = struct();
        projection.step = idx;
        projection.power_w = p(idx) + obj.current_state.measurement_bias_w;
        projection.horizon_steps = numel(idx);
        projection.phase_id = obj.phase_id;
        projection.zone = obj.zone;
        projection.source = 'HouseholdTwin';
    end

    function updateFromMeasurement(obj, p_measured_w)
        % UPDATEFROMMEASUREMENT Update twin state from smart-meter measurement.
        %
        % Author: Mohammed Ahmed
        % Date: 2026
        %
        % Inputs:
        %   p_measured_w (double): Latest measured household power [W].
        %
        % Outputs:
        %   None. Updates current_state measurement fields.
        %
        % Example:
        %   twin.updateFromMeasurement(1250);

        validateattributes(p_measured_w, {'numeric'}, {'scalar','finite','nonnegative'}, mfilename, 'p_measured_w', 1);
        obj.requireDailyProfile();

        p = obj.getActivePowerVector();
        step = min(max(1, round(double(obj.current_state.current_step))), numel(p));
        predicted = p(step);
        alpha = 0.25;
        instantaneousBias = double(p_measured_w) - predicted;
        if ~isfinite(obj.current_state.measurement_bias_w)
            obj.current_state.measurement_bias_w = 0;
        end
        obj.current_state.measurement_bias_w = (1 - alpha) * obj.current_state.measurement_bias_w + alpha * instantaneousBias;
        obj.current_state.last_measured_power_w = double(p_measured_w);
        obj.current_state.last_predicted_power_w = predicted;
        obj.current_state.last_measurement_error_w = instantaneousBias;
        obj.current_state.updated_on = datestr(now, 31);
        obj.current_state.current_step = min(numel(p), step + 1);
        if isfield(obj.daily_profile, 'occupancy') && step <= numel(obj.daily_profile.occupancy)
            obj.current_state.occupancy = obj.daily_profile.occupancy(step);
        end
    end
end

methods (Access = private)
    function cfgOut = extractHouseholdConfig(obj)
        % EXTRACTHOUSEHOLDCONFIG Build survey-derived configuration struct.
        sr = obj.assignment.survey_row(obj.household_index);
        cfgOut = struct();
        cfgOut.household_index = obj.household_index;
        cfgOut.survey_row = sr;
        cfgOut.household_id = obj.safeTableValue(obj.data.household, sr, 'Household_ID', obj.household_index);
        cfgOut.dwelling_type = obj.safeTableValue(obj.data.household, sr, 'Dwelling_Type', 'Unknown');
        cfgOut.floor_area_m2 = obj.safeTableValue(obj.data.household, sr, 'Floor_Area_m2', NaN);
        cfgOut.num_residents = obj.safeTableValue(obj.data.household, sr, 'Num_Residents', NaN);
        cfgOut.income_level = obj.safeTableValue(obj.data.household, sr, 'Income_Level', 'Unknown');
        cfgOut.phase_id = obj.phase_id;
        cfgOut.phase = char('A' + obj.phase_id - 1);
        cfgOut.zone = obj.zone;
        cfgOut.bus_id = obj.assignment.bus_id(obj.household_index);
        cfgOut.has_ev = obj.assignment.has_ev(obj.household_index);
        cfgOut.charger_type = obj.assignment.charger_type{obj.household_index};
        cfgOut.ev_battery_kwh = obj.assignment.ev_battery_kwh(obj.household_index);
    end

    function st = initializeState(obj)
        % INITIALIZESTATE Create default state.
        st = struct();
        st.current_step = 1;
        st.occupancy = uint8(0);
        st.active_loads = {};
        st.ev = struct('present', false, 'charger_type', 'none');
        st.measurement_bias_w = 0;
        st.last_measured_power_w = NaN;
        st.last_predicted_power_w = NaN;
        st.last_measurement_error_w = NaN;
        st.command_count = 0;
        st.command_log = struct('timestamp', {}, 'appliance', {}, 'new_start', {}, ...
            'accepted', {}, 'comfort_idx', {}, 'reason', {});
        st.created_on = datestr(now, 31);
    end

    function api = emptyFlexibilityApi(obj) %#ok<MANU>
        % EMPTYFLEXIBILITYAPI Return empty API with stable fields.
        api = struct();
        api.household_id = [];
        api.appliance = {};
        api.earliest_start_step = [];
        api.latest_start_step = [];
        api.preferred_start_step = [];
        api.duration_steps = [];
        api.power_w = [];
        api.max_shift_steps = [];
        api.count = 0;
        api.dt_min = [];
    end

    function schedule = buildPreferredCommandSchedule(obj, flex)
        % BUILDPREFERREDCOMMANDSCHEDULE Initialize command schedule at preferred starts.
        A = obj.getFlexCount(flex);
        schedule = struct();
        schedule.scheduled_start_step = zeros(A, 1);
        schedule.x = zeros(A, obj.stepsPerDay());
        schedule.method = 'household_twin_preferred';
        schedule.flexibility = flex;
        for a = 1:A
            startStep = min(obj.stepsPerDay(), max(1, round(double(flex.preferred_start_step(a)))));
            schedule.scheduled_start_step(a) = startStep;
            schedule.x(a, startStep) = 1;
        end
        [schedule.comfort_idx, schedule.comfort_detail] = comfort_index(schedule, flex, obj.cfg);
    end

    function api = buildFlexibilityApi(obj, flex)
        % BUILDFLEXIBILITYAPI Convert flexibility metadata to stable API struct.
        api = obj.emptyFlexibilityApi();
        api.household_id = obj.household_index;
        api.phase_id = obj.phase_id;
        api.zone = obj.zone;
        api.dt_min = obj.cfg.simulation.dt_min;
        A = obj.getFlexCount(flex);
        if A == 0
            return;
        end
        api.appliance = flex.appliance(:);
        api.earliest_start_step = double(flex.earliest_start_step(:));
        api.latest_start_step = double(flex.latest_start_step(:));
        api.preferred_start_step = double(flex.preferred_start_step(:));
        api.duration_steps = double(flex.duration_steps(:));
        api.power_w = double(flex.power_w(:));
        api.max_shift_steps = double(flex.max_shift_steps(:));
        api.count = A;
        api.window_start_hr = (api.earliest_start_step - 1) * obj.cfg.simulation.dt_min / 60;
        api.window_end_hr = (api.latest_start_step + api.duration_steps - 1) * obj.cfg.simulation.dt_min / 60;
    end

    function schedule = getCurrentCommandSchedule(obj)
        % GETCURRENTCOMMANDSCHEDULE Return current command schedule or create one.
        if isfield(obj.daily_profile, 'command_schedule') && isstruct(obj.daily_profile.command_schedule)
            schedule = obj.daily_profile.command_schedule;
        else
            schedule = obj.buildPreferredCommandSchedule(obj.daily_profile.flexibility);
        end
    end

    function p = synthesizeCommandedLoad(obj, schedule)
        % SYNTHESIZECOMMANDEDLOAD Build commanded total load from fixed + scheduled flexible loads.
        W = obj.stepsPerDay();
        if isfield(obj.daily_profile, 'p_fixed_w')
            p = double(obj.daily_profile.p_fixed_w(:));
        else
            p = zeros(W, 1);
        end
        if numel(p) < W
            p = [p; repmat(p(end), W - numel(p), 1)];
        elseif numel(p) > W
            p = p(1:W);
        end
        flex = obj.daily_profile.flexibility;
        A = obj.getFlexCount(flex);
        for a = 1:A
            s = max(1, min(W, round(double(schedule.scheduled_start_step(a)))));
            duration = max(1, round(double(flex.duration_steps(a))));
            powerW = max(0, double(flex.power_w(a)));
            activeIdx = s:min(W, s + duration - 1);
            p(activeIdx) = p(activeIdx) + powerW;
        end
    end

    function [hasConflict, reason] = hasScheduleConflict(obj, schedule, movedIdx)
        % HASSCHEDULECONFLICT Check active-interval overlaps among controllable loads.
        hasConflict = false;
        reason = '';
        flex = obj.daily_profile.flexibility;
        A = obj.getFlexCount(flex);
        movedRange = obj.activeRange(schedule, flex, movedIdx);
        for a = 1:A
            if a == movedIdx
                continue;
            end
            otherRange = obj.activeRange(schedule, flex, a);
            if any(ismember(movedRange, otherRange))
                hasConflict = true;
                reason = sprintf('%s overlaps with %s.', flex.appliance{movedIdx}, flex.appliance{a});
                return;
            end
        end
    end

    function idxRange = activeRange(obj, schedule, flex, a)
        % ACTIVERANGE Return active steps for schedule index a.
        W = obj.stepsPerDay();
        s = max(1, min(W, round(double(schedule.scheduled_start_step(a)))));
        d = max(1, round(double(flex.duration_steps(a))));
        idxRange = s:min(W, s + d - 1);
    end

    function idx = findFlexIndex(obj, flex, applianceName) %#ok<INUSL>
        % FINDFLEXINDEX Locate controllable appliance by name.
        idx = [];
        if ~isfield(flex, 'appliance') || isempty(flex.appliance)
            return;
        end
        names = lower(string(flex.appliance(:)));
        target = lower(string(applianceName));
        match = find(names == target, 1, 'first');
        if isempty(match)
            normalizedNames = regexprep(names, '[^a-z0-9]', '');
            normalizedTarget = regexprep(target, '[^a-z0-9]', '');
            match = find(normalizedNames == normalizedTarget, 1, 'first');
        end
        if ~isempty(match)
            idx = match;
        end
    end

    function ci = computeCurrentComfort(obj)
        % COMPUTECURRENTCOMFORT Compute comfort for current command schedule.
        if ~isfield(obj.daily_profile, 'flexibility') || obj.getFlexCount(obj.daily_profile.flexibility) == 0
            ci = 1.0;
            return;
        end
        schedule = obj.getCurrentCommandSchedule();
        ci = comfort_index(schedule, obj.daily_profile.flexibility, obj.cfg);
    end

    function recordCommand(obj, cmd, accepted, ci, reason)
        % RECORDCOMMAND Append command to state log.
        entry = struct();
        entry.timestamp = datestr(now, 31);
        if isfield(cmd, 'appliance')
            entry.appliance = char(string(cmd.appliance));
        else
            entry.appliance = '';
        end
        if isfield(cmd, 'new_start')
            entry.new_start = double(cmd.new_start);
        else
            entry.new_start = NaN;
        end
        entry.accepted = logical(accepted);
        entry.comfort_idx = double(ci);
        entry.reason = char(reason);
        obj.current_state.command_log(end + 1) = entry;
        obj.daily_profile.last_command = entry;
    end

    function requireDailyProfile(obj)
        % REQUIREDAILYPROFILE Error if profile has not been generated.
        if isempty(fieldnames(obj.daily_profile)) || ~isfield(obj.daily_profile, 'p_total_w')
            error('HouseholdTwin:noDailyProfile', 'Call generateDayProfile(cal_day, weather_day) before this method.');
        end
    end

    function p = getActivePowerVector(obj)
        % GETACTIVEPOWERVECTOR Return commanded profile when available; else simulated profile.
        if isfield(obj.daily_profile, 'p_commanded_w') && ~isempty(obj.daily_profile.p_commanded_w)
            p = double(obj.daily_profile.p_commanded_w(:));
        else
            p = double(obj.daily_profile.p_total_w(:));
        end
    end

    function n = stepsPerDay(obj)
        % STEPSPERDAY Return configured number of daily samples.
        n = 24 * 60 / obj.cfg.simulation.dt_min;
    end

    function A = getFlexCount(obj, flex) %#ok<INUSL>
        % GETFLEXCOUNT Return number of controllable windows.
        if isfield(flex, 'count')
            A = double(flex.count);
        elseif isfield(flex, 'appliance')
            A = numel(flex.appliance);
        else
            A = 0;
        end
    end

    function threshold = getComfortThreshold(obj)
        % GETCOMFORTTHRESHOLD Return minimum accepted CI threshold.
        threshold = 0.30;
        if isfield(obj.cfg, 'dsm') && isfield(obj.cfg.dsm, 'comfort_min_acceptance')
            threshold = double(obj.cfg.dsm.comfort_min_acceptance);
        end
        if ~isfinite(threshold) || threshold < 0 || threshold > 1
            threshold = 0.30;
        end
    end

    function value = safeTableValue(obj, tbl, row, varName, defaultValue) %#ok<INUSL>
        % SAFETABLEVALUE Get table value with fallback.
        value = defaultValue;
        if isempty(tbl) || row < 1 || row > height(tbl) || ~ismember(varName, tbl.Properties.VariableNames)
            return;
        end
        raw = tbl.(varName)(row);
        if iscell(raw)
            value = raw{1};
        elseif isstring(raw) || iscategorical(raw)
            value = char(raw);
        else
            value = raw;
        end
    end
end
end

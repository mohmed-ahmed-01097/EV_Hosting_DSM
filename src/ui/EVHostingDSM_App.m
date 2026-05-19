classdef EVHostingDSM_App < matlab.apps.AppBase
% EVHOSTINGDSM_APP Dashboard-first MATLAB UI skeleton for EV Hosting DSM.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None. Launch with EVHostingDSM_App() or launch_app().
%
% Outputs:
%   Opens a dashboard-first MATLAB app window.
%
% Example:
%   app = EVHostingDSM_App();
%
% Notes:
%   PART B Step 10 implements the App Designer-compatible class skeleton.
%   The detailed controls for each view are implemented in the following UI
%   steps. This class is intentionally lightweight and compiled-app safe.

properties (Access = public)
    UIFigure
    RootGrid
    SidebarPanel
    ContentPanel
    StatusPanel
    StatusBar
    ProgressBar
    ProgressLabel
    ExecutionLog
    NavCards

    DashboardPanel
    ConfigPanel
    FeederPanel
    LoadPanel
    PricingPanel
    ScenariosPanel
    ResultsPanel
    ExportPanel
    TestsPanel

    ConfigLamp
    SurveyLamp
    WeatherLamp
    PopulationLamp
end

properties (Access = private)
    cfg
    data
    net
    assignment
    pop
    cal_struct
    weather
    all_results
    is_initialized logical = false
    active_view double = 1
    all_results_ready logical = false
    SimState struct = struct()
    Theme struct
end

methods (Access = public)
    function app = EVHostingDSM_App()
        % EVHOSTINGDSM_APP Construct and initialize the app skeleton.
        app.Theme = app_theme();
        createComponents(app);
        registerApp(app, app.UIFigure);
        runStartup(app);
        app.UIFigure.Visible = 'on';

        if nargout == 0
            clear app
        end
    end

    function delete(app)
        % DELETE Close UI resources cleanly.
        if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
            delete(app.UIFigure);
        end
    end
end

methods (Access = private)
    function createComponents(app)
        % CREATECOMPONENTS Build dashboard-first skeleton layout.
        c = app.Theme.colors;

        app.UIFigure = uifigure('Visible', 'off');
        app.UIFigure.Name = 'EV Hosting DSM Simulator';
        app.UIFigure.Position = [100 100 1400 850];
        app.UIFigure.Color = c.bg_dark;
        app.UIFigure.CloseRequestFcn = @(~, ~) delete(app);

        app.RootGrid = uigridlayout(app.UIFigure, [2 2]);
        app.RootGrid.RowHeight = {'1x', app.Theme.layout.status_height};
        app.RootGrid.ColumnWidth = {app.Theme.layout.sidebar_width, '1x'};
        app.RootGrid.RowSpacing = 0;
        app.RootGrid.ColumnSpacing = 0;
        app.RootGrid.Padding = [0 0 0 0];
        app.RootGrid.BackgroundColor = c.bg_dark;

        createSidebar(app);
        createContentPanels(app);
        createStatusBar(app);
        switchView(app, 1);
    end

    function createSidebar(app)
        % CREATESIDEBAR Build left card navigation.
        c = app.Theme.colors;
        labels = app.Theme.nav.labels;

        app.SidebarPanel = uipanel(app.RootGrid, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_dark);
        app.SidebarPanel.Layout.Row = 1;
        app.SidebarPanel.Layout.Column = 1;

        titleLabel = uilabel(app.SidebarPanel, ...
            'Text', 'EV Hosting DSM', ...
            'FontWeight', 'bold', ...
            'FontSize', 16, ...
            'FontColor', c.text_light, ...
            'HorizontalAlignment', 'center', ...
            'Position', [10 805 200 28]);
        titleLabel.Tooltip = 'Assiut University - AI-Driven DSM Simulator';

        app.NavCards = gobjects(numel(labels), 1);
        y0 = 710;
        for k = 1:numel(labels)
            ypos = y0 - (k-1) * 76;
            app.NavCards(k) = uibutton(app.SidebarPanel, 'push', ...
                'Text', labels{k}, ...
                'Position', [10 ypos 200 64], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'FontColor', c.text_light, ...
                'BackgroundColor', c.bg_panel, ...
                'ButtonPushedFcn', @(~, ~) switchView(app, k));
        end
    end

    function createContentPanels(app)
        % CREATECONTENTPANELS Build the nine content panels.
        c = app.Theme.colors;

        app.ContentPanel = uipanel(app.RootGrid, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_dark);
        app.ContentPanel.Layout.Row = 1;
        app.ContentPanel.Layout.Column = 2;

        app.DashboardPanel = uipanel(app.ContentPanel, 'Title', '', 'BorderType', 'none', 'BackgroundColor', c.bg_dark, 'Position', [0 0 1180 820]);
        app.ConfigPanel    = makePlaceholderPanel(app, 'Configuration', 'Step 11 will add editable config groups and save/validate actions.');
        app.FeederPanel    = makePlaceholderPanel(app, 'Feeder Model', 'Step 11 will add feeder topology, assignment table, and BFS smoke test.');
        app.LoadPanel      = makePlaceholderPanel(app, 'Load Model', 'Step 11 will add household/profile simulation and live population plot.');
        app.PricingPanel   = makePlaceholderPanel(app, 'Pricing', 'Step 11 will add tariff curves and block tariff calculator.');
        app.ScenariosPanel = makePlaceholderPanel(app, 'Scenarios', 'Step 12 will add scenario cards and live execution log.');
        app.ResultsPanel   = makePlaceholderPanel(app, 'Results', 'Step 13 will add PQ dashboard, comparison, hosting, cost, twin, and UQ sub-views.');
        app.ExportPanel    = makePlaceholderPanel(app, 'Export', 'Step 14 will add figure, CSV, and LaTeX export controls.');
        app.TestsPanel     = makePlaceholderPanel(app, 'Tests', 'Step 15 will add interactive test runner and result table.');

        createDashboardView(app);
    end

    function panel = makePlaceholderPanel(app, titleText, bodyText)
        % MAKEPLACEHOLDERPANEL Create a placeholder view panel.
        c = app.Theme.colors;
        panel = uipanel(app.ContentPanel, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_dark, ...
            'Position', [0 0 1180 820], ...
            'Visible', 'off');

        uilabel(panel, ...
            'Text', titleText, ...
            'FontSize', 22, ...
            'FontWeight', 'bold', ...
            'FontColor', c.text_light, ...
            'Position', [24 760 700 36]);

        card = uipanel(panel, ...
            'Title', '', ...
            'BackgroundColor', c.bg_panel, ...
            'ForegroundColor', c.text_light, ...
            'Position', [24 620 850 110]);

        uilabel(card, ...
            'Text', bodyText, ...
            'FontSize', 13, ...
            'FontColor', c.text_light, ...
            'WordWrap', 'on', ...
            'Position', [20 22 800 60]);
    end

    function createDashboardView(app)
        % CREATEDASHBOARDVIEW Build the initial dashboard skeleton.
        c = app.Theme.colors;
        p = app.DashboardPanel;

        uilabel(p, ...
            'Text', 'Dashboard', ...
            'FontSize', 24, ...
            'FontWeight', 'bold', ...
            'FontColor', c.text_light, ...
            'Position', [24 760 300 40]);

        uilabel(p, ...
            'Text', 'EV Hosting Capacity and Power Quality - AI-Driven DSM Simulator', ...
            'FontSize', 13, ...
            'FontColor', c.text_muted, ...
            'Position', [24 735 600 26]);

        cardW = 260;
        cardH = 115;
        xs = [24, 304, 584, 864];
        titles = {'CONFIG', 'SURVEY', 'WEATHER', 'POPULATION'};
        subtitles = {'Waiting...', 'Waiting...', 'Waiting...', 'Not simulated'};
        lamps = cell(1,4);

        for k = 1:4
            card = uipanel(p, ...
                'Title', '', ...
                'BackgroundColor', c.bg_panel, ...
                'Position', [xs(k) 595 cardW cardH]);
            lamps{k} = uilamp(card, ...
                'Color', c.warning, ...
                'Position', [18 68 20 20]);
            uilabel(card, ...
                'Text', titles{k}, ...
                'FontSize', 13, ...
                'FontWeight', 'bold', ...
                'FontColor', c.text_light, ...
                'Position', [50 65 180 26]);
            uilabel(card, ...
                'Text', subtitles{k}, ...
                'Tag', [titles{k} '_SUBTITLE'], ...
                'FontSize', 11, ...
                'FontColor', c.text_muted, ...
                'Position', [18 26 225 28]);
        end

        app.ConfigLamp     = lamps{1};
        app.SurveyLamp     = lamps{2};
        app.WeatherLamp    = lamps{3};
        app.PopulationLamp = lamps{4};

        feederCard = uipanel(p, ...
            'Title', 'Feeder Mini-Map Preview', ...
            'FontWeight', 'bold', ...
            'ForegroundColor', c.text_light, ...
            'BackgroundColor', c.bg_panel, ...
            'Position', [24 290 540 260]);
        ax = uiaxes(feederCard, 'Position', [20 20 500 205]);
        app_feeder_plot(struct(), struct(), ax);

        actions = uipanel(p, ...
            'Title', 'Quick Actions', ...
            'FontWeight', 'bold', ...
            'ForegroundColor', c.text_light, ...
            'BackgroundColor', c.bg_panel, ...
            'Position', [584 290 540 260]);

        uibutton(actions, 'push', ...
            'Text', 'Run All Tests', ...
            'FontWeight', 'bold', ...
            'Position', [28 175 210 42], ...
            'ButtonPushedFcn', @(~, ~) onRunTests(app));
        uibutton(actions, 'push', ...
            'Text', 'Open Results Folder', ...
            'Position', [28 115 210 42], ...
            'ButtonPushedFcn', @(~, ~) onOpenResultsFolder(app));
        uibutton(actions, 'push', ...
            'Text', 'Switch to Scenarios', ...
            'Position', [28 55 210 42], ...
            'ButtonPushedFcn', @(~, ~) switchView(app, 6));

        app.ExecutionLog = uitextarea(p, ...
            'Editable', 'off', ...
            'FontName', app.Theme.font.mono, ...
            'FontSize', 10, ...
            'FontColor', c.text_light, ...
            'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [24 24 1100 230], ...
            'Value', {'> App log initialized.'});
    end

    function createStatusBar(app)
        % CREATESTATUSBAR Build persistent bottom status area.
        c = app.Theme.colors;

        app.StatusPanel = uipanel(app.RootGrid, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', [0.06 0.06 0.10]);
        app.StatusPanel.Layout.Row = 2;
        app.StatusPanel.Layout.Column = [1 2];

        app.StatusBar = uilabel(app.StatusPanel, ...
            'Text', 'Initializing...', ...
            'FontSize', 10, ...
            'FontColor', c.text_light, ...
            'Position', [12 4 620 22]);

        app.ProgressBar = uilabel(app.StatusPanel, ...
            'Text', '[--------------------] 0%', ...
            'FontName', app.Theme.font.mono, ...
            'FontSize', 10, ...
            'FontColor', c.accent, ...
            'HorizontalAlignment', 'right', ...
            'Position', [910 4 240 22]);

        app.ProgressLabel = uilabel(app.StatusPanel, ...
            'Text', 'Stage: startup', ...
            'FontSize', 10, ...
            'FontColor', c.text_muted, ...
            'Position', [1160 4 220 22]);
    end

    function runStartup(app)
        % RUNSTARTUP Load core project state with defensive error handling.
        updateStatus(app, 'Initializing project...', 'warning');
        updateProgress(app, 5, 'loading paths');

        try
            rootDir = get_root_dir();
            addpath(genpath(fullfile(rootDir, 'src')));

            updateProgress(app, 15, 'loading config');
            app.cfg = config_loader([]);
            setLamp(app, 'config', true);
            log(app, sprintf('Config loaded from %s', app.cfg.root_folder));

            updateProgress(app, 35, 'loading survey');
            app.data = data_loader(app.cfg);
            setLamp(app, 'survey', true);
            log(app, sprintf('Survey loaded: %d households', height(app.data.household)));

            updateProgress(app, 50, 'calendar/weather');
            app.cal_struct = daytype_calendar(app.cfg);
            app.weather = get_weather(app.cfg);
            setLamp(app, 'weather', strcmpi(app.weather.meta.source, 'NASA_POWER') || strcmpi(app.weather.meta.source, 'cache'));
            log(app, sprintf('Weather source: %s', app.weather.meta.source));

            updateProgress(app, 70, 'building feeder');
            app.net = build_feeder_network(app.cfg);
            app.assignment = assign_households(app.cfg, app.data, app.net);
            log(app, sprintf('Feeder ready: %d buses, %d branches', app.net.n_buses, app.net.n_branches));

            updateProgress(app, 100, 'ready');
            app.is_initialized = true;
            updateStatus(app, 'Ready', 'success');
            log(app, 'Project initialized successfully.');
        catch ME
            updateStatus(app, sprintf('Initialization error: %s', ME.message), 'danger');
            log(app, sprintf('ERROR during startup: %s', ME.message));
            updateProgress(app, 0, 'startup failed');
        end
    end

    function switchView(app, viewId)
        % SWITCHVIEW Hide all content panels and show one selected panel.
        panels = {app.DashboardPanel, app.ConfigPanel, app.FeederPanel, ...
            app.LoadPanel, app.PricingPanel, app.ScenariosPanel, ...
            app.ResultsPanel, app.ExportPanel, app.TestsPanel};

        for k = 1:numel(panels)
            
            if k == viewId
                panels{k}.Visible = 'on';
            else
                panels{k}.Visible = 'off';
            end
        end

        c = app.Theme.colors;
        for k = 1:numel(app.NavCards)
            if k == viewId
                app.NavCards(k).BackgroundColor = 0.65 * c.bg_panel + 0.35 * c.accent;
            else
                app.NavCards(k).BackgroundColor = c.bg_panel;
            end
        end
        app.active_view = viewId;
        updateStatus(app, sprintf('View: %s', app.Theme.nav.labels{viewId}), 'info');
    end

    function updateStatus(app, msg, level)
        % UPDATESTATUS Update persistent bottom status text.
        c = app.Theme.colors;
        color = c.text_light;
        switch lower(level)
            case 'success', color = c.success;
            case 'warning', color = c.warning;
            case 'danger',  color = c.danger;
            case 'info',    color = c.accent;
        end
        app.StatusBar.Text = sprintf('%s | %s', datestr(now, 'HH:MM:SS'), msg);
        app.StatusBar.FontColor = color;
        drawnow('limitrate');
    end

    function updateProgress(app, pct, msg)
        % UPDATEPROGRESS Update the status progress indicator.
        pct = max(0, min(100, round(pct)));
        nBlocks = 20;
        nFill = round(nBlocks * pct / 100);
        barText = ['[', repmat('#', 1, nFill), repmat('-', 1, nBlocks - nFill), sprintf('] %3d%%', pct)];
        app.ProgressBar.Text = barText;
        app.ProgressLabel.Text = sprintf('Stage: %s', msg);
        drawnow('limitrate');
    end

    function log(app, msg)
        % LOG Append one line to the ring-buffer execution log.
        if isempty(app.ExecutionLog) || ~isvalid(app.ExecutionLog)
            return;
        end
        app.ExecutionLog.Value = app_log(app.ExecutionLog.Value, msg, 200);
        try
            scroll(app.ExecutionLog, 'bottom');
        catch
            % scroll is not available in every release; safe to ignore.
        end
        drawnow('limitrate');
    end

    function setLamp(app, lampName, isOk)
        % SETLAMP Set one dashboard lamp by semantic name.
        c = app.Theme.colors;
        if isOk
            lampColor = c.success;
        else
            lampColor = c.warning;
        end

        switch lower(lampName)
            case 'config'
                app.ConfigLamp.Color = lampColor;
            case 'survey'
                app.SurveyLamp.Color = lampColor;
            case 'weather'
                app.WeatherLamp.Color = lampColor;
            case 'population'
                app.PopulationLamp.Color = lampColor;
        end
    end

    function onRunTests(app)
        % ONRUNTESTS Quick-action test runner placeholder.
        log(app, 'Running validation tests from UI...');
        updateStatus(app, 'Running tests...', 'warning');
        try
            run_config_tests();
            updateStatus(app, 'Tests completed', 'success');
            log(app, 'Validation tests completed. See MATLAB command window for details.');
        catch ME
            updateStatus(app, sprintf('Tests failed: %s', ME.message), 'danger');
            log(app, sprintf('Tests failed: %s', ME.message));
        end
    end

    function onOpenResultsFolder(app)
        % ONOPENRESULTSFOLDER Open results directory when supported.
        if isempty(app.cfg) || ~isfield(app.cfg, 'output_dir')
            log(app, 'Results folder unavailable before config load.');
            return;
        end
        outDir = app.cfg.output_dir;
        if exist(outDir, 'dir') ~= 7
            mkdir(outDir);
        end
        log(app, sprintf('Opening results folder: %s', outDir));
        try
            if ispc
                winopen(outDir);
            elseif ismac
                system(sprintf('open "%s"', outDir));
            else
                system(sprintf('xdg-open "%s" &', outDir));
            end
        catch ME
            log(app, sprintf('Could not open folder automatically: %s', ME.message));
        end
    end
end
end

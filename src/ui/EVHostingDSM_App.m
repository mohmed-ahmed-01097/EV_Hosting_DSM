classdef EVHostingDSM_App < matlab.apps.AppBase
% EVHOSTINGDSM_APP Dashboard-first MATLAB UI for EV Hosting DSM.
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
%   PART B Step 14 implements Dashboard, Config, Feeder, Load, Pricing,
%   Scenarios, Results, and Export. Tests view is intentionally left
%   for later steps.

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

    DashboardSubtitleLabels
    DashboardKpiLabels
    DashboardFeederAxes

    ConfigGroupList
    ConfigEvPenSlider
    ConfigEvPenValueLabel
    ConfigChargerDropDown
    ConfigSlowKwEdit
    ConfigFastKwEdit
    ConfigV2GCheckBox
    ConfigV2GRevenueEdit
    ConfigV2GReserveSlider
    ConfigArrivalEdit
    ConfigDepartureEdit
    ConfigDsmControllerDropDown
    ConfigLambdaEdit
    ConfigComfortThresholdSlider
    ConfigFlexTable
    ConfigValidationText

    FeederAxes
    FeederAssignmentTable
    FeederSmokePkwEdit
    FeederSmokeQkvarEdit
    FeederSmokeText

    LoadHouseholdSpinner
    LoadDayDropDown
    LoadTempEdit
    LoadInfoLabel
    LoadAxes
    OccupancyAxes
    PopulationModeDropDown
    PopulationProgressLabel
    LiveLoadAxes

    PricingAxes
    PricingMethodChecks
    PricingDayDropDown
    BlockKwhEdit
    BlockBillText
    BlockSlabTable

    ScenarioCards
    ScenarioStatusLabels
    ScenarioSelectionChecks
    ScenarioRunDropDown
    ScenarioDetailText
    ScenarioProgressText
    ScenarioLiveAxes
    ScenarioLog

    ResultsSubButtons
    ResultsSubPanels
    ResultsPqScenarioDropDown
    ResultsPqTextArea
    ResultsPqAxes
    ResultsVoltageAxes
    ResultsCompareAxes
    ResultsCompareMetricDropDown
    ResultsCompareTable
    ResultsHostingAxes
    ResultsHostingTable
    ResultsCostAxes
    ResultsCostTariffDropDown
    ResultsCostTable
    ResultsTwinHouseholdSpinner
    ResultsTwinDayDropDown
    ResultsTwinAxes
    ResultsTwinFlexTable
    ResultsTwinCommandApplianceDropDown
    ResultsTwinCommandStartEdit
    ResultsTwinStatusText
    ResultsUqAxes
    ResultsUqScenarioDropDown
    ResultsUqRunsSpinner
    ResultsUqTable

    ExportFigureChecks
    ExportFormatPngCheck
    ExportFormatEpsCheck
    ExportFormatSvgCheck
    ExportSizeDropDown
    ExportFolderEdit
    ExportStatusText
    ExportCsvChecks
    ExportAuthorEdit
    ExportDateEdit
    ExportLatexStatusText

    TestsTable
    TestsDetailText
    TestsSummaryLabel
    TestsProgressLabel
    TestsRunAllButton
    TestsRunSelectedButton
    TestsClearButton
    TestsSaveButton

    ScenarioStopRequested logical = false

    ClockTimer
    LastStatusMessage char = 'ready'
    LastStatusLevel char = 'info'
    LastProgressPct double = 100
    LastProgressStage char = 'ready'

    ConfigGroupTitleLabel
    ConfigAdvancedTable
    ConfigDynamicPanel
    ConfigDynamicControls
    TestsStateLoaded logical = false
end

methods (Access = public)
    function app = EVHostingDSM_App()
        % EVHOSTINGDSM_APP Construct and initialize the app.
        app.Theme = app_theme();
        createComponents(app);
        registerApp(app, app.UIFigure);
        runStartup(app);
        startClockTimer(app);
        app.UIFigure.Visible = 'on';

        if nargout == 0
            clear app
        end
    end

    function delete(app)
        % DELETE Close UI resources cleanly.
        try
            stopClockTimer(app);
        catch
        end
        if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
            delete(app.UIFigure);
        end
    end
end

methods (Access = private)
    function createComponents(app)
        % CREATECOMPONENTS Build dashboard-first layout.
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
        styleAllAxes(app);
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
        % CREATECONTENTPANELS Build all content panels.
        c = app.Theme.colors;

        app.ContentPanel = uipanel(app.RootGrid, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_dark);
        app.ContentPanel.Layout.Row = 1;
        app.ContentPanel.Layout.Column = 2;

        app.DashboardPanel = makeBasePanel(app);
        app.ConfigPanel    = makeBasePanel(app);
        app.FeederPanel    = makeBasePanel(app);
        app.LoadPanel      = makeBasePanel(app);
        app.PricingPanel   = makeBasePanel(app);
        app.ScenariosPanel = makeBasePanel(app);
        app.ResultsPanel   = makeBasePanel(app);
        app.ExportPanel    = makeBasePanel(app);
        app.TestsPanel     = makeBasePanel(app);

        createDashboardView(app);
        createConfigView(app);
        createFeederView(app);
        createLoadView(app);
        createPricingView(app);
        createScenariosView(app);
        createResultsView(app);
        createExportView(app);
        createTestsView(app);
    end

    function panel = makeBasePanel(app)
        % MAKEBASEPANEL Create a standard invisible content panel.
        c = app.Theme.colors;
        panel = uipanel(app.ContentPanel, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_dark, ...
            'Position', [0 0 1180 820], ...
            'Visible', 'off');
    end

    function panel = makePlaceholderPanel(app, titleText, bodyText)
        % MAKEPLACEHOLDERPANEL Create a placeholder view panel.
        c = app.Theme.colors;
        panel = makeBasePanel(app);

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
        % CREATEDASHBOARDVIEW Build dashboard cards, actions, KPIs, and log.
        c = app.Theme.colors;
        p = app.DashboardPanel;

        addHeader(app, p, 'Dashboard', 'EV Hosting Capacity and Power Quality - AI-Driven DSM Simulator');

        cardW = 260;
        cardH = 115;
        xs = [24, 304, 584, 864];
        titles = {'CONFIG', 'SURVEY', 'WEATHER', 'POPULATION'};
        subtitles = {'Waiting...', 'Waiting...', 'Waiting...', 'Not simulated'};
        lamps = cell(1,4);
        app.DashboardSubtitleLabels = gobjects(4,1);

        for k = 1:4
            card = makeCard(app, p, '', [xs(k) 595 cardW cardH]);
            lamps{k} = uilamp(card, 'Color', c.warning, 'Position', [18 68 20 20]);
            uilabel(card, 'Text', titles{k}, 'FontSize', 13, 'FontWeight', 'bold', ...
                'FontColor', c.text_light, 'Position', [50 65 180 26]);
            app.DashboardSubtitleLabels(k) = uilabel(card, 'Text', subtitles{k}, ...
                'FontSize', 11, 'FontColor', c.text_muted, 'Position', [18 26 225 30]);
        end
        app.ConfigLamp     = lamps{1};
        app.SurveyLamp     = lamps{2};
        app.WeatherLamp    = lamps{3};
        app.PopulationLamp = lamps{4};

        feederCard = makeCard(app, p, 'Feeder Mini-Map Preview', [24 330 540 230]);
        app.DashboardFeederAxes = uiaxes(feederCard, 'Position', [20 20 500 170]);
        app_feeder_plot(struct(), struct(), app.DashboardFeederAxes);

        actions = makeCard(app, p, 'Quick Actions', [584 330 540 230]);
        uibutton(actions, 'push', 'Text', 'Run All Scenarios', 'FontWeight', 'bold', ...
            'Position', [28 150 210 36], 'ButtonPushedFcn', @(~, ~) onRunSelectedScenarios(app, [-1 0 1 2 3 4 5 6]));
        uibutton(actions, 'push', 'Text', 'Run Scenario 4', ...
            'Position', [28 102 210 36], 'ButtonPushedFcn', @(~, ~) onRunSelectedScenarios(app, 4));
        uibutton(actions, 'push', 'Text', 'Run All Tests', ...
            'Position', [28 54 210 36], 'ButtonPushedFcn', @(~, ~) onRunTests(app));
        uibutton(actions, 'push', 'Text', 'Open Results Folder', ...
            'Position', [270 54 210 36], 'ButtonPushedFcn', @(~, ~) onOpenResultsFolder(app));

        kpiTitles = {'VUF', 'V_min', 'Hosting', 'Comfort', 'Last Scenario'};
        app.DashboardKpiLabels = gobjects(5,1);
        for k = 1:5
            x = 24 + (k-1)*220;
            tile = makeCard(app, p, '', [x 235 200 75]);
            uilabel(tile, 'Text', kpiTitles{k}, 'FontWeight', 'bold', 'FontSize', 11, ...
                'FontColor', c.text_light, 'Position', [14 42 160 22]);
            app.DashboardKpiLabels(k) = uilabel(tile, 'Text', '--', 'FontSize', 14, ...
                'FontWeight', 'bold', 'FontColor', c.accent, 'Position', [14 12 160 28]);
        end

        app.ExecutionLog = uitextarea(p, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [24 24 1100 190], 'Value', {'> App log initialized.'});
    end

    function createConfigView(app)
        % CREATECONFIGVIEW Build editable core configuration controls.
        c = app.Theme.colors;
        p = app.ConfigPanel;
        addHeader(app, p, 'Configuration', 'Edit high-impact simulation, EV, DSM, pricing, and HVAC parameters.');

        left = makeCard(app, p, 'Groups', [24 95 300 635]);
        app.ConfigGroupList = uilistbox(left, ...
            'Items', {'Simulation','EV Parameters','PQ Limits','DSM Controller','Pricing','HVAC'}, ...
            'Value', 'EV Parameters', ...
            'Position', [16 385 260 200], ...
            'ValueChangedFcn', @(~, ~) onConfigGroupChanged(app));
        app.ConfigValidationText = uitextarea(left, 'Editable', 'off', ...
            'FontName', app.Theme.font.mono, 'FontSize', 10, ...
            'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [16 20 260 340], 'Value', {'Configuration validation messages appear here.'});

        right = makeCard(app, p, 'Editable Parameters', [344 95 780 635]);
        y = 555;
        addSmallLabel(app, right, 'EV Penetration [%]', [24 y 170 22]);
        app.ConfigEvPenSlider = uislider(right, 'Limits', [0 100], 'Value', 20, ...
            'Position', [210 y+10 300 3], 'ValueChangedFcn', @(~, ~) onConfigSliderChanged(app));
        app.ConfigEvPenValueLabel = uilabel(right, 'Text', '20%', 'FontColor', c.accent, 'FontWeight', 'bold', 'Position', [540 y 70 22]);

        y = y - 48;
        addSmallLabel(app, right, 'Charger Type', [24 y 170 22]);
        app.ConfigChargerDropDown = uidropdown(right, 'Items', {'both','slow','fast','v2g'}, ...
            'Value', 'both', 'Position', [210 y 160 28]);

        addSmallLabel(app, right, 'V2G Enabled', [420 y 120 22]);
        app.ConfigV2GCheckBox = uicheckbox(right, 'Text', '', 'Value', true, 'Position', [540 y 60 28]);

        y = y - 48;
        addSmallLabel(app, right, 'Slow Charger [kW]', [24 y 170 22]);
        app.ConfigSlowKwEdit = uieditfield(right, 'numeric', 'Limits', [0.1 50], 'Value', 3.7, 'Position', [210 y 120 28]);
        addSmallLabel(app, right, 'Fast Charger [kW]', [420 y 150 22]);
        app.ConfigFastKwEdit = uieditfield(right, 'numeric', 'Limits', [0.1 100], 'Value', 7.4, 'Position', [570 y 120 28]);

        y = y - 48;
        addSmallLabel(app, right, 'V2G Revenue Fraction', [24 y 170 22]);
        app.ConfigV2GRevenueEdit = uieditfield(right, 'numeric', 'Limits', [0 1], 'Value', 0.50, 'Position', [210 y 120 28]);
        addSmallLabel(app, right, 'V2G Reserve SOC [%]', [420 y 160 22]);
        app.ConfigV2GReserveSlider = uislider(right, 'Limits', [0 100], 'Value', 30, 'Position', [590 y+10 135 3]);

        y = y - 48;
        addSmallLabel(app, right, 'Arrival Mean [hr]', [24 y 170 22]);
        app.ConfigArrivalEdit = uieditfield(right, 'numeric', 'Limits', [0 24], 'Value', 18, 'Position', [210 y 120 28]);
        addSmallLabel(app, right, 'Departure Mean [hr]', [420 y 160 22]);
        app.ConfigDepartureEdit = uieditfield(right, 'numeric', 'Limits', [0 24], 'Value', 7.5, 'Position', [590 y 120 28]);

        y = y - 55;
        addSmallLabel(app, right, 'DSM Controller', [24 y 170 22]);
        app.ConfigDsmControllerDropDown = uidropdown(right, 'Items', {'none','rule_based','milp'}, ...
            'Value', 'milp', 'Position', [210 y 150 28]);
        addSmallLabel(app, right, 'Lambda Comfort', [420 y 150 22]);
        app.ConfigLambdaEdit = uieditfield(right, 'numeric', 'Value', 0.001, 'Position', [590 y 120 28]);

        y = y - 48;
        addSmallLabel(app, right, 'Comfort CI Threshold', [24 y 170 22]);
        app.ConfigComfortThresholdSlider = uislider(right, 'Limits', [0 1], 'Value', 0.30, 'Position', [210 y+10 300 3]);

        addSmallLabel(app, right, 'Appliance Flexibility', [24 200 250 22]);
        app.ConfigFlexTable = uitable(right, 'Position', [24 65 330 125], ...
            'ColumnName', {'Appliance','Max Shift min','Comfort Weight','Controllable'}, ...
            'ColumnEditable', [false true true true], 'Data', cell(0,4));
        style_app_table(app.ConfigFlexTable, app.Theme);

        app.ConfigGroupTitleLabel = uilabel(right, 'Text', 'Selected group values', ...
            'FontSize', 11, 'FontWeight', 'bold', 'FontColor', c.text_light, ...
            'Position', [380 200 330 22]);
        app.ConfigDynamicPanel = uipanel(right, ...
            'Title', '', ...
            'BorderType', 'none', ...
            'BackgroundColor', c.bg_panel, ...
            'Position', [380 65 360 125]);
        app.ConfigDynamicControls = {};

        uibutton(right, 'push', 'Text', 'Save to cfg', 'FontWeight', 'bold', ...
            'Position', [24 18 120 34], 'ButtonPushedFcn', @(~, ~) onSaveConfig(app));
        uibutton(right, 'push', 'Text', 'Reset from cfg', ...
            'Position', [160 18 130 34], 'ButtonPushedFcn', @(~, ~) refreshConfigView(app));
        uibutton(right, 'push', 'Text', 'Validate', ...
            'Position', [306 18 120 34], 'ButtonPushedFcn', @(~, ~) onValidateConfig(app));
    end

    function createFeederView(app)
        % CREATEFEEDERVIEW Build feeder topology, assignment, and BFS test UI.
        c = app.Theme.colors;
        p = app.FeederPanel;
        addHeader(app, p, 'Feeder Model', 'Three-phase unbalanced LV feeder topology, assignments, and BFS smoke test.');

        topo = makeCard(app, p, 'Feeder Topology', [24 315 730 415]);
        app.FeederAxes = uiaxes(topo, 'Position', [20 45 685 325]);
        uibutton(topo, 'push', 'Text', 'Rebuild / Refresh', 'Position', [20 10 140 28], ...
            'ButtonPushedFcn', @(~, ~) refreshFeederView(app));
        uibutton(topo, 'push', 'Text', 'Pop Out', 'Position', [175 10 100 28], ...
            'ButtonPushedFcn', @(~, ~) app_popout_plot('feeder_topo', struct('net', app.net, 'assignment', app.assignment), app.cfg));

        assignCard = makeCard(app, p, 'Assignment Summary', [774 315 350 415]);
        app.FeederAssignmentTable = uitable(assignCard, 'Position', [18 55 310 310], ...
            'ColumnName', {'Zone','HH','EV','V2G','Phase A','Phase B','Phase C'}, 'Data', cell(0,7));
        style_app_table(app.FeederAssignmentTable, app.Theme);
        uibutton(assignCard, 'push', 'Text', 'Re-Assign', 'Position', [18 14 120 30], ...
            'ButtonPushedFcn', @(~, ~) onReassignHouseholds(app));

        smoke = makeCard(app, p, 'BFS Smoke Test', [24 95 1100 180]);
        addSmallLabel(app, smoke, 'P per phase/bus [kW]', [24 105 170 22]);
        app.FeederSmokePkwEdit = uieditfield(smoke, 'numeric', 'Value', 3.5, 'Limits', [0 500], 'Position', [190 105 80 28]);
        addSmallLabel(app, smoke, 'Q per phase/bus [kVAr]', [300 105 180 22]);
        app.FeederSmokeQkvarEdit = uieditfield(smoke, 'numeric', 'Value', 0.9, 'Limits', [0 500], 'Position', [480 105 80 28]);
        uibutton(smoke, 'push', 'Text', 'Run BFS', 'FontWeight', 'bold', 'Position', [590 105 120 30], ...
            'ButtonPushedFcn', @(~, ~) onRunBfsSmoke(app));
        app.FeederSmokeText = uitextarea(smoke, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [24 18 1040 70], 'Value', {'Run BFS to verify voltage, VUF, transformer loading, and losses.'});
    end

    function createLoadView(app)
        % CREATELOADVIEW Build single-household and population load UI.
        c = app.Theme.colors;
        p = app.LoadPanel;
        addHeader(app, p, 'Load Model', 'Behavior-driven household profile, occupancy, HVAC, EV, and population simulation preview.');

        top = makeCard(app, p, 'Single Household', [24 505 1100 225]);
        addSmallLabel(app, top, 'HH Index', [20 150 80 22]);
        app.LoadHouseholdSpinner = uispinner(top, 'Limits', [1 100], 'Value', 1, 'Step', 1, 'Position', [100 150 80 28]);
        addSmallLabel(app, top, 'Day', [210 150 50 22]);
        app.LoadDayDropDown = uidropdown(top, 'Items', {'Summer Weekday','Summer Weekend','Winter Weekday','Winter Weekend','Ramadan Weekday'}, ...
            'Value', 'Summer Weekday', 'Position', [260 150 160 28]);
        addSmallLabel(app, top, 'Temperature [C]', [450 150 115 22]);
        app.LoadTempEdit = uieditfield(top, 'numeric', 'Value', 42, 'Limits', [-10 60], 'Position', [570 150 80 28]);
        uibutton(top, 'push', 'Text', 'Simulate Household', 'FontWeight', 'bold', 'Position', [680 150 150 30], ...
            'ButtonPushedFcn', @(~, ~) onSimulateSingleHousehold(app));
        uibutton(top, 'push', 'Text', 'Pop Out Load', 'Position', [850 150 120 30], ...
            'ButtonPushedFcn', @(~, ~) onPopoutLastLoad(app));
        app.LoadInfoLabel = uilabel(top, 'Text', 'Household information appears after simulation.', ...
            'FontColor', c.text_light, 'Position', [20 105 1030 28]);
        app.LoadAxes = uiaxes(top, 'Position', [20 10 500 90]);
        app.OccupancyAxes = uiaxes(top, 'Position', [555 10 500 90]);

        popCard = makeCard(app, p, 'Population Simulation', [24 95 1100 380]);
        addSmallLabel(app, popCard, 'Mode', [20 310 60 22]);
        app.PopulationModeDropDown = uidropdown(popCard, 'Items', {'Representative','Full Config Period'}, ...
            'Value', 'Representative', 'Position', [80 310 165 28]);
        uibutton(popCard, 'push', 'Text', 'Run Full Population', 'FontWeight', 'bold', 'Position', [270 310 150 30], ...
            'ButtonPushedFcn', @(~, ~) onRunPopulation(app));
        uibutton(popCard, 'push', 'Text', 'Reload Cache', 'Position', [440 310 120 30], ...
            'ButtonPushedFcn', @(~, ~) onReloadPopulationCache(app));
        app.PopulationProgressLabel = uilabel(popCard, 'Text', 'Progress: idle', 'FontColor', c.text_light, 'Position', [20 275 800 25]);
        app.LiveLoadAxes = uiaxes(popCard, 'Position', [40 25 1000 235]);
        title(app.LiveLoadAxes, 'Mean Load per Transformer Zone');
    end

    function createPricingView(app)
        % CREATEPRICINGVIEW Build tariff curve and block calculator UI.
        c = app.Theme.colors;
        p = app.PricingPanel;
        addHeader(app, p, 'Pricing', 'Plot the seven tariff architectures and calculate Egyptian block tariff bills.');

        curve = makeCard(app, p, '24-hour Tariff Curves', [24 350 1100 380]);
        methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
        app.PricingMethodChecks = gobjects(numel(methods), 1);
        for k = 1:numel(methods)
            app.PricingMethodChecks(k) = uicheckbox(curve, 'Text', methods{k}, 'FontColor', c.text_light, ...
                'Value', k <= 4, 'Position', [20 + (k-1)*110 320 100 24]);
        end
        addSmallLabel(app, curve, 'Day type', [820 320 70 22]);
        app.PricingDayDropDown = uidropdown(curve, 'Items', {'Summer Weekday','Winter Weekday','Summer Weekend'}, ...
            'Value', 'Summer Weekday', 'Position', [890 320 150 28]);
        uibutton(curve, 'push', 'Text', 'Plot', 'FontWeight', 'bold', 'Position', [20 285 80 28], ...
            'ButtonPushedFcn', @(~, ~) onPlotTariffs(app));
        uibutton(curve, 'push', 'Text', 'Pop Out', 'Position', [115 285 90 28], ...
            'ButtonPushedFcn', @(~, ~) app_popout_plot('pricing_curves', struct('cfg', app.cfg), app.cfg));
        app.PricingAxes = uiaxes(curve, 'Position', [45 35 1000 235]);

        block = makeCard(app, p, 'Block Tariff Bill Calculator', [24 95 1100 220]);
        addSmallLabel(app, block, 'Monthly Consumption [kWh]', [24 150 180 22]);
        app.BlockKwhEdit = uieditfield(block, 'numeric', 'Value', 110, 'Limits', [0 Inf], 'Position', [210 150 100 28]);
        uibutton(block, 'push', 'Text', 'Calculate Bill', 'FontWeight', 'bold', 'Position', [330 150 130 30], ...
            'ButtonPushedFcn', @(~, ~) onCalculateBlockBill(app));
        app.BlockBillText = uilabel(block, 'Text', 'Total: -- EGP/month', 'FontSize', 14, 'FontWeight', 'bold', ...
            'FontColor', c.accent, 'Position', [490 150 320 28]);
        app.BlockSlabTable = uitable(block, 'Position', [24 18 1040 115], ...
            'ColumnName', {'Slab','Energy kWh','Rate EGP/kWh','Charge EGP'}, 'Data', cell(0,4));
        style_app_table(app.BlockSlabTable, app.Theme);
    end

    function createScenariosView(app)
        % CREATESCENARIOSVIEW Build scenario cards, controls, live plot, and log.
        c = app.Theme.colors;
        p = app.ScenariosPanel;
        addHeader(app, p, 'Scenarios', 'Run baseline and DSM scenarios sequentially with progress callbacks, live log, and feeder-load preview.');

        cardPanel = makeCard(app, p, 'Scenario Cards', [24 620 1100 110]);
        ids = [-1 0 1 2 3 4 5 6];
        names = {'Baseline 0','Scenario 0','Scenario 1','Scenario 2','Scenario 3','Scenario 4','Scenario 5','Scenario 6'};
        tags = {'No EV / No DSM','Rule DSM / No EV','Uncontrolled EV','Slow vs Fast','MILP EV','MILP Loads+EV','MILP+V2G','Full AI-DSM'};
        app.ScenarioCards = gobjects(numel(ids), 1);
        app.ScenarioStatusLabels = gobjects(numel(ids), 1);
        app.ScenarioSelectionChecks = gobjects(numel(ids), 1);
        for k = 1:numel(ids)
            x = 12 + (k-1) * 134;
            card = uipanel(cardPanel, 'Title', '', 'BackgroundColor', c.bg_card, ...
                'ForegroundColor', c.text_light, 'Position', [x 12 124 65]);
            app.ScenarioCards(k) = card;
            app.ScenarioSelectionChecks(k) = uicheckbox(card, 'Text', '', 'Value', ismember(ids(k), [-1 1 4 6]), ...
                'Position', [5 38 20 20]);
            uilabel(card, 'Text', names{k}, 'FontWeight', 'bold', 'FontSize', 10, ...
                'FontColor', c.text_light, 'Position', [25 38 92 18]);
            uilabel(card, 'Text', tags{k}, 'FontSize', 8, 'FontColor', c.text_muted, ...
                'Position', [8 20 110 16]);
            app.ScenarioStatusLabels(k) = uilabel(card, 'Text', 'Not run', 'FontSize', 8, ...
                'FontWeight', 'bold', 'FontColor', c.text_muted, 'Position', [8 4 110 16]);
        end

        detail = makeCard(app, p, 'Active Scenario Detail', [24 500 1100 100]);
        addSmallLabel(app, detail, 'Scenario', [20 45 75 22]);
        app.ScenarioRunDropDown = uidropdown(detail, ...
            'Items', {'Baseline 0','Scenario 0','Scenario 1','Scenario 2','Scenario 3','Scenario 4','Scenario 5','Scenario 6'}, ...
            'ItemsData', ids, 'Value', 4, 'Position', [95 45 170 28], ...
            'ValueChangedFcn', @(~, ~) refreshScenarioDetail(app));
        uibutton(detail, 'push', 'Text', 'Run This', 'FontWeight', 'bold', ...
            'Position', [290 45 110 30], 'ButtonPushedFcn', @(~, ~) onRunThisScenario(app));
        uibutton(detail, 'push', 'Text', 'Run Selected', ...
            'Position', [415 45 125 30], 'ButtonPushedFcn', @(~, ~) onRunCheckedScenarios(app));
        uibutton(detail, 'push', 'Text', 'Stop', ...
            'Position', [555 45 85 30], 'ButtonPushedFcn', @(~, ~) onStopScenarios(app));
        uibutton(detail, 'push', 'Text', 'Reset', ...
            'Position', [655 45 85 30], 'ButtonPushedFcn', @(~, ~) onResetScenarios(app));
        app.ScenarioDetailText = uilabel(detail, 'Text', 'Scenario 4 - MILP loads + EV, no V2G.', ...
            'FontColor', c.text_light, 'WordWrap', 'on', 'Position', [20 10 1040 26]);

        exec = makeCard(app, p, 'Live Execution', [24 95 1100 385]);
        app.ScenarioProgressText = uilabel(exec, 'Text', 'Progress: idle', 'FontColor', c.text_light, ...
            'FontWeight', 'bold', 'Position', [20 320 1020 26]);
        app.ScenarioLiveAxes = uiaxes(exec, 'Position', [40 45 610 260]);
        title(app.ScenarioLiveAxes, 'Live / Last Scenario Three-Phase Feeder Load');
        xlabel(app.ScenarioLiveAxes, 'Time step');
        ylabel(app.ScenarioLiveAxes, 'Power [kW]');
        app.ScenarioLog = uitextarea(exec, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [680 45 390 260], 'Value', {'> Scenario log initialized.'});
        uibutton(exec, 'push', 'Text', 'Pop Out Live Plot', 'Position', [40 12 135 26], ...
            'ButtonPushedFcn', @(~, ~) onPopoutScenarioPlot(app));
        uibutton(exec, 'push', 'Text', 'Open Results Folder', 'Position', [190 12 145 26], ...
            'ButtonPushedFcn', @(~, ~) onOpenResultsFolder(app));
    end


    function createResultsView(app)
        % CREATERESULTSVIEW Build Step 13 Results view and six sub-views.
        c = app.Theme.colors;
        p = app.ResultsPanel;
        addHeader(app, p, 'Results', 'PQ dashboard, scenario comparison, hosting capacity, cost analysis, twin inspector, and uncertainty analysis.');

        names = {'PQ Dashboard','Comparison','Hosting','Cost','Twin','UQ'};
        app.ResultsSubButtons = gobjects(1, numel(names));
        for k = 1:numel(names)
            app.ResultsSubButtons(k) = uibutton(p, 'push', 'Text', names{k}, ...
                'FontWeight', 'bold', 'FontColor', c.text_light, 'BackgroundColor', c.bg_panel, ...
                'Position', [24 + (k-1)*178 690 165 34], ...
                'ButtonPushedFcn', @(~, ~) switchResultsSubView(app, k));
        end

        app.ResultsSubPanels = gobjects(1, 6);
        for k = 1:6
            app.ResultsSubPanels(k) = uipanel(p, 'Title', '', 'BorderType', 'none', ...
                'BackgroundColor', c.bg_dark, 'Position', [24 90 1100 590], 'Visible', 'off');
        end

        createResultsPqDashboard(app, app.ResultsSubPanels(1));
        createResultsComparison(app, app.ResultsSubPanels(2));
        createResultsHosting(app, app.ResultsSubPanels(3));
        createResultsCost(app, app.ResultsSubPanels(4));
        createResultsTwin(app, app.ResultsSubPanels(5));
        createResultsUq(app, app.ResultsSubPanels(6));
        switchResultsSubView(app, 1);
    end

    function createExportView(app)
        % CREATEEXPORTVIEW Build Step 14 figure/CSV/LaTeX export UI.
        c = app.Theme.colors;
        p = app.ExportPanel;
        addHeader(app, p, 'Export', 'Export thesis-ready figures, CSV tables, and a LaTeX report from lean scenario results.');

        figCard = makeCard(app, p, 'Figure Export', [24 455 1100 275]);
        figNames = {'VUF Comparison Bar Chart','Hosting Capacity Curve','Load Profiles Summer+Winter', ...
            'Monthly Bill Box Plots','Tariff Slab Migration Chart','Bus Voltage Map','PQ Time-Series'};
        figKeys = {'vuf_comparison','hosting_capacity','load_profiles','monthly_bill_box', ...
            'tariff_slab_migration','bus_voltage_map','pq_timeseries'};
        app.ExportFigureChecks = gobjects(numel(figNames), 1);
        for k = 1:numel(figNames)
            col = floor((k-1) / 4);
            row = mod(k-1, 4);
            app.ExportFigureChecks(k) = uicheckbox(figCard, 'Text', figNames{k}, ...
                'FontColor', c.text_light, 'Value', k <= 4, ...
                'UserData', figKeys{k}, 'Position', [24 + col*420 205 - row*38 360 24]);
        end
        app.ExportFormatPngCheck = uicheckbox(figCard, 'Text', 'PNG 300 dpi', 'FontColor', c.text_light, ...
            'Value', true, 'Position', [24 44 120 24]);
        app.ExportFormatEpsCheck = uicheckbox(figCard, 'Text', 'EPS', 'FontColor', c.text_light, ...
            'Value', true, 'Position', [155 44 70 24]);
        app.ExportFormatSvgCheck = uicheckbox(figCard, 'Text', 'SVG', 'FontColor', c.text_light, ...
            'Value', false, 'Position', [230 44 70 24]);
        addSmallLabel(app, figCard, 'Size', [330 44 45 22]);
        app.ExportSizeDropDown = uidropdown(figCard, 'Items', {'IEEE 2-col 180mm','IEEE 1-col 88mm','A4'}, ...
            'Value', 'IEEE 2-col 180mm', 'Position', [375 42 160 28]);
        addSmallLabel(app, figCard, 'Folder', [560 44 55 22]);
        app.ExportFolderEdit = uieditfield(figCard, 'text', 'Editable', 'off', ...
            'Position', [615 42 300 28]);
        uibutton(figCard, 'push', 'Text', 'Browse...', 'Position', [930 42 80 28], ...
            'ButtonPushedFcn', @(~, ~) onBrowseExportFolder(app));
        uibutton(figCard, 'push', 'Text', 'Export Selected', 'FontWeight', 'bold', ...
            'Position', [24 8 135 28], 'ButtonPushedFcn', @(~, ~) onExportSelectedFigures(app));
        uibutton(figCard, 'push', 'Text', 'Export ALL Figures', ...
            'Position', [175 8 145 28], 'ButtonPushedFcn', @(~, ~) onExportAllFigures(app));

        csvCard = makeCard(app, p, 'CSV / Table Export', [24 270 1100 160]);
        csvNames = {'PQ Summary','Scenario Matrix','Monthly Costs','Hosting Data','Sensitivity','Monte Carlo Stats'};
        csvKeys = {'scenario_summary','scenario_summary','cost_summary','violations','sensitivity','monte_carlo'};
        app.ExportCsvChecks = gobjects(numel(csvNames), 1);
        for k = 1:numel(csvNames)
            app.ExportCsvChecks(k) = uicheckbox(csvCard, 'Text', csvNames{k}, 'FontColor', c.text_light, ...
                'Value', k <= 4, 'UserData', csvKeys{k}, 'Position', [24 + (k-1)*170 82 160 24]);
        end
        uibutton(csvCard, 'push', 'Text', 'Export Selected CSVs', 'FontWeight', 'bold', ...
            'Position', [24 32 165 32], 'ButtonPushedFcn', @(~, ~) onExportSelectedCsv(app));
        uibutton(csvCard, 'push', 'Text', 'Open Tables Folder', ...
            'Position', [205 32 150 32], 'ButtonPushedFcn', @(~, ~) onOpenResultsFolder(app));

        latexCard = makeCard(app, p, 'PDF / LaTeX Thesis Report', [24 95 1100 150]);
        addSmallLabel(app, latexCard, 'Author', [24 82 65 22]);
        app.ExportAuthorEdit = uieditfield(latexCard, 'text', 'Value', 'Mohammed Ahmed', ...
            'Position', [90 82 220 28]);
        addSmallLabel(app, latexCard, 'Date', [335 82 45 22]);
        app.ExportDateEdit = uieditfield(latexCard, 'text', 'Value', datestr(now, 'yyyy-mm'), ...
            'Position', [380 82 120 28]);
        uibutton(latexCard, 'push', 'Text', 'Generate PDF Report', 'FontWeight', 'bold', ...
            'Position', [525 82 170 30], 'ButtonPushedFcn', @(~, ~) onGeneratePdfReport(app));
        uibutton(latexCard, 'push', 'Text', 'Generate LaTeX .tex', ...
            'Position', [710 82 170 30], 'ButtonPushedFcn', @(~, ~) onGenerateLatexReport(app));
        app.ExportLatexStatusText = uitextarea(latexCard, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [24 15 1040 52], 'Value', {'Generate a modern PDF report or a LaTeX include file after exporting figures/tables.'});

        statusCard = makeCard(app, p, 'Export Log', [24 24 1100 55]);
        app.ExportStatusText = uitextarea(statusCard, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [15 8 1070 25], 'Value', {'Export system ready.'});
    end

    function createTestsView(app)
        % CREATETESTSVIEW Build Step 15 interactive validation runner UI.
        c = app.Theme.colors;
        p = app.TestsPanel;
        addHeader(app, p, 'Tests', 'Run validation suites from the app, monitor status, inspect details, and save a report.');

        controlCard = makeCard(app, p, 'Test Controls', [24 640 1100 90]);
        app.TestsRunAllButton = uibutton(controlCard, 'push', 'Text', 'Run All Tests', ...
            'FontWeight', 'bold', 'Position', [20 28 130 34], ...
            'ButtonPushedFcn', @(~, ~) onRunAllUiTests(app));
        app.TestsRunSelectedButton = uibutton(controlCard, 'push', 'Text', 'Run Selected', ...
            'Position', [165 28 130 34], 'ButtonPushedFcn', @(~, ~) onRunSelectedUiTests(app));
        app.TestsClearButton = uibutton(controlCard, 'push', 'Text', 'Clear Results', ...
            'Position', [310 28 120 34], 'ButtonPushedFcn', @(~, ~) onClearUiTests(app));
        app.TestsSaveButton = uibutton(controlCard, 'push', 'Text', 'Save Test Report', ...
            'Position', [445 28 145 34], 'ButtonPushedFcn', @(~, ~) onSaveUiTestReport(app));
        app.TestsSummaryLabel = uilabel(controlCard, 'Text', 'Ready. Select tests and run.', ...
            'FontColor', c.text_light, 'FontWeight', 'bold', 'Position', [620 40 440 22]);
        app.TestsProgressLabel = uilabel(controlCard, 'Text', '[--------------------] 0%', ...
            'FontName', app.Theme.font.mono, 'FontColor', c.accent, ...
            'HorizontalAlignment', 'left', 'Position', [620 16 400 22]);

        tableCard = makeCard(app, p, 'Validation Test Matrix', [24 250 690 370]);
        app.TestsTable = uitable(tableCard, ...
            'Position', [15 15 660 315], ...
            'ColumnName', {'Run','Test','Status','Time_s','Last run','Last result'}, ...
            'ColumnEditable', [true false false false false false], ...
            'ColumnFormat', {'logical','char','char','numeric','char','char'}, ...
            'CellSelectionCallback', @(~, event) onTestTableSelection(app, event), ...
            'Data', buildInitialTestTable(app));
        style_app_table(app.TestsTable, app.Theme);

        detailCard = makeCard(app, p, 'DETAIL', [734 250 390 370]);
        app.TestsDetailText = uitextarea(detailCard, 'Editable', 'off', ...
            'FontName', app.Theme.font.mono, 'FontSize', 10, ...
            'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [15 15 360 315], ...
            'Value', {'Click a test row to show details.', 'Use Run Selected for shorter validation cycles.'});

        summaryCard = makeCard(app, p, 'Execution Notes', [24 95 1100 130]);
        uitextarea(summaryCard, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [15 15 1070 82], ...
            'Value', {'Compiled-safe test execution: sequential for-loop, no parfeval, no parfor.', ...
                      'Long scenario/visualization tests may still take time. The UI remains responsive through drawnow(''limitrate'').', ...
                      'Reports are saved under <project_root>/results/tables/ui_test_report.csv.'});
    end

    function createResultsPqDashboard(app, panel)
        % CREATERESULTSPQDASHBOARD Build KPI text, PQ plot, and bus voltage map.
        c = app.Theme.colors;
        ctrl = makeCard(app, panel, 'PQ Dashboard Controls', [0 500 1100 80]);
        addSmallLabel(app, ctrl, 'Scenario', [20 22 70 22]);
        app.ResultsPqScenarioDropDown = uidropdown(ctrl, 'Items', {'Last result'}, 'Value', 'Last result', ...
            'Position', [95 22 185 28], 'ValueChangedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Refresh Results', 'FontWeight', 'bold', ...
            'Position', [305 22 130 30], 'ButtonPushedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Pop Out PQ', ...
            'Position', [455 22 105 30], 'ButtonPushedFcn', @(~, ~) onPopoutResults(app, 'pq'));

        summary = makeCard(app, panel, 'KPI Gauges / Summary', [0 315 330 170]);
        app.ResultsPqTextArea = uitextarea(summary, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [15 15 300 120], 'Value', {'Run scenarios to populate PQ summary.'});

        plotCard = makeCard(app, panel, 'PQ KPI Overview', [350 315 750 170]);
        app.ResultsPqAxes = uiaxes(plotCard, 'Position', [35 25 690 110]);
        title(app.ResultsPqAxes, 'PQ metrics');

        vCard = makeCard(app, panel, 'Bus Voltage Map / Scenario Load Preview', [0 10 1100 285]);
        app.ResultsVoltageAxes = uiaxes(vCard, 'Position', [35 30 1020 210]);
        title(app.ResultsVoltageAxes, 'Bus voltage or retained three-phase feeder load');
    end

    function createResultsComparison(app, panel)
        % CREATERESULTSCOMPARISON Build multi-scenario comparison chart/table.
        ctrl = makeCard(app, panel, 'Scenario Comparison Controls', [0 500 1100 80]);
        addSmallLabel(app, ctrl, 'Metric', [20 22 60 22]);
        app.ResultsCompareMetricDropDown = uidropdown(ctrl, ...
            'Items', {'Mean VUF %','Peak VUF %','Vmin pu','Max TL %','Hosting %','Comfort CI','Block Cost EGP'}, ...
            'Value', 'Mean VUF %', 'Position', [85 22 160 28], ...
            'ValueChangedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Update', 'FontWeight', 'bold', ...
            'Position', [270 22 95 30], 'ButtonPushedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Pop Out', ...
            'Position', [380 22 95 30], 'ButtonPushedFcn', @(~, ~) onPopoutResults(app, 'comparison'));

        chart = makeCard(app, panel, 'Comparison Chart', [0 185 1100 300]);
        app.ResultsCompareAxes = uiaxes(chart, 'Position', [45 35 1000 220]);
        title(app.ResultsCompareAxes, 'Scenario comparison');

        tableCard = makeCard(app, panel, 'Comparison Table', [0 10 1100 155]);
        app.ResultsCompareTable = uitable(tableCard, 'Position', [15 15 1070 105], ...
            'ColumnName', {'Scenario','Mean VUF %','Peak VUF %','Vmin pu','Max TL %','Hosting %','Comfort CI','Block Cost EGP'}, ...
            'Data', cell(0,8));
        style_app_table(app.ResultsCompareTable, app.Theme);
    end

    function createResultsHosting(app, panel)
        % CREATERESULTSHOSTING Build hosting capacity curve and summary table.
        ctrl = makeCard(app, panel, 'Hosting Capacity', [0 500 1100 80]);
        uilabel(ctrl, 'Text', 'Displays retained hosting_capacity_pct plus synthetic planning curves for thesis preview.', ...
            'FontColor', app.Theme.colors.text_light, 'Position', [20 24 760 24]);
        uibutton(ctrl, 'push', 'Text', 'Refresh', 'FontWeight', 'bold', ...
            'Position', [840 22 95 30], 'ButtonPushedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Pop Out', ...
            'Position', [950 22 95 30], 'ButtonPushedFcn', @(~, ~) onPopoutResults(app, 'hosting'));

        chart = makeCard(app, panel, 'Hosting Curve', [0 185 1100 300]);
        app.ResultsHostingAxes = uiaxes(chart, 'Position', [45 35 1000 220]);
        title(app.ResultsHostingAxes, 'EV penetration versus PQ indicators');

        tableCard = makeCard(app, panel, 'Hosting Summary', [0 10 1100 155]);
        app.ResultsHostingTable = uitable(tableCard, 'Position', [15 15 1070 105], ...
            'ColumnName', {'Scenario','Hosting Cap %','Binding Constraint','Mean VUF %','Vmin pu','Max TL %'}, ...
            'Data', cell(0,6));
        style_app_table(app.ResultsHostingTable, app.Theme);
    end

    function createResultsCost(app, panel)
        % CREATERESULTSCOST Build cost analysis chart/table.
        ctrl = makeCard(app, panel, 'Cost Analysis Controls', [0 500 1100 80]);
        addSmallLabel(app, ctrl, 'Tariff', [20 22 60 22]);
        app.ResultsCostTariffDropDown = uidropdown(ctrl, 'Items', {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'}, ...
            'Value', 'Block', 'Position', [85 22 140 28], 'ValueChangedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Update', 'FontWeight', 'bold', ...
            'Position', [250 22 95 30], 'ButtonPushedFcn', @(~, ~) refreshResultsView(app));
        uibutton(ctrl, 'push', 'Text', 'Pop Out', ...
            'Position', [360 22 95 30], 'ButtonPushedFcn', @(~, ~) onPopoutResults(app, 'cost'));

        chart = makeCard(app, panel, 'Monthly Bill / Scenario Cost', [0 185 1100 300]);
        app.ResultsCostAxes = uiaxes(chart, 'Position', [45 35 1000 220]);
        title(app.ResultsCostAxes, 'Cost comparison');

        tableCard = makeCard(app, panel, 'Cost Table', [0 10 1100 155]);
        app.ResultsCostTable = uitable(tableCard, 'Position', [15 15 1070 105], ...
            'ColumnName', {'Scenario','Tariff','Mean Bill EGP','Min Bill EGP','Max Bill EGP','EV Increment EGP'}, ...
            'Data', cell(0,6));
        style_app_table(app.ResultsCostTable, app.Theme);
    end

    function createResultsTwin(app, panel)
        % CREATERESULTSTWIN Build household digital twin inspector.
        c = app.Theme.colors;
        ctrl = makeCard(app, panel, 'Digital Twin Inspector', [0 500 1100 80]);
        addSmallLabel(app, ctrl, 'HH Index', [20 22 75 22]);
        app.ResultsTwinHouseholdSpinner = uispinner(ctrl, 'Limits', [1 100], 'Value', 1, 'Step', 1, 'Position', [95 22 80 28]);
        addSmallLabel(app, ctrl, 'Day', [205 22 40 22]);
        app.ResultsTwinDayDropDown = uidropdown(ctrl, 'Items', {'Summer Weekday','Summer Weekend','Winter Weekday','Winter Weekend'}, ...
            'Value', 'Summer Weekday', 'Position', [245 22 160 28]);
        uibutton(ctrl, 'push', 'Text', 'Reload Twin', 'FontWeight', 'bold', ...
            'Position', [430 22 110 30], 'ButtonPushedFcn', @(~, ~) onReloadResultsTwin(app));

        plotCard = makeCard(app, panel, 'Twin 24h Load Profile', [0 185 660 300]);
        app.ResultsTwinAxes = uiaxes(plotCard, 'Position', [35 35 585 220]);
        title(app.ResultsTwinAxes, 'Twin-driven profile');

        flexCard = makeCard(app, panel, 'Flexibility Windows', [680 185 420 300]);
        app.ResultsTwinFlexTable = uitable(flexCard, 'Position', [15 55 390 190], ...
            'ColumnName', {'Appliance','Preferred','Window','Max Shift','CI'}, 'Data', cell(0,5));
        style_app_table(app.ResultsTwinFlexTable, app.Theme);
        app.ResultsTwinCommandApplianceDropDown = uidropdown(flexCard, 'Items', {'No controllable load'}, ...
            'Position', [15 15 155 28]);
        app.ResultsTwinCommandStartEdit = uieditfield(flexCard, 'numeric', 'Value', 1, 'Limits', [1 96], ...
            'Position', [185 15 70 28]);
        uibutton(flexCard, 'push', 'Text', 'Send Command', 'Position', [270 15 120 28], ...
            'ButtonPushedFcn', @(~, ~) onSendTwinCommand(app));

        statusCard = makeCard(app, panel, 'Twin Status', [0 10 1100 155]);
        app.ResultsTwinStatusText = uitextarea(statusCard, 'Editable', 'off', 'FontName', app.Theme.font.mono, ...
            'FontSize', 10, 'FontColor', c.text_light, 'BackgroundColor', [0.07 0.07 0.12], ...
            'Position', [15 15 1070 105], 'Value', {'Reload a household twin to inspect flexibility and EV status.'});
    end

    function createResultsUq(app, panel)
        % CREATERESULTSUQ Build Monte Carlo / sensitivity placeholder dashboard.
        ctrl = makeCard(app, panel, 'Uncertainty Analysis Controls', [0 500 1100 80]);
        addSmallLabel(app, ctrl, 'Scenario', [20 22 70 22]);
        app.ResultsUqScenarioDropDown = uidropdown(ctrl, 'Items', {'Scenario 4','Scenario 6'}, 'ItemsData', [4 6], ...
            'Value', 4, 'Position', [95 22 140 28]);
        addSmallLabel(app, ctrl, 'N runs', [260 22 60 22]);
        app.ResultsUqRunsSpinner = uispinner(ctrl, 'Limits', [2 100], 'Value', 10, 'Step', 1, 'Position', [320 22 80 28]);
        uibutton(ctrl, 'push', 'Text', 'Preview UQ', 'FontWeight', 'bold', ...
            'Position', [425 22 110 30], 'ButtonPushedFcn', @(~, ~) onPreviewUq(app));

        chart = makeCard(app, panel, 'UQ KPI Distributions', [0 185 1100 300]);
        app.ResultsUqAxes = uiaxes(chart, 'Position', [45 35 1000 220]);
        title(app.ResultsUqAxes, 'Monte Carlo / sensitivity preview');

        tableCard = makeCard(app, panel, 'UQ Statistics', [0 10 1100 155]);
        app.ResultsUqTable = uitable(tableCard, 'Position', [15 15 1070 105], ...
            'ColumnName', {'KPI','Mean','Std','P5','P50','P95'}, 'Data', cell(0,6));
        style_app_table(app.ResultsUqTable, app.Theme);
    end

    function createStatusBar(app)
        % CREATESTATUSBAR Build persistent bottom status area.
        c = app.Theme.colors;

        app.StatusPanel = uipanel(app.RootGrid, 'Title', '', 'BorderType', 'none', ...
            'BackgroundColor', [0.06 0.06 0.10]);
        app.StatusPanel.Layout.Row = 2;
        app.StatusPanel.Layout.Column = [1 2];

        app.StatusBar = uilabel(app.StatusPanel, 'Text', 'Initializing...', 'FontSize', 10, ...
            'FontColor', c.text_light, 'Position', [12 4 620 22]);
        app.ProgressBar = uilabel(app.StatusPanel, 'Text', '[--------------------] 0%', ...
            'FontName', app.Theme.font.mono, 'FontSize', 10, 'FontColor', c.accent, ...
            'HorizontalAlignment', 'right', 'Position', [910 4 240 22]);
        app.ProgressLabel = uilabel(app.StatusPanel, 'Text', 'Stage: startup', 'FontSize', 10, ...
            'FontColor', c.text_muted, 'Position', [1160 4 220 22]);
    end

    function addHeader(app, parent, titleText, subtitleText)
        % ADDHEADER Add standard title/subtitle labels.
        c = app.Theme.colors;
        uilabel(parent, 'Text', titleText, 'FontSize', 24, 'FontWeight', 'bold', ...
            'FontColor', c.text_light, 'Position', [24 760 400 40]);
        uilabel(parent, 'Text', subtitleText, 'FontSize', 13, 'FontColor', c.text_muted, ...
            'Position', [24 735 850 26]);
    end

    function panel = makeCard(app, parent, titleText, pos)
        % MAKECARD Create a panel card with common styling.
        c = app.Theme.colors;
        panel = uipanel(parent, 'Title', titleText, 'FontWeight', 'bold', ...
            'ForegroundColor', c.text_light, 'BackgroundColor', c.bg_panel, ...
            'Position', pos);
    end

    function addSmallLabel(app, parent, txt, pos)
        % ADDSMALLLABEL Add a compact white label.
        c = app.Theme.colors;
        uilabel(parent, 'Text', txt, 'FontSize', 11, 'FontColor', c.text_light, 'Position', pos);
    end

    function runStartup(app)
        % RUNSTARTUP Load project state with defensive error handling.
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

            refreshAllImplementedViews(app);
            loadSavedUiState(app);
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

    function refreshAllImplementedViews(app)
        % REFRESHALLIMPLEMENTEDVIEWS Update data-dependent UI controls.
        refreshDashboard(app);
        refreshConfigView(app);
        refreshFeederView(app);
        onPlotTariffs(app);
        onCalculateBlockBill(app);
        refreshResultsView(app);
        refreshExportView(app);
        refreshTestsView(app);
    end

    function refreshDashboard(app)
        % REFRESHDASHBOARD Update status cards and KPIs.
        if isempty(app.cfg)
            return;
        end
        try
            app.DashboardSubtitleLabels(1).Text = sprintf('%s, %s | dt=%d min', app.cfg.location.city, app.cfg.location.country, app.cfg.simulation.dt_min);
            app.DashboardSubtitleLabels(2).Text = sprintf('%d households | %d activities', height(app.data.household), height(app.data.activities));
            app.DashboardSubtitleLabels(3).Text = sprintf('%s | %.1f..%.1f C', app.weather.meta.source, min(app.weather.temp_C), max(app.weather.temp_C));
            if isempty(app.pop)
                app.DashboardSubtitleLabels(4).Text = 'Not simulated';
            else
                app.DashboardSubtitleLabels(4).Text = sprintf('Cached | %d x %d matrix', size(app.pop.L_house_w,1), size(app.pop.L_house_w,2));
            end
            app.DashboardKpiLabels(1).Text = '--';
            app.DashboardKpiLabels(2).Text = '--';
            app.DashboardKpiLabels(3).Text = sprintf('%.0f%% target', 100 * app.cfg.ev.penetration_rate);
            app.DashboardKpiLabels(4).Text = sprintf('CI >= %.2f', app.cfg.dsm.comfort_ci_threshold);
            app.DashboardKpiLabels(5).Text = 'None yet';
            lastResult = getLatestScenarioResult(app);
            if ~isempty(lastResult)
                updateDashboardFromScenario(app, lastResult);
            end
            app_feeder_plot(app.net, app.assignment, app.DashboardFeederAxes);
            style_app_axes(app.DashboardFeederAxes, app.Theme);
        catch ME
            log(app, sprintf('Dashboard refresh warning: %s', ME.message));
        end
    end

    function refreshConfigView(app)
        % REFRESHCONFIGVIEW Populate config controls from cfg.
        if isempty(app.cfg)
            return;
        end
        try
            app.ConfigEvPenSlider.Value = 100 * app.cfg.ev.penetration_rate;
            app.ConfigEvPenValueLabel.Text = sprintf('%.0f%%', 100 * app.cfg.ev.penetration_rate);
            app.ConfigChargerDropDown.Value = char(string(app.cfg.ev.charger_type));
            app.ConfigSlowKwEdit.Value = app.cfg.ev.slow_kw;
            app.ConfigFastKwEdit.Value = app.cfg.ev.fast_kw;
            app.ConfigV2GCheckBox.Value = logical(app.cfg.ev.v2g_enabled);
            app.ConfigV2GRevenueEdit.Value = app.cfg.ev.v2g_revenue_fraction;
            app.ConfigV2GReserveSlider.Value = app.cfg.ev.soc_v2g_reserve_pct;
            app.ConfigArrivalEdit.Value = app.cfg.ev.arrival_mean_hour;
            app.ConfigDepartureEdit.Value = app.cfg.ev.departure_mean_hour;
            app.ConfigDsmControllerDropDown.Value = char(string(app.cfg.dsm.controller));
            app.ConfigLambdaEdit.Value = app.cfg.dsm.lambda_comfort;
            app.ConfigComfortThresholdSlider.Value = app.cfg.dsm.comfort_ci_threshold;
            app.ConfigFlexTable.Data = buildFlexibilityTable(app.cfg);
            updateConfigGroupView(app);
            app.ConfigValidationText.Value = {'Config loaded into UI controls.'};
        catch ME
            app.ConfigValidationText.Value = {sprintf('Config refresh error: %s', ME.message)};
        end
    end

    function onConfigGroupChanged(app)
        % ONCONFIGGROUPCHANGED Update the selected-group config table.
        updateConfigGroupView(app);
        log(app, sprintf('Config group selected: %s', app.ConfigGroupList.Value));
    end

    function onConfigSliderChanged(app)
        % ONCONFIGSLIDERCHANGED Update visible slider label.
        app.ConfigEvPenValueLabel.Text = sprintf('%.0f%%', app.ConfigEvPenSlider.Value);
    end

    function onSaveConfig(app)
        % ONSAVECONFIG Apply UI values into app.cfg.
        try
            app.cfg.ev.penetration_rate = app.ConfigEvPenSlider.Value / 100;
            app.cfg.ev.charger_type = app.ConfigChargerDropDown.Value;
            app.cfg.ev.slow_kw = app.ConfigSlowKwEdit.Value;
            app.cfg.ev.fast_kw = app.ConfigFastKwEdit.Value;
            app.cfg.ev.v2g_enabled = logical(app.ConfigV2GCheckBox.Value);
            app.cfg.ev.v2g_revenue_fraction = app.ConfigV2GRevenueEdit.Value;
            app.cfg.ev.soc_v2g_reserve_pct = app.ConfigV2GReserveSlider.Value;
            app.cfg.ev.v2g_reserve_soc_pct = app.ConfigV2GReserveSlider.Value;
            app.cfg.ev.arrival_mean_hour = app.ConfigArrivalEdit.Value;
            app.cfg.ev.departure_mean_hour = app.ConfigDepartureEdit.Value;
            app.cfg.dsm.controller = app.ConfigDsmControllerDropDown.Value;
            app.cfg.dsm.lambda_comfort = app.ConfigLambdaEdit.Value;
            app.cfg.dsm.comfort_ci_threshold = app.ConfigComfortThresholdSlider.Value;
            syncDynamicConfigControls(app);
            app.cfg = applyFlexibilityTable(app.cfg, app.ConfigFlexTable.Data);
            app.ConfigValidationText.Value = {'Saved UI values to in-memory cfg.', 'Use Export/Config save in later UI steps for file persistence.'};
            log(app, 'Configuration values saved to app.cfg.');
            refreshDashboard(app);
        catch ME
            app.ConfigValidationText.Value = {sprintf('Save failed: %s', ME.message)};
            log(app, sprintf('Config save failed: %s', ME.message));
        end
    end

    function onValidateConfig(app)
        % ONVALIDATECONFIG Run lightweight config validation.
        msgs = {};
        try
            if app.ConfigEvPenSlider.Value < 0 || app.ConfigEvPenSlider.Value > 100
                error('EV penetration must be in [0,100]%%.');
            end
            if app.ConfigSlowKwEdit.Value <= 0 || app.ConfigFastKwEdit.Value <= 0
                error('Charger powers must be positive.');
            end
            if app.ConfigComfortThresholdSlider.Value < 0 || app.ConfigComfortThresholdSlider.Value > 1
                error('Comfort threshold must be in [0,1].');
            end
            msgs{end+1} = 'PASS: UI config values are valid.'; %#ok<AGROW>
            msgs{end+1} = sprintf('EV penetration = %.1f%%', app.ConfigEvPenSlider.Value); %#ok<AGROW>
            msgs{end+1} = sprintf('Comfort threshold = %.2f', app.ConfigComfortThresholdSlider.Value); %#ok<AGROW>
            app.ConfigValidationText.Value = msgs;
            log(app, 'Configuration validation passed.');
        catch ME
            app.ConfigValidationText.Value = {sprintf('FAIL: %s', ME.message)};
            log(app, sprintf('Configuration validation failed: %s', ME.message));
        end
    end

    function refreshFeederView(app)
        % REFRESHFEEDERVIEW Redraw topology and assignment table.
        if isempty(app.net)
            return;
        end
        try
            app_feeder_plot(app.net, app.assignment, app.FeederAxes);
            app.FeederAssignmentTable.Data = buildAssignmentSummary(app.assignment, app.net);
            log(app, 'Feeder view refreshed.');
        catch ME
            log(app, sprintf('Feeder refresh failed: %s', ME.message));
        end
    end

    function onReassignHouseholds(app)
        % ONREASSIGNHOUSEHOLDS Regenerate assignment with current cfg.
        try
            app.assignment = assign_households(app.cfg, app.data, app.net);
            refreshFeederView(app);
            refreshDashboard(app);
            log(app, 'Households reassigned across zones/phases.');
        catch ME
            log(app, sprintf('Re-assignment failed: %s', ME.message));
        end
    end

    function onRunBfsSmoke(app)
        % ONRUNBFSSMOKE Run balanced BFS smoke test from UI values.
        try
            pVa = app.FeederSmokePkwEdit.Value * 1000;
            qVar = app.FeederSmokeQkvarEdit.Value * 1000;
            S_load = (pVa + 1j*qVar) * ones(3, app.net.n_buses);
            [V_bus, I_branch, I_neutral, ok] = bfs_power_flow(app.net, S_load, app.assignment);
            pq = compute_pq_indices(V_bus, I_branch, I_neutral, S_load, app.net, app.cfg);
            msg = {
                sprintf('Converged: %d', ok)
                sprintf('V_min: %.4f pu', pq.V_min_pu)
                sprintf('Max VUF: %.4f %%', max(pq.VUF_pct))
                sprintf('Max TL: %.2f %%', max(pq.TL_pct))
                sprintf('Losses: %.3f kW / %.3f kvar', pq.Ploss_kW, pq.Qloss_kvar)
            };
            app.FeederSmokeText.Value = msg;
            log(app, sprintf('BFS smoke test complete: Vmin=%.4f pu, VUF=%.3f%%', pq.V_min_pu, max(pq.VUF_pct)));
        catch ME
            app.FeederSmokeText.Value = {sprintf('BFS smoke test failed: %s', ME.message)};
            log(app, sprintf('BFS smoke test failed: %s', ME.message));
        end
    end

    function onSimulateSingleHousehold(app)
        % ONSIMULATESINGLEHOUSEHOLD Generate and plot one 24-hour profile.
        try
            h = round(app.LoadHouseholdSpinner.Value);
            steps = 24 * 60 / app.cfg.simulation.dt_min;
            cal_day = buildUiCalDay(app.LoadDayDropDown.Value);
            weather_day = app.LoadTempEdit.Value * ones(steps, 1);
            hh = simulate_household(h, app.assignment, app.data, weather_day, cal_day, app.cfg);
            app.SimState.last_household = hh;
            app_load_profile_plot(hh, app.cfg, app.LoadAxes);
            plotOccupancy(app, hh.occupancy, app.OccupancyAxes);
            evText = 'No EV';
            if isfield(hh, 'ev') && isfield(hh.ev, 'present') && hh.ev.present
                evText = sprintf('EV %s %.0fkWh | SOC %.0f%% -> %.0f%%', hh.ev.charger_type, hh.ev.battery_kwh, 100*hh.ev.soc_initial, 100*hh.ev.soc_target);
            end
            dailyKwh = sum(hh.p_total_w) * app.cfg.simulation.dt_hr / 1000;
            app.LoadInfoLabel.Text = sprintf('HH %d | Zone T%d | Phase %d | %.2f kWh/day | %s', h, hh.zone, hh.phase_id, dailyKwh, evText);
            log(app, sprintf('Simulated household %d: %.2f kWh/day.', h, dailyKwh));
        catch ME
            app.LoadInfoLabel.Text = sprintf('Simulation failed: %s', ME.message);
            log(app, sprintf('Household simulation failed: %s', ME.message));
        end
    end

    function plotOccupancy(app, occ, ax)
        % PLOTOCCUPANCY Plot occupancy state as a one-row heatmap.
        cla(ax);
        if isempty(occ)
            title(ax, 'Occupancy unavailable');
            return;
        end
        hours = (0:numel(occ)-1) * app.cfg.simulation.dt_min / 60;
        imagesc(ax, hours, 1, double(occ(:))');
        colormap(ax, parula(3));
        xlabel(ax, 'Hour');
        yticks(ax, 1);
        yticklabels(ax, {'State'});
        title(ax, 'Occupancy: 0 Away, 1 Awake, 2 Asleep');
        xlim(ax, [0 24]);
        style_app_axes(ax, app.Theme);
    end

    function onPopoutLastLoad(app)
        % ONPOPOUTLASTLOAD Show last single-household profile in figure.
        if isfield(app.SimState, 'last_household')
            app_popout_plot('load_profile', app.SimState.last_household, app.cfg);
        else
            log(app, 'Simulate a household before using Pop Out Load.');
        end
    end

    function onRunPopulation(app)
        % ONRUNPOPULATION Run population simulation with live progress.
        try
            cb = @(pct, msg) populationProgressCallback(app, pct, msg);
            app.pop = simulate_population(app.cfg, app.data, app.assignment, app.net, app.cal_struct, app.weather, cb);
            setLamp(app, 'population', true);
            refreshDashboard(app);
            updateLiveLoadAxes(app);
            log(app, 'Population simulation completed.');
        catch ME
            log(app, sprintf('Population simulation failed: %s', ME.message));
            app.PopulationProgressLabel.Text = sprintf('Progress: failed - %s', ME.message);
        end
    end

    function populationProgressCallback(app, pct, msg)
        % POPULATIONPROGRESSCALLBACK Update UI while simulate_population runs.
        app.PopulationProgressLabel.Text = sprintf('Progress: %d%% | %s', pct, msg);
        updateProgress(app, pct, msg);
        if mod(pct, 5) == 0
            updateLiveLoadAxes(app);
        end
        drawnow('limitrate');
    end

    function onReloadPopulationCache(app)
        % ONRELOADPOPULATIONCACHE Load cached population profile if available.
        try
            cacheFile = fullfile(app.cfg.output_dir, 'population_profiles.mat');
            if isfile(cacheFile)
                S = load(cacheFile, 'pop');
                app.pop = S.pop;
                setLamp(app, 'population', true);
                updateLiveLoadAxes(app);
                refreshDashboard(app);
                log(app, sprintf('Population cache loaded: %s', cacheFile));
            else
                log(app, sprintf('Population cache not found: %s', cacheFile));
            end
        catch ME
            log(app, sprintf('Population cache reload failed: %s', ME.message));
        end
    end

    function updateLiveLoadAxes(app)
        % UPDATELIVELOADAXES Plot mean load per transformer zone when pop exists.
        cla(app.LiveLoadAxes);
        if isempty(app.pop) || ~isfield(app.pop, 'L_house_w')
            bar(app.LiveLoadAxes, 1:5, zeros(1,5));
            title(app.LiveLoadAxes, 'Mean Load per Transformer Zone - no population cache');
            xlabel(app.LiveLoadAxes, 'Zone');
            ylabel(app.LiveLoadAxes, 'Mean Load [W]');
            style_app_axes(app.LiveLoadAxes, app.Theme);
            return;
        end
        zoneMeans = zeros(1, app.cfg.feeder.num_transformer_zones);
        for z = 1:numel(zoneMeans)
            idx = find(app.assignment.zone == z);
            if ~isempty(idx)
                zoneMeans(z) = mean(app.pop.L_house_w(:, idx), 'all', 'omitnan');
            end
        end
        bar(app.LiveLoadAxes, 1:numel(zoneMeans), zoneMeans);
        grid(app.LiveLoadAxes, 'on');
        xlabel(app.LiveLoadAxes, 'Transformer Zone');
        ylabel(app.LiveLoadAxes, 'Mean Load [W]');
        style_app_axes(app.LiveLoadAxes, app.Theme);
        title(app.LiveLoadAxes, 'Mean Load per Transformer Zone');
    end

    function onPlotTariffs(app)
        % ONPLOTTARIFFS Plot selected tariff curves.
        if isempty(app.cfg)
            return;
        end
        methods = {'Block','Flat','TOU','RTP','Seasonal','CPP','RGDP'};
        tvec = (0:(24*60/app.cfg.simulation.dt_min)-1)' * app.cfg.simulation.dt_min;
        hours = tvec / 60;
        cla(app.PricingAxes);
        hold(app.PricingAxes, 'on');
        plotted = false;
        for k = 1:numel(methods)
            if app.PricingMethodChecks(k).Value
                p = select_pricing(methods{k}, app.cfg, tvec, 250, []);
                if isstruct(p) && isfield(p, 'price_series')
                    y = p.price_series;
                else
                    y = p(:);
                end
                plot(app.PricingAxes, hours, y, 'LineWidth', 1.5, 'DisplayName', methods{k});
                plotted = true;
            end
        end
        if ~plotted
            title(app.PricingAxes, 'Select at least one tariff.');
        else
            grid(app.PricingAxes, 'on');
            xlabel(app.PricingAxes, 'Hour');
            ylabel(app.PricingAxes, 'EGP/kWh');
            title(app.PricingAxes, sprintf('24-hour Tariff Curves - %s', app.PricingDayDropDown.Value));
            legend(app.PricingAxes, 'Location', 'best');
            xlim(app.PricingAxes, [0 24]);
        end
        hold(app.PricingAxes, 'off');
        style_app_axes(app.PricingAxes, app.Theme);
    end

    function onCalculateBlockBill(app)
        % ONCALCULATEBLOCKBILL Calculate Egyptian block tariff bill and slab table.
        if isempty(app.cfg)
            return;
        end
        try
            kwh = app.BlockKwhEdit.Value;
            b = pricing_block(app.cfg, (0:95)'*15, kwh, 30);
            app.BlockBillText.Text = sprintf('Total: %.2f EGP/month | Slab %d | Effective %.3f EGP/kWh', b.bill_egp, b.slab_reached, b.effective_rate_egp_kwh);
            app.BlockSlabTable.Data = buildBlockSlabRows(app.cfg, kwh);
            log(app, sprintf('Block bill calculated: %.1f kWh -> %.2f EGP.', kwh, b.bill_egp));
        catch ME
            app.BlockBillText.Text = sprintf('Calculation failed: %s', ME.message);
            log(app, sprintf('Block tariff calculation failed: %s', ME.message));
        end
    end

    function refreshScenarioDetail(app)
        % REFRESHSCENARIODETAIL Update active scenario description text.
        if isempty(app.ScenarioRunDropDown)
            return;
        end
        sid = app.ScenarioRunDropDown.Value;
        app.ScenarioDetailText.Text = scenarioDescriptionText(sid);
        updateScenarioCardSelection(app, sid);
    end

    function onRunThisScenario(app)
        % ONRUNTHISSCENARIO Run the dropdown-selected scenario.
        onRunSelectedScenarios(app, app.ScenarioRunDropDown.Value);
    end

    function onRunCheckedScenarios(app)
        % ONRUNCHECKEDSCENARIOS Run scenarios whose cards are checked.
        ids = [-1 0 1 2 3 4 5 6];
        selected = false(size(ids));
        for k = 1:numel(ids)
            selected(k) = app.ScenarioSelectionChecks(k).Value;
        end
        if ~any(selected)
            logScenario(app, 'No scenario cards selected. Select at least one card.');
            return;
        end
        onRunSelectedScenarios(app, ids(selected));
    end

    function onRunSelectedScenarios(app, scenarioIds)
        % ONRUNSELECTEDSCENARIOS Sequential compiled-safe scenario execution.
        if isempty(app.cfg) || isempty(app.data) || isempty(app.net) || isempty(app.assignment)
            logScenario(app, 'Project is not initialized; cannot run scenarios.');
            return;
        end
        app.ScenarioStopRequested = false;
        switchView(app, 6);
        scenarioIds = scenarioIds(:)';
        logScenario(app, sprintf('Starting scenario batch: %s', mat2str(scenarioIds)));
        updateProgress(app, 0, 'scenario batch starting');

        try
            ensurePopulationReady(app);
        catch ME
            logScenario(app, sprintf('Population preparation failed: %s', ME.message));
            updateScenarioProgress(app, 0, sprintf('Failed before scenarios: %s', ME.message));
            return;
        end

        if isempty(app.all_results) || numel(app.all_results) < 8
            app.all_results = cell(8, 1);
        end

        for k = 1:numel(scenarioIds)
            sid = scenarioIds(k);
            if app.ScenarioStopRequested
                logScenario(app, 'Scenario batch stopped by user.');
                updateScenarioProgress(app, 0, 'stopped');
                break;
            end
            updateScenarioCardStatus(app, sid, 'running');
            updateScenarioProgress(app, 1, sprintf('Scenario %g starting...', sid));
            progressCb = @(pct, msg) scenarioProgressCallback(app, sid, pct, msg);
            try
                result = runScenarioById(app, sid, progressCb);
                app.all_results{scenarioResultIndex(sid)} = result;
                updateScenarioCardStatus(app, sid, 'complete');
                updateDashboardFromScenario(app, result);
                updateScenarioLivePlot(app, result);
                logScenario(app, sprintf('Scenario %g COMPLETE.', sid));
            catch ME
                updateScenarioCardStatus(app, sid, 'failed');
                logScenario(app, sprintf('ERROR Scenario %g: %s', sid, ME.message));
            end
            drawnow('limitrate');
        end

        app.all_results_ready = true;
        saveScenarioResults(app);
        refreshResultsView(app);
        updateProgress(app, 100, 'scenario batch done');
        updateStatus(app, 'Scenario execution finished', 'success');
    end

    function ensurePopulationReady(app)
        % ENSUREPOPULATIONREADY Load or simulate population before scenarios run.
        if ~isempty(app.pop) && isstruct(app.pop)
            return;
        end
        cacheFile = fullfile(app.cfg.output_dir, 'population_profiles.mat');
        if isfile(cacheFile)
            S = load(cacheFile, 'pop');
            app.pop = S.pop;
            setLamp(app, 'population', true);
            logScenario(app, sprintf('Loaded population cache: %s', cacheFile));
            return;
        end
        logScenario(app, 'Population cache not found. Running population simulation first.');
        cb = @(pct, msg) scenarioProgressCallback(app, NaN, pct, ['Population: ', msg]);
        app.pop = simulate_population(app.cfg, app.data, app.assignment, app.net, app.cal_struct, app.weather, cb);
        setLamp(app, 'population', true);
        refreshDashboard(app);
    end

    function result = runScenarioById(app, sid, progressCb)
        % RUNSCENARIOBYID Dispatch baseline or scenario function.
        if sid == -1
            result = run_baseline0(app.cfg, app.data, app.net, app.assignment, app.pop, app.cal_struct, app.weather, progressCb);
        else
            runFn = str2func(sprintf('run_scenario%d', sid));
            result = runFn(app.cfg, app.data, app.net, app.assignment, app.pop, app.cal_struct, app.weather, progressCb);
        end
    end

    function scenarioProgressCallback(app, sid, pct, msg)
        % SCENARIOPROGRESSCALLBACK Update progress bar, text log, and live plot.
        pct = max(0, min(100, round(pct)));
        if isnan(sid)
            label = sprintf('%d%% - %s', pct, msg);
        else
            label = sprintf('S%g: %d%% - %s', sid, pct, msg);
        end
        updateScenarioProgress(app, pct, label);
        logScenario(app, msg);
        drawnow('limitrate');
    end

    function updateScenarioProgress(app, pct, msg)
        % UPDATESCENARIOPROGRESS Update scenario progress label and status bar.
        if ~isempty(app.ScenarioProgressText) && isvalid(app.ScenarioProgressText)
            app.ScenarioProgressText.Text = sprintf('Progress: %d%% | %s', pct, msg);
        end
        updateProgress(app, pct, msg);
    end

    function updateScenarioCardStatus(app, sid, status)
        % UPDATESCENARIOCARDSTATUS Update a scenario card label and color.
        idx = scenarioResultIndex(sid);
        if isempty(app.ScenarioStatusLabels) || idx < 1 || idx > numel(app.ScenarioStatusLabels)
            return;
        end
        c = app.Theme.colors;
        label = app.ScenarioStatusLabels(idx);
        card = app.ScenarioCards(idx);
        switch lower(status)
            case 'running'
                label.Text = 'Running...'; label.FontColor = c.warning; card.BackgroundColor = 0.65*c.bg_card + 0.35*c.warning;
            case 'complete'
                label.Text = 'Complete'; label.FontColor = c.success; card.BackgroundColor = 0.75*c.bg_card + 0.25*c.success;
            case 'failed'
                label.Text = 'Failed'; label.FontColor = c.danger; card.BackgroundColor = 0.70*c.bg_card + 0.30*c.danger;
            otherwise
                label.Text = 'Not run'; label.FontColor = c.text_muted; card.BackgroundColor = c.bg_card;
        end
        drawnow('limitrate');
    end

    function updateScenarioCardSelection(app, sid)
        % UPDATESCENARIOCARDSELECTION Visually highlight the dropdown-selected scenario.
        if isempty(app.ScenarioCards)
            return;
        end
        c = app.Theme.colors;
        for k = 1:numel(app.ScenarioCards)
            app.ScenarioCards(k).BorderType = 'line';
            app.ScenarioCards(k).HighlightColor = c.bg_card;
        end
        idx = scenarioResultIndex(sid);
        if idx >= 1 && idx <= numel(app.ScenarioCards)
            app.ScenarioCards(idx).HighlightColor = c.accent;
        end
    end

    function onStopScenarios(app)
        % ONSTOPSCENARIOS Request stop between sequential scenario runs.
        app.ScenarioStopRequested = true;
        logScenario(app, 'Stop requested. Current scenario will finish, then the batch will stop.');
        updateScenarioProgress(app, 0, 'stop requested');
    end

    function onResetScenarios(app)
        % ONRESETSCENARIOS Reset card statuses and scenario log.
        app.ScenarioStopRequested = false;
        app.all_results = cell(8, 1);
        for sid = [-1 0 1 2 3 4 5 6]
            updateScenarioCardStatus(app, sid, 'notrun');
        end
        if ~isempty(app.ScenarioLog) && isvalid(app.ScenarioLog)
            app.ScenarioLog.Value = {'> Scenario log reset.'};
        end
        cla(app.ScenarioLiveAxes);
        title(app.ScenarioLiveAxes, 'Live / Last Scenario Three-Phase Feeder Load');
        updateScenarioProgress(app, 0, 'reset');
        saveUiState(app);
        log(app, 'Scenario view reset.');
    end

    function logScenario(app, msg)
        % LOGSCENARIO Append to scenario-specific log and global log.
        if ~isempty(app.ScenarioLog) && isvalid(app.ScenarioLog)
            app.ScenarioLog.Value = app_log(app.ScenarioLog.Value, msg, 200);
            try
                scroll(app.ScenarioLog, 'bottom');
            catch
            end
        end
        log(app, msg);
    end

    function updateScenarioLivePlot(app, result)
        % UPDATESCENARIOLIVEPLOT Plot retained lean feeder-load output.
        if isempty(app.ScenarioLiveAxes) || ~isvalid(app.ScenarioLiveAxes)
            return;
        end
        cla(app.ScenarioLiveAxes);
        try
            if isfield(result, 'slow') && isfield(result.slow, 'L_feeder_w')
                L = result.slow.L_feeder_w;
                plotTitle = 'Scenario 2 slow charger feeder load';
            elseif isfield(result, 'L_feeder_w')
                L = result.L_feeder_w;
                plotTitle = sprintf('Scenario %g feeder load', result.scenario_id);
            else
                title(app.ScenarioLiveAxes, 'No retained L_feeder_w in result.');
                return;
            end
            n = size(L, 1);
            stride = max(1, ceil(n / 1500));
            x = (1:stride:n)';
            y = L(x, :)/1000;
            plot(app.ScenarioLiveAxes, x, y, 'LineWidth', 1.1);
            grid(app.ScenarioLiveAxes, 'on');
            xlabel(app.ScenarioLiveAxes, 'Time step');
            ylabel(app.ScenarioLiveAxes, 'Power [kW]');
            legend(app.ScenarioLiveAxes, {'Phase A','Phase B','Phase C'}, 'Location', 'best');
            title(app.ScenarioLiveAxes, plotTitle);
            style_app_axes(app.ScenarioLiveAxes, app.Theme);
        catch ME
            title(app.ScenarioLiveAxes, sprintf('Live plot failed: %s', ME.message));
        end
    end

    function updateDashboardFromScenario(app, result)
        % UPDATEDASHBOARDFROMSCENARIO Copy latest scenario KPIs into dashboard tiles.
        try
            if isfield(result, 'slow')
                result = result.fast;
            end
            if isfield(result, 'pq_summary')
                app.DashboardKpiLabels(1).Text = sprintf('%.2f%%', result.pq_summary.max_vuf_pct);
                app.DashboardKpiLabels(2).Text = sprintf('%.3f pu', result.pq_summary.min_voltage_pu);
            end
            if isfield(result, 'hosting_capacity_pct')
                app.DashboardKpiLabels(3).Text = sprintf('%.0f%%', result.hosting_capacity_pct);
            end
            if isfield(result, 'comfort_summary') && isfield(result.comfort_summary, 'mean_ci')
                app.DashboardKpiLabels(4).Text = sprintf('CI %.2f', result.comfort_summary.mean_ci);
            end
            if isfield(result, 'scenario_id')
                app.DashboardKpiLabels(5).Text = sprintf('S%g', result.scenario_id);
            end
            if ~isempty(app.DashboardFeederAxes) && isvalid(app.DashboardFeederAxes)
                app_feeder_plot(app.net, app.assignment, app.DashboardFeederAxes);
            end
        catch ME
            logScenario(app, sprintf('Dashboard KPI update warning: %s', ME.message));
        end
    end

    function saveScenarioResults(app)
        % SAVESCENARIORESULTS Save current scenario cell array to results folder.
        try
            if isempty(app.cfg) || isempty(app.all_results)
                return;
            end
            if exist(app.cfg.output_dir, 'dir') ~= 7
                mkdir(app.cfg.output_dir);
            end
            all_results = app.all_results; %#ok<NASGU>
            outFile = fullfile(app.cfg.output_dir, 'scenario_results.mat');
            save(outFile, 'all_results', '-v7.3');
            saveUiState(app);
            logScenario(app, sprintf('Scenario results saved: %s', outFile));
        catch ME
            logScenario(app, sprintf('Could not save scenario_results.mat: %s', ME.message));
        end
    end

    function onPopoutScenarioPlot(app)
        % ONPOPOUTSCENARIOPLOT Pop out latest scenario comparison/live plot.
        if isempty(app.all_results)
            logScenario(app, 'No scenario results available to pop out.');
            return;
        end
        app_popout_plot('comparison', app.all_results, app.cfg);
    end


    function switchResultsSubView(app, subId)
        % SWITCHRESULTSSUBVIEW Show one Results sub-view.
        if isempty(app.ResultsSubPanels)
            return;
        end
        c = app.Theme.colors;
        for k = 1:numel(app.ResultsSubPanels)
            
            if k == subId
                app.ResultsSubPanels(k).Visible = 'on';
            else
                app.ResultsSubPanels(k).Visible = 'off';
            end
            if k <= numel(app.ResultsSubButtons)
                if k == subId
                    app.ResultsSubButtons(k).BackgroundColor = 0.65 * c.bg_panel + 0.35 * c.accent;
                else
                    app.ResultsSubButtons(k).BackgroundColor = c.bg_panel;
                end
            end
        end
        refreshResultsView(app);
    end

    function refreshResultsView(app)
        % REFRESHRESULTSVIEW Refresh all Step 13 result sub-views from lean results.
        if isempty(app.ResultsSubPanels) || isempty(app.cfg)
            return;
        end
        try
            [results, labels, ids] = getUiResults(app);
            updateResultsScenarioDropDown(app, labels, ids);
            refreshPqDashboard(app, results, labels, ids);
            refreshComparisonResults(app, results, labels);
            refreshHostingResults(app, results, labels);
            refreshCostResults(app, results, labels);
            refreshUqPreview(app, results, labels);
            styleAllAxes(app);
        catch ME
            log(app, sprintf('Results refresh warning: %s', ME.message));
        end
    end

    function [results, labels, ids] = getUiResults(app)
        % GETUIRESULTS Return available in-memory results and labels.
        idsAll = [-1 0 1 2 3 4 5 6];
        labelsAll = {'Baseline 0','Scenario 0','Scenario 1','Scenario 2','Scenario 3','Scenario 4','Scenario 5','Scenario 6'};
        results = {};
        labels = {};
        ids = [];
        if isempty(app.all_results)
            matFile = fullfile(app.cfg.output_dir, 'scenario_results.mat');
            if isfile(matFile)
                try
                    S = load(matFile, 'all_results');
                    if isfield(S, 'all_results')
                        app.all_results = S.all_results;
                    end
                catch
                end
            end
        end
        if isempty(app.all_results)
            return;
        end
        for k = 1:min(numel(app.all_results), numel(idsAll))
            r = app.all_results{k};
            if isempty(r)
                continue;
            end
            results{end+1} = r; %#ok<AGROW>
            if isstruct(r) && isfield(r, 'description') && ~isempty(r.description)
                labels{end+1} = shortScenarioLabel(r.description, labelsAll{k}); %#ok<AGROW>
            else
                labels{end+1} = labelsAll{k}; %#ok<AGROW>
            end
            ids(end+1) = idsAll(k); %#ok<AGROW>
        end
    end

    function updateResultsScenarioDropDown(app, labels, ids)
        % UPDATERESULTSSCENARIODROPDOWN Sync scenario dropdown choices.
        if isempty(app.ResultsPqScenarioDropDown) || ~isvalid(app.ResultsPqScenarioDropDown)
            return;
        end
        if isempty(labels)
            app.ResultsPqScenarioDropDown.Items = {'No results yet'};
            app.ResultsPqScenarioDropDown.ItemsData = 0;
            app.ResultsPqScenarioDropDown.Value = 0;
            return;
        end
        current = app.ResultsPqScenarioDropDown.Value;
        app.ResultsPqScenarioDropDown.Items = labels;
        app.ResultsPqScenarioDropDown.ItemsData = ids;
        if any(ids == current)
            app.ResultsPqScenarioDropDown.Value = current;
        else
            app.ResultsPqScenarioDropDown.Value = ids(end);
        end
    end

    function r = selectedResultsScenario(app, results, ids)
        % SELECTEDRESULTSSCENARIO Return currently selected PQ dashboard result.
        r = [];
        if isempty(results)
            return;
        end
        sid = app.ResultsPqScenarioDropDown.Value;
        idx = find(ids == sid, 1, 'first');
        if isempty(idx)
            idx = numel(results);
        end
        r = results{idx};
    end

    function refreshPqDashboard(app, results, labels, ids)
        % REFRESHPQDASHBOARD Update PQ summary and preview plots.
        %#ok<INUSD>
        r = selectedResultsScenario(app, results, ids);
        cla(app.ResultsPqAxes); cla(app.ResultsVoltageAxes);
        if isempty(r)
            app.ResultsPqTextArea.Value = {'No scenario results available yet.'; 'Run scenarios from the Scenarios view first.'};
            return;
        end
        meanVuf = resultMetric(r, 'mean_vuf_pct');
        maxVuf = resultMetric(r, 'max_vuf_pct');
        vmin = resultMetric(r, 'min_voltage_pu');
        maxTl = resultMetric(r, 'max_loading_pct');
        losses = resultMetric(r, 'total_losses_kw');
        thdi = resultMetric(r, 'max_thdi_pct');
        thdv = resultMetric(r, 'max_thdv_pct');
        ci = resultMetric(r, 'mean_ci');
        host = resultMetric(r, 'hosting_capacity_pct');
        app.ResultsPqTextArea.Value = {
            sprintf('Mean VUF      : %.3f %%', meanVuf)
            sprintf('Peak VUF      : %.3f %%', maxVuf)
            sprintf('Minimum V     : %.3f pu', vmin)
            sprintf('Max loading   : %.2f %%', maxTl)
            sprintf('THDi / THDv   : %.2f %% / %.2f %%', thdi, thdv)
            sprintf('Losses        : %.3f kW', losses)
            sprintf('Hosting / CI  : %.1f %% / %.3f', host, ci)
            };
        vals = [meanVuf, maxVuf, maxTl, thdi, thdv, losses];
        labelsK = categorical({'Mean VUF','Peak VUF','Max TL','THDi','THDv','Losses'});
        bar(app.ResultsPqAxes, labelsK, vals);
        ylabel(app.ResultsPqAxes, 'Value');
        grid(app.ResultsPqAxes, 'on');
        yline(app.ResultsPqAxes, app.cfg.pq_limits.vuf_max_pct, '--', 'VUF limit');

        if isstruct(r) && isfield(r, 'L_feeder_w') && ~isempty(r.L_feeder_w)
            L = r.L_feeder_w;
            n = min(size(L,1), 96);
            plot(app.ResultsVoltageAxes, (1:n), L(1:n,:) / 1000, 'LineWidth', 1.2);
            xlabel(app.ResultsVoltageAxes, 'Step'); ylabel(app.ResultsVoltageAxes, 'Phase power [kW]');
            legend(app.ResultsVoltageAxes, {'A','B','C'}, 'Location', 'best');
            title(app.ResultsVoltageAxes, 'First-day retained three-phase feeder load');
            grid(app.ResultsVoltageAxes, 'on');
        else
            busNames = string(app.net.bus_names(:));
            vVals = vmin * ones(numel(busNames), 1);
            bar(app.ResultsVoltageAxes, categorical(busNames), vVals);
            ylabel(app.ResultsVoltageAxes, 'Voltage [pu]');
            title(app.ResultsVoltageAxes, 'Voltage summary fallback');
            yline(app.ResultsVoltageAxes, app.cfg.pq_limits.voltage_min_pu, '--', 'Vmin limit');
        end
    end

    function refreshComparisonResults(app, results, labels)
        % REFRESHCOMPARISONRESULTS Update scenario comparison chart/table.
        cla(app.ResultsCompareAxes);
        if isempty(results)
            app.ResultsCompareTable.Data = cell(0,8);
            return;
        end
        rows = buildResultsMetricRows(results, labels);
        app.ResultsCompareTable.Data = rows;
        metric = app.ResultsCompareMetricDropDown.Value;
        colMap = containers.Map({'Mean VUF %','Peak VUF %','Vmin pu','Max TL %','Hosting %','Comfort CI','Block Cost EGP'}, 2:8);
        col = colMap(metric);
        y = cell2mat(rows(:, col));
        x = categorical(rows(:,1));
        bar(app.ResultsCompareAxes, x, y);
        ylabel(app.ResultsCompareAxes, metric);
        title(app.ResultsCompareAxes, ['Scenario comparison - ', metric]);
        grid(app.ResultsCompareAxes, 'on');
        if contains(metric, 'VUF')
            yline(app.ResultsCompareAxes, app.cfg.pq_limits.vuf_max_pct, '--', 'VUF limit');
        elseif contains(metric, 'Vmin')
            yline(app.ResultsCompareAxes, app.cfg.pq_limits.voltage_min_pu, '--', 'Vmin limit');
        elseif contains(metric, 'TL')
            yline(app.ResultsCompareAxes, app.cfg.pq_limits.transformer_loading_max_pct, '--', 'TL limit');
        end
    end

    function refreshHostingResults(app, results, labels)
        % REFRESHHOSTINGRESULTS Update hosting chart/table.
        cla(app.ResultsHostingAxes);
        if isempty(results)
            app.ResultsHostingTable.Data = cell(0,6);
            return;
        end
        rows = cell(numel(results), 6);
        hold(app.ResultsHostingAxes, 'on');
        pen = 0:5:50;
        for k = 1:numel(results)
            r = results{k};
            host = resultMetric(r, 'hosting_capacity_pct');
            meanVuf = resultMetric(r, 'mean_vuf_pct');
            vmin = resultMetric(r, 'min_voltage_pu');
            maxTl = resultMetric(r, 'max_loading_pct');
            if isnan(host), host = NaN; end
            rows{k,1} = labels{k};
            rows{k,2} = host;
            rows{k,3} = inferBindingConstraint(meanVuf, vmin, maxTl, app.cfg);
            rows{k,4} = meanVuf;
            rows{k,5} = vmin;
            rows{k,6} = maxTl;
            if ~isnan(host)
                y = meanVuf + max(0, (pen - host)) * 0.035;
                plot(app.ResultsHostingAxes, pen, y, 'LineWidth', 1.2, 'DisplayName', labels{k});
            end
        end
        hold(app.ResultsHostingAxes, 'off');
        yline(app.ResultsHostingAxes, app.cfg.pq_limits.vuf_max_pct, '--', 'VUF limit');
        xlabel(app.ResultsHostingAxes, 'EV penetration [%]');
        ylabel(app.ResultsHostingAxes, 'Estimated VUF [%]');
        title(app.ResultsHostingAxes, 'Hosting capacity planning preview');
        grid(app.ResultsHostingAxes, 'on');
        legend(app.ResultsHostingAxes, 'Location', 'bestoutside');
        app.ResultsHostingTable.Data = rows;
    end

    function refreshCostResults(app, results, labels)
        % REFRESHCOSTRESULTS Update cost chart/table.
        cla(app.ResultsCostAxes);
        if isempty(results)
            app.ResultsCostTable.Data = cell(0,6);
            return;
        end
        tariff = app.ResultsCostTariffDropDown.Value;
        rows = cell(numel(results), 6);
        y = nan(numel(results), 1);
        for k = 1:numel(results)
            r = results{k};
            bills = resultBills(r, tariff);
            inc = resultEvIncrement(r);
            rows{k,1} = labels{k};
            rows{k,2} = tariff;
            rows{k,3} = mean(bills, 'omitnan');
            rows{k,4} = min(bills, [], 'omitnan');
            rows{k,5} = max(bills, [], 'omitnan');
            rows{k,6} = inc;
            y(k) = rows{k,3};
        end
        bar(app.ResultsCostAxes, categorical(labels), y);
        ylabel(app.ResultsCostAxes, 'Mean bill [EGP]');
        title(app.ResultsCostAxes, ['Scenario cost - ', tariff]);
        grid(app.ResultsCostAxes, 'on');
        app.ResultsCostTable.Data = rows;
    end

    function onReloadResultsTwin(app)
        % ONRELOADRESULTSTWIN Create/reload one HouseholdTwin and plot it.
        cla(app.ResultsTwinAxes);
        try
            ensurePopulationReady(app);
        catch
        end
        hIdx = round(app.ResultsTwinHouseholdSpinner.Value);
        dayText = app.ResultsTwinDayDropDown.Value;
        calDay = buildUiCalDay(dayText);
        weatherDay = app.ResultsTwinDayWeather(dayText);
        twin = HouseholdTwin(hIdx, app.assignment, app.data, app.cfg);
        twin.generateDayProfile(calDay, weatherDay);
        app.SimState.results_twin = twin;
        projection = twin.getProjectedLoad(96);
        profile = projection.power_w(:);
        plot(app.ResultsTwinAxes, (0:numel(profile)-1) * app.cfg.simulation.dt_hr, profile, 'LineWidth', 1.3);
        xlabel(app.ResultsTwinAxes, 'Hour'); ylabel(app.ResultsTwinAxes, 'Power [W]');
        title(app.ResultsTwinAxes, sprintf('Household %d projected load', hIdx));
        grid(app.ResultsTwinAxes, 'on');
        windows = twin.getFlexibilityWindows();
        [rows, names] = twinFlexRows(windows, app.cfg);
        app.ResultsTwinFlexTable.Data = rows;
        if isempty(names)
            app.ResultsTwinCommandApplianceDropDown.Items = {'No controllable load'};
            app.ResultsTwinCommandApplianceDropDown.Value = 'No controllable load';
        else
            app.ResultsTwinCommandApplianceDropDown.Items = names;
            app.ResultsTwinCommandApplianceDropDown.Value = names{1};
            try
                app.ResultsTwinCommandStartEdit.Value = max(1, round(windows.preferred_start_step(1)));
            catch
            end
        end
        ev = twin.getEVStatus();
        app.ResultsTwinStatusText.Value = {
            sprintf('Household %d | Phase %d | Zone %d', hIdx, twin.phase_id, twin.zone)
            sprintf('Flexibility windows: %d', size(rows,1))
            sprintf('EV present field: %d | current measurement bias: %.2f W', isfield(ev, 'present'), twin.current_state.measurement_bias_w)
            'Use Send Command to test the smart-meter-to-twin DSM API.'
            };
    end

    function weatherDay = ResultsTwinDayWeather(app, dayText)
        % RESULTSTWINDAYWEATHER Build 96-step weather vector for twin preview.
        steps = 24 * 60 / app.cfg.simulation.dt_min;
        if contains(dayText, 'Winter', 'IgnoreCase', true)
            base = 14;
        else
            base = 40;
        end
        weatherDay = base + 4 * sin((0:steps-1)' / steps * 2*pi - pi/3);
    end

    function onSendTwinCommand(app)
        % ONSENDTWINCOMMAND Send DSM command to the current twin.
        if ~isfield(app.SimState, 'results_twin') || isempty(app.SimState.results_twin)
            onReloadResultsTwin(app);
        end
        twin = app.SimState.results_twin;
        cmd.appliance = app.ResultsTwinCommandApplianceDropDown.Value;
        cmd.new_start = round(app.ResultsTwinCommandStartEdit.Value);
        try
            [accepted, newCi, reason] = twin.acceptDSMCommand(cmd);
            status = 'Rejected';
            if accepted, status = 'Accepted'; end
            old = app.ResultsTwinStatusText.Value;
            app.ResultsTwinStatusText.Value = [old; {sprintf('%s command: %s | CI=%.3f', status, reason, newCi)}];
        catch ME
            app.ResultsTwinStatusText.Value = [app.ResultsTwinStatusText.Value; {sprintf('Command failed: %s', ME.message)}];
        end
    end

    function onPreviewUq(app)
        % ONPREVIEWUQ Draw lightweight UQ preview from existing scenario results.
        [results, labels, ids] = getUiResults(app);
        cla(app.ResultsUqAxes);
        if isempty(results)
            app.ResultsUqTable.Data = cell(0,6);
            return;
        end
        refreshUqPreview(app, results, labels);
    end

    function refreshUqPreview(app, results, labels)
        % REFRESHUQPREVIEW Build a lightweight KPI distribution preview.
        if isempty(app.ResultsUqAxes) || ~isvalid(app.ResultsUqAxes)
            return;
        end
        cla(app.ResultsUqAxes);
        if isempty(results)
            app.ResultsUqTable.Data = cell(0,6);
            return;
        end
        metrics = {'mean_vuf_pct','max_vuf_pct','min_voltage_pu','max_loading_pct','hosting_capacity_pct','mean_ci'};
        names = {'Mean VUF','Peak VUF','Vmin','Max TL','Hosting','CI'};
        vals = nan(numel(results), numel(metrics));
        for r = 1:numel(results)
            for k = 1:numel(metrics)
                vals(r,k) = resultMetric(results{r}, metrics{k});
            end
        end
        mu = mean(vals, 1, 'omitnan');
        sigma = std(vals, 0, 1, 'omitnan');
        x = 1:numel(names);
        bar(app.ResultsUqAxes, x, mu);
        hold(app.ResultsUqAxes, 'on');
        errorbar(app.ResultsUqAxes, x, mu, sigma, 'LineStyle', 'none');
        hold(app.ResultsUqAxes, 'off');
        app.ResultsUqAxes.XTick = x;
        app.ResultsUqAxes.XTickLabel = names;
        title(app.ResultsUqAxes, sprintf('Existing-result KPI spread (%d scenarios)', numel(results)));
        grid(app.ResultsUqAxes, 'on');
        rows = cell(numel(metrics), 6);
        for k = 1:numel(metrics)
            x = vals(:,k);
            rows{k,1} = names{k};
            rows{k,2} = mean(x, 'omitnan');
            rows{k,3} = std(x, 0, 'omitnan');
            rows{k,4} = prctile(x, 5);
            rows{k,5} = prctile(x, 50);
            rows{k,6} = prctile(x, 95);
        end
        app.ResultsUqTable.Data = rows;
    end

    function onPopoutResults(app, plotType)
        % ONPOPOUTRESULTS Open a standalone figure for the selected result view.
        [results, labels, ids] = getUiResults(app);
        if isempty(results)
            log(app, 'No results available to pop out. Run scenarios first.');
            return;
        end
        fig = figure('Name', ['Results - ', plotType], 'Color', 'w', 'NumberTitle', 'off');
        ax = axes(fig);
        switch lower(plotType)
            case 'comparison'
                rows = buildResultsMetricRows(results, labels);
                vals = cell2mat(rows(:,2));
                bar(ax, categorical(labels), vals); ylabel(ax, 'Mean VUF [%]'); grid(ax, 'on');
            case 'hosting'
                caps = cellfun(@(r) resultMetric(r, 'hosting_capacity_pct'), results);
                bar(ax, categorical(labels), caps); ylabel(ax, 'Hosting capacity [%]'); grid(ax, 'on');
            case 'cost'
                vals = cellfun(@(r) mean(resultBills(r, app.ResultsCostTariffDropDown.Value), 'omitnan'), results);
                bar(ax, categorical(labels), vals); ylabel(ax, 'Mean bill [EGP]'); grid(ax, 'on');
            otherwise
                r = selectedResultsScenario(app, results, ids);
                vals = [resultMetric(r,'mean_vuf_pct'), resultMetric(r,'max_vuf_pct'), resultMetric(r,'max_loading_pct')];
                bar(ax, categorical({'Mean VUF','Peak VUF','Max TL'}), vals); grid(ax, 'on');
        end
    end

    function refreshExportView(app)
        % REFRESHEXPORTVIEW Update dynamic export folder and status.
        try
            if ~isempty(app.cfg) && isfield(app.cfg, 'output_dir')
                app.ExportFolderEdit.Value = app.cfg.output_dir;
            elseif ~isempty(app.ExportFolderEdit)
                app.ExportFolderEdit.Value = fullfile(get_root_dir(), 'results');
            end
        catch
        end
    end

    function onBrowseExportFolder(app)
        % ONBROWSEEXPORTFOLDER Let the user choose the export root folder.
        try
            startDir = app.ExportFolderEdit.Value;
            if isempty(startDir) || exist(startDir, 'dir') ~= 7
                startDir = app.cfg.output_dir;
            end
            chosen = uigetdir(startDir, 'Choose EV DSM export folder');
            if isequal(chosen, 0), return; end
            app.ExportFolderEdit.Value = chosen;
            app.cfg.output_dir = chosen;
            app.cfg.figs_dir = fullfile(chosen, 'figures');
            app.cfg.tables_dir = fullfile(chosen, 'tables');
            ensureUiExportDirs(app);
            log(app, sprintf('Export folder changed: %s', chosen));
        catch ME
            log(app, sprintf('Export folder browse failed: %s', ME.message));
        end
    end

    function onExportSelectedFigures(app)
        % ONEXPORTSELECTEDFIGURES Export checked figures in checked formats.
        try
            [results, ~, ~] = getUiResults(app);
            if isempty(results)
                app.ExportStatusText.Value = {'No scenario results found. Run scenarios first.'};
                log(app, 'Figure export skipped: no results available.');
                return;
            end
            opts = buildExportOptions(app);
            opts.selected_figures = getSelectedExportFigures(app, false);
            opts.formats = getSelectedExportFormats(app);
            out = app_export_helper('figures_selected', results, app.cfg, opts);
            app.SimState.last_export.figure_paths = out.figure_paths;
            app.ExportStatusText.Value = exportPathLines('Exported figures', out.figure_paths);
            log(app, sprintf('Exported %d figure files.', out.count));
        catch ME
            app.ExportStatusText.Value = {sprintf('Figure export failed: %s', ME.message)};
            log(app, sprintf('Figure export failed: %s', ME.message));
        end
    end

    function onExportAllFigures(app)
        % ONEXPORTALLFIGURES Export all known thesis figures.
        try
            [results, ~, ~] = getUiResults(app);
            if isempty(results)
                app.ExportStatusText.Value = {'No scenario results found. Run scenarios first.'};
                return;
            end
            opts = buildExportOptions(app);
            opts.selected_figures = getSelectedExportFigures(app, true);
            opts.formats = getSelectedExportFormats(app);
            out = app_export_helper('figures_selected', results, app.cfg, opts);
            app.SimState.last_export.figure_paths = out.figure_paths;
            app.ExportStatusText.Value = exportPathLines('Exported all figures', out.figure_paths);
            log(app, sprintf('Exported all figures: %d files.', out.count));
        catch ME
            app.ExportStatusText.Value = {sprintf('Export all figures failed: %s', ME.message)};
            log(app, sprintf('Export all figures failed: %s', ME.message));
        end
    end

    function onExportSelectedCsv(app)
        % ONEXPORTSELECTEDCSV Export selected scenario CSV tables.
        try
            [results, ~, ~] = getUiResults(app);
            if isempty(results)
                app.ExportStatusText.Value = {'No scenario results found. Run scenarios first.'};
                return;
            end
            opts = buildExportOptions(app);
            opts.selected_tables = getSelectedExportTables(app);
            out = app_export_helper('tables_selected', results, app.cfg, opts);
            app.SimState.last_export.table_paths = out.table_paths;
            app.ExportStatusText.Value = exportPathLines('Exported CSV tables', out.table_paths);
            log(app, sprintf('Exported %d CSV table files.', out.count));
        catch ME
            app.ExportStatusText.Value = {sprintf('CSV export failed: %s', ME.message)};
            log(app, sprintf('CSV export failed: %s', ME.message));
        end
    end

    function onGeneratePdfReport(app)
        % ONGENERATEPDFREPORT Generate a full scenario PDF report.
        try
            [results, ~, ~] = getUiResults(app);
            if isempty(results)
                app.ExportLatexStatusText.Value = {'No scenario results found. Run scenarios first before generating PDF.'};
                log(app, 'PDF report skipped: no scenario results available.');
                return;
            end
            opts = buildExportOptions(app);
            opts.name = 'ev_dsm_full_scenario_report';
            opts.author = app.ExportAuthorEdit.Value;
            opts.report_date = app.ExportDateEdit.Value;
            opts.selected_figures = getSelectedExportFigures(app, true);
            opts.formats = {'pdf'};
            outFile = app_export_helper('pdf_report', results, app.cfg, opts);
            if ~isfield(app.SimState, 'last_export') || ~isstruct(app.SimState.last_export)
                app.SimState.last_export = struct();
            end
            app.SimState.last_export.pdf_report = outFile;
            app.ExportLatexStatusText.Value = {'Generated PDF report:', outFile, ...
                'Contents: used configuration, scenario KPI tables, cost summary, and thesis plots.'};
            log(app, sprintf('Generated PDF report: %s', outFile));
        catch ME
            app.ExportLatexStatusText.Value = {sprintf('PDF report failed: %s', ME.message)};
            log(app, sprintf('PDF report failed: %s', ME.message));
        end
    end

    function onGenerateLatexReport(app)
        % ONGENERATELATEXREPORT Generate LaTeX include file from latest exports.
        try
            exports = struct();
            if isfield(app.SimState, 'last_export')
                exports = app.SimState.last_export;
            end
            opts = buildExportOptions(app);
            opts.name = 'thesis_results_report';
            opts.author = app.ExportAuthorEdit.Value;
            opts.report_date = app.ExportDateEdit.Value;
            outFile = app_export_helper('latex_report', exports, app.cfg, opts);
            app.ExportLatexStatusText.Value = {sprintf('Generated: %s', outFile), 'Compile with pdflatex after copying into the thesis folder.'};
            log(app, sprintf('Generated LaTeX report: %s', outFile));
        catch ME
            app.ExportLatexStatusText.Value = {sprintf('LaTeX report failed: %s', ME.message)};
            log(app, sprintf('LaTeX report failed: %s', ME.message));
        end
    end

    function opts = buildExportOptions(app)
        % BUILDEXPORTOPTIONS Collect export options from UI controls.
        ensureUiExportDirs(app);
        opts = struct();
        opts.output_dir = app.ExportFolderEdit.Value;
        opts.figures_dir = fullfile(opts.output_dir, 'figures');
        opts.tables_dir = fullfile(opts.output_dir, 'tables');
        opts.dpi = 300;
        opts.size = app.ExportSizeDropDown.Value;
    end

    function ensureUiExportDirs(app)
        % ENSUREUIEXPORTDIRS Ensure output/figures/tables directories exist.
        if isempty(app.cfg) || ~isfield(app.cfg, 'output_dir')
            app.cfg.output_dir = fullfile(get_root_dir(), 'results');
        end
        if isempty(app.ExportFolderEdit.Value)
            app.ExportFolderEdit.Value = app.cfg.output_dir;
        end
        app.cfg.output_dir = app.ExportFolderEdit.Value;
        app.cfg.figs_dir = fullfile(app.cfg.output_dir, 'figures');
        app.cfg.tables_dir = fullfile(app.cfg.output_dir, 'tables');
        dirs = {app.cfg.output_dir, app.cfg.figs_dir, app.cfg.tables_dir, ...
            fullfile(app.cfg.figs_dir, 'png'), fullfile(app.cfg.figs_dir, 'eps'), fullfile(app.cfg.figs_dir, 'svg')};
        for k = 1:numel(dirs)
            if exist(dirs{k}, 'dir') ~= 7, mkdir(dirs{k}); end
        end
    end

    function keys = getSelectedExportFigures(app, includeAll)
        % GETSELECTEDEXPORTFIGURES Return checked/all figure export keys.
        keys = {};
        for k = 1:numel(app.ExportFigureChecks)
            if includeAll || app.ExportFigureChecks(k).Value
                keys{end+1} = app.ExportFigureChecks(k).UserData; %#ok<AGROW>
            end
        end
        if isempty(keys), keys = {'vuf_comparison'}; end
    end

    function fmts = getSelectedExportFormats(app)
        % GETSELECTEDEXPORTFORMATS Return checked figure formats.
        fmts = {};
        if app.ExportFormatPngCheck.Value, fmts{end+1} = 'png'; end %#ok<AGROW>
        if app.ExportFormatEpsCheck.Value, fmts{end+1} = 'eps'; end %#ok<AGROW>
        if app.ExportFormatSvgCheck.Value, fmts{end+1} = 'svg'; end %#ok<AGROW>
        if isempty(fmts), fmts = {'png'}; end
    end

    function keys = getSelectedExportTables(app)
        % GETSELECTEDEXPORTTABLES Return checked table export keys.
        keys = {};
        for k = 1:numel(app.ExportCsvChecks)
            if app.ExportCsvChecks(k).Value
                keys{end+1} = app.ExportCsvChecks(k).UserData; %#ok<AGROW>
            end
        end
        if isempty(keys), keys = {'scenario_summary'}; end
    end

    function data = buildInitialTestTable(app)
        % BUILDINITIALTESTTABLE Return default Tests view table data.
        names = appDefaultTestNames();
        data = cell(numel(names), 6);
        for k = 1:numel(names)
            data{k,1} = true;
            data{k,2} = names{k};
            data{k,3} = 'Queued';
            data{k,4} = NaN;
            data{k,5} = 'Never';
            data{k,6} = 'Not run yet';
        end
    end

    function refreshTestsView(app)
        % REFRESHTESTSVIEW Ensure table is initialized and summary is current.
        if isempty(app.TestsTable) || ~isvalid(app.TestsTable)
            return;
        end
        if ~app.TestsStateLoaded
            app.TestsTable.Data = loadSavedTestTable(app);
            app.TestsStateLoaded = true;
        elseif isempty(app.TestsTable.Data)
            app.TestsTable.Data = buildInitialTestTable(app);
        end
        updateTestsSummary(app);
    end


    function data = loadSavedTestTable(app)
        % LOADSAVEDTESTTABLE Restore last saved UI test report when available.
        data = buildInitialTestTable(app);
        try
            if isempty(app.cfg) || ~isfield(app.cfg, 'tables_dir')
                return;
            end
            reportFile = fullfile(app.cfg.tables_dir, 'ui_test_report.csv');
            if ~isfile(reportFile)
                app.TestsDetailText.Value = {'No previous UI test report found.', sprintf('Expected: %s', reportFile)};
                return;
            end
            T = readtable(reportFile, 'TextType', 'string');
            hasNew = all(ismember({'Run','Test','Status','Time_s','LastRunAt','LastResult'}, T.Properties.VariableNames));
            hasOld = all(ismember({'Run','Test','Status','Time_s','LastResult'}, T.Properties.VariableNames));
            if hasNew || hasOld
                n = min(height(T), size(data,1));
                for k = 1:n
                    data{k,1} = logical(T.Run(k));
                    data{k,2} = char(T.Test(k));
                    data{k,3} = char(T.Status(k));
                    data{k,4} = T.Time_s(k);
                    if hasNew
                        data{k,5} = char(T.LastRunAt(k));
                        data{k,6} = char(T.LastResult(k));
                    else
                        data{k,5} = 'Imported old report';
                        data{k,6} = char(T.LastResult(k));
                    end
                end
                app.TestsDetailText.Value = { ...
                    sprintf('Restored previous test report: %s', reportFile), ...
                    sprintf('Last stored row timestamp: %s', data{max(1,n),5})};
                log(app, sprintf('Restored previous UI test report: %s', reportFile));
            end
        catch ME
            app.TestsDetailText.Value = {sprintf('Could not restore previous test report: %s', ME.message)};
        end
    end

    function onRunAllUiTests(app)
        % ONRUNALLUITESTS Mark all rows selected and run them.
        data = app.TestsTable.Data;
        for k = 1:size(data, 1)
            data{k, 1} = true;
        end
        app.TestsTable.Data = data;
        runUiTests(app, true);
    end

    function onRunSelectedUiTests(app)
        % ONRUNSELECTEDUITESTS Run only checked tests.
        runUiTests(app, false);
    end

    function runUiTests(app, includeAll)
        % RENUITESTS Sequential, compiled-safe UI test runner.
        if nargin < 2, includeAll = false; end
        data = app.TestsTable.Data;
        if isempty(data)
            data = buildInitialTestTable(app);
        end
        total = size(data, 1);
        selected = false(total, 1);
        for k = 1:total
            selected(k) = includeAll || logical(data{k, 1});
        end
        nSelected = sum(selected);
        if nSelected == 0
            app.TestsDetailText.Value = {'No tests selected.'};
            updateStatus(app, 'No tests selected', 'warning');
            return;
        end

        app.TestsRunAllButton.Enable = 'off';
        app.TestsRunSelectedButton.Enable = 'off';
        cleanupObj = onCleanup(@() restoreTestButtons(app));
        updateStatus(app, 'Running UI tests...', 'warning');
        log(app, sprintf('Tests view: running %d selected test(s).', nSelected));

        done = 0;
        for k = 1:total
            if ~selected(k), continue; end
            testName = data{k, 2};
            data{k, 3} = 'Running';
            data{k, 5} = datestr(now, 31);
            data{k, 6} = 'Executing...';
            app.TestsTable.Data = data;
            updateUiTestProgress(app, done, nSelected, sprintf('Running %s', testName));
            drawnow('limitrate');

            result = app_test_runner(testName);
            done = done + 1;
            data{k, 3} = result.status;
            data{k, 4} = result.time_s;
            data{k, 5} = datestr(now, 31);
            data{k, 6} = result.message;
            app.TestsTable.Data = data;
            app.TestsDetailText.Value = result.detail(:);
            log(app, sprintf('Test %s: %s (%.2fs)', testName, result.status, result.time_s));
            updateUiTestProgress(app, done, nSelected, sprintf('Completed %s', testName));
            drawnow('limitrate');
        end

        updateTestsSummary(app);
        onSaveUiTestReport(app);
        updateStatus(app, 'Tests complete', 'success');
    end

    function restoreTestButtons(app)
        % RESTORETESTBUTTONS Re-enable test buttons after execution/errors.
        if ~isempty(app.TestsRunAllButton) && isvalid(app.TestsRunAllButton)
            app.TestsRunAllButton.Enable = 'on';
        end
        if ~isempty(app.TestsRunSelectedButton) && isvalid(app.TestsRunSelectedButton)
            app.TestsRunSelectedButton.Enable = 'on';
        end
    end

    function updateUiTestProgress(app, done, total, msg)
        % UPDATEUITESTPROGRESS Update Tests view and global progress labels.
        if total <= 0, pct = 0; else, pct = round(100 * done / total); end
        nBlocks = 20;
        nFill = round(nBlocks * pct / 100);
        app.TestsProgressLabel.Text = ['[', repmat('#', 1, nFill), repmat('-', 1, nBlocks - nFill), sprintf('] %3d%%', pct)];
        app.TestsSummaryLabel.Text = sprintf('%d/%d completed — %s', done, total, msg);
        updateProgress(app, pct, msg);
    end

    function updateTestsSummary(app)
        % UPDATETESTSSUMMARY Update PASS/FAIL/PENDING summary labels.
        if isempty(app.TestsTable) || ~isvalid(app.TestsTable), return; end
        data = app.TestsTable.Data;
        if isempty(data), return; end
        statuses = string(data(:,3));
        passCount = sum(statuses == "PASS");
        failCount = sum(statuses == "FAIL");
        runCount = sum(statuses == "PASS" | statuses == "FAIL");
        total = numel(statuses);
        app.TestsSummaryLabel.Text = sprintf('%d/%d run | PASS=%d | FAIL=%d | Pending=%d', ...
            runCount, total, passCount, failCount, total - runCount);
    end

    function onClearUiTests(app)
        % ONCLEARUITESTS Reset table and details.
        app.TestsTable.Data = buildInitialTestTable(app);
        app.TestsDetailText.Value = {'Test results cleared.'};
        updateTestsSummary(app);
        updateUiTestProgress(app, 0, 1, 'cleared');
        log(app, 'Tests view cleared.');
    end

    function onSaveUiTestReport(app)
        % ONSAVEUITESTREPORT Write Tests view table to CSV in results/tables.
        try
            if isempty(app.cfg) || ~isfield(app.cfg, 'tables_dir')
                app.cfg = config_loader([]);
            end
            if exist(app.cfg.tables_dir, 'dir') ~= 7, mkdir(app.cfg.tables_dir); end
            data = app.TestsTable.Data;
            if size(data, 2) < 6
                data(:,6) = data(:,5);
                data(:,5) = {'Unknown'};
            end
            T = cell2table(data, 'VariableNames', {'Run','Test','Status','Time_s','LastRunAt','LastResult'});
            outFile = fullfile(app.cfg.tables_dir, 'ui_test_report.csv');
            writetable(T, outFile);
            app.TestsDetailText.Value = {sprintf('Saved test report: %s', outFile)};
            log(app, sprintf('Saved UI test report: %s', outFile));
        catch ME
            app.TestsDetailText.Value = {sprintf('Failed to save test report: %s', ME.message)};
            log(app, sprintf('Failed to save test report: %s', ME.message));
        end
    end

    function onTestTableSelection(app, event)
        % ONTESTTABLESELECTION Show selected test details.
        try
            if isempty(event.Indices), return; end
            row = event.Indices(1);
            data = app.TestsTable.Data;
            if row < 1 || row > size(data, 1), return; end
            app.TestsDetailText.Value = { ...
                sprintf('Test: %s', data{row,2}), ...
                sprintf('Status: %s', data{row,3}), ...
                sprintf('Time_s: %.3g', data{row,4}), ...
                sprintf('Last run: %s', data{row,5}), ...
                sprintf('Last result: %s', data{row,6})};
        catch
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
        if viewId == 7
            refreshResultsView(app);
        elseif viewId == 8
            refreshExportView(app);
        elseif viewId == 9
            refreshTestsView(app);
        end
        styleAllAxes(app);
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
        app.LastStatusMessage = char(string(msg));
        app.LastStatusLevel = char(string(level));
        app.StatusBar.Text = sprintf('%s | View: %s | %s', datestr(now, 'HH:MM:SS'), app.Theme.nav.labels{app.active_view}, msg);
        app.StatusBar.FontColor = color;
        drawnow('limitrate');
    end

    function updateProgress(app, pct, msg)
        % UPDATEPROGRESS Update the status progress indicator.
        pct = max(0, min(100, round(pct)));
        nBlocks = 20;
        nFill = round(nBlocks * pct / 100);
        barText = ['[', repmat('#', 1, nFill), repmat('-', 1, nBlocks - nFill), sprintf('] %3d%%', pct)];
        app.LastProgressPct = pct;
        app.LastProgressStage = char(string(msg));
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
        end
        drawnow('limitrate');
    end


    function updateConfigGroupView(app)
        % UPDATECONFIGGROUPVIEW Rebuild selected-group controls with edit boxes/sliders.
        if isempty(app.cfg) || isempty(app.ConfigDynamicPanel) || ~isvalid(app.ConfigDynamicPanel)
            return;
        end
        group = char(string(app.ConfigGroupList.Value));
        app.ConfigGroupTitleLabel.Text = sprintf('%s editor', group);
        try
            rebuildConfigDynamicControls(app, group);
        catch ME
            delete(allchild(app.ConfigDynamicPanel));
            uilabel(app.ConfigDynamicPanel, 'Text', sprintf('Config view error: %s', ME.message), ...
                'FontColor', app.Theme.colors.danger, 'WordWrap', 'on', 'Position', [8 45 330 55]);
        end
    end

    function rebuildConfigDynamicControls(app, group)
        % REBUILDCONFIGDYNAMICCONTROLS Render text boxes/sliders for selected config group.
        c = app.Theme.colors;
        delete(allchild(app.ConfigDynamicPanel));
        app.ConfigDynamicControls = {};
        fields = configFieldsForGroup(app, group);
        if isempty(fields)
            uilabel(app.ConfigDynamicPanel, 'Text', 'No editable fields for this group.', ...
                'FontColor', c.text_muted, 'Position', [8 55 330 24]);
            return;
        end
        maxRows = min(numel(fields), 4);
        y0 = 92;
        for k = 1:maxRows
            f = fields(k);
            y = y0 - (k-1)*28;
            uilabel(app.ConfigDynamicPanel, 'Text', f.label, 'FontColor', c.text_light, ...
                'FontSize', 10, 'Position', [8 y 122 20]);
            value = getNestedConfigValue(app.cfg, f.path, f.defaultValue);
            switch f.type
                case 'numeric'
                    edit = uieditfield(app.ConfigDynamicPanel, 'numeric', ...
                        'Value', double(value), 'Position', [135 y 80 22], ...
                        'ValueChangedFcn', @(src, ~) onDynamicConfigControlChanged(app, src));
                    if isfield(f, 'limits') && ~isempty(f.limits)
                        edit.Limits = f.limits;
                    end
                    edit.UserData = f;
                    app.ConfigDynamicControls{end+1} = edit; %#ok<AGROW>
                    if isfield(f, 'slider') && f.slider
                        slider = uislider(app.ConfigDynamicPanel, 'Limits', f.limits, ...
                            'Value', min(max(double(value), f.limits(1)), f.limits(2)), ...
                            'Position', [225 y+11 120 3], ...
                            'ValueChangedFcn', @(src, ~) onDynamicConfigControlChanged(app, src));
                        slider.UserData = f;
                        app.ConfigDynamicControls{end+1} = slider; %#ok<AGROW>
                    end
                case 'logical'
                    chk = uicheckbox(app.ConfigDynamicPanel, 'Text', '', 'Value', logical(value), ...
                        'Position', [135 y 50 22], ...
                        'ValueChangedFcn', @(src, ~) onDynamicConfigControlChanged(app, src));
                    chk.UserData = f;
                    app.ConfigDynamicControls{end+1} = chk; %#ok<AGROW>
                otherwise
                    edit = uieditfield(app.ConfigDynamicPanel, 'text', ...
                        'Value', char(string(value)), 'Position', [135 y 205 22], ...
                        'ValueChangedFcn', @(src, ~) onDynamicConfigControlChanged(app, src));
                    edit.UserData = f;
                    app.ConfigDynamicControls{end+1} = edit; %#ok<AGROW>
            end
        end
        if numel(fields) > maxRows
            uilabel(app.ConfigDynamicPanel, 'Text', sprintf('+ %d more saved in JSON / advanced config', numel(fields)-maxRows), ...
                'FontColor', c.text_muted, 'FontSize', 9, 'Position', [8 4 330 18]);
        end
    end

    function fields = configFieldsForGroup(app, group)
        % CONFIGFIELDSFORGROUP Define group-specific editable controls.
        fields = struct('label', {}, 'path', {}, 'type', {}, 'defaultValue', {}, 'limits', {}, 'slider', {});
        switch group
            case 'Simulation'
                fields = [ ...
                    makeCfgField('Start date','simulation.start_date','text','2025-01-01'), ...
                    makeCfgField('End date','simulation.end_date','text','2025-12-31'), ...
                    makeCfgField('dt min','simulation.dt_min','numeric',15,[1 30],true), ...
                    makeCfgField('Mode','simulation.mode','text','representative')];
            case 'EV Parameters'
                fields = [ ...
                    makeCfgField('EV fraction','ev.penetration_rate','numeric',app.cfg.ev.penetration_rate,[0 1],true), ...
                    makeCfgField('Slow kW','ev.slow_kw','numeric',3.7,[0.1 50],false), ...
                    makeCfgField('Fast kW','ev.fast_kw','numeric',7.4,[0.1 100],false), ...
                    makeCfgField('V2G frac','ev.v2g_revenue_fraction','numeric',0.50,[0 1],true), ...
                    makeCfgField('SOC reserve','ev.soc_v2g_reserve_pct','numeric',30,[0 100],true)];
            case 'PQ Limits'
                fields = [ ...
                    makeCfgField('VUF max %','pq_limits.vuf_max_pct','numeric',2,[0 10],true), ...
                    makeCfgField('V min pu','pq_limits.voltage_min_pu','numeric',0.90,[0.80 1.0],true), ...
                    makeCfgField('V max pu','pq_limits.voltage_max_pu','numeric',1.10,[1.0 1.20],true), ...
                    makeCfgField('THDv max','pq_limits.thdv_max_pct','numeric',8,[0 20],true), ...
                    makeCfgField('THDi max','pq_limits.thdi_max_pct','numeric',15,[0 40],true), ...
                    makeCfgField('TL max %','pq_limits.transformer_loading_max_pct','numeric',100,[50 150],true)];
            case 'DSM Controller'
                fields = [ ...
                    makeCfgField('Controller','dsm.controller','text','milp'), ...
                    makeCfgField('Lambda','dsm.lambda_comfort','numeric',0.001,[0 0.1],false), ...
                    makeCfgField('CI min','dsm.comfort_ci_threshold','numeric',0.30,[0 1],true), ...
                    makeCfgField('Horizon','dsm.scheduling_horizon_steps','numeric',96,[24 192],true), ...
                    makeCfgField('Coord iter','dsm.max_coordination_iterations','numeric',3,[1 10],true)];
            case 'Pricing'
                fields = [ ...
                    makeCfgField('Flat EGP','pricing.flat_rate_egp_per_kwh','numeric',0.50,[0 5],true), ...
                    makeCfgField('RTP base','pricing.rtp_base_egp','numeric',0.65,[0 5],true), ...
                    makeCfgField('RTP vol','pricing.rtp_volatility','numeric',0.30,[0 2],true), ...
                    makeCfgField('CPP add','pricing.cpp_adder_egp_per_kwh','numeric',1.50,[0 10],true), ...
                    makeCfgField('Summer mult','pricing.seasonal_summer_multiplier','numeric',1.30,[0.5 3],true)];
            case 'HVAC'
                fields = [ ...
                    makeCfgField('Use HVAC','hvac.use','logical',true), ...
                    makeCfgField('Summer C','hvac.summer_setpoint_c','numeric',24,[18 30],true), ...
                    makeCfgField('Winter C','hvac.winter_setpoint_c','numeric',20,[15 26],true), ...
                    makeCfgField('Band C','hvac.delta_comfort_band_c','numeric',2,[0.5 6],true), ...
                    makeCfgField('Power kW','hvac.power_per_unit_kw','numeric',1.75,[0.5 5],true)];
        end
    end

    function onDynamicConfigControlChanged(app, src)
        % ONDYNAMICCONFIGCONTROLCHANGED Apply a dynamic config edit immediately.
        try
            f = src.UserData;
            value = src.Value;
            app.cfg = setNestedConfigValue(app.cfg, f.path, value);
            if strcmp(f.path, 'ev.penetration_rate')
                app.ConfigEvPenSlider.Value = 100 * value;
                app.ConfigEvPenValueLabel.Text = sprintf('%.0f%%', 100 * value);
            elseif strcmp(f.path, 'dsm.comfort_ci_threshold')
                app.ConfigComfortThresholdSlider.Value = value;
            end
            log(app, sprintf('Config updated: %s = %s', f.path, valueToText(value)));
        catch ME
            log(app, sprintf('Dynamic config update failed: %s', ME.message));
        end
    end

    function syncDynamicConfigControls(app)
        % SYNCDYNAMICCONFIGCONTROLS Re-apply current dynamic controls before saving.
        if isempty(app.ConfigDynamicControls), return; end
        for k = 1:numel(app.ConfigDynamicControls)
            h = app.ConfigDynamicControls{k};
            if isempty(h) || ~isvalid(h), continue; end
            try
                f = h.UserData;
                app.cfg = setNestedConfigValue(app.cfg, f.path, h.Value);
            catch
            end
        end
    end

    function styleAllAxes(app)
        % STYLEALLAXES Apply the app plot theme to every axes under the UI.
        try
            axList = findall(app.UIFigure, 'Type', 'axes');
            for k = 1:numel(axList)
                style_app_axes(axList(k), app.Theme);
            end
        catch
        end
    end

    function startClockTimer(app)
        % STARTCLOCKTIMER Keep the bottom status clock alive while the app is idle.
        try
            stopClockTimer(app);
            app.ClockTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 1.0, 'BusyMode', 'drop', ...
                'TimerFcn', @(~, ~) tickClock(app));
            start(app.ClockTimer);
        catch ME
            log(app, sprintf('Clock timer could not start: %s', ME.message));
        end
    end

    function stopClockTimer(app)
        % STOPCLOCKTIMER Stop and delete the UI clock timer.
        try
            if ~isempty(app.ClockTimer) && isvalid(app.ClockTimer)
                stop(app.ClockTimer);
                delete(app.ClockTimer);
            end
        catch
        end
        app.ClockTimer = [];
    end

    function tickClock(app)
        % TICKCLOCK Refresh clock/status text without changing the current stage.
        try
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure) || isempty(app.StatusBar) || ~isvalid(app.StatusBar)
                return;
            end
            app.StatusBar.Text = sprintf('%s | View: %s | %s', ...
                datestr(now, 'HH:MM:SS'), app.Theme.nav.labels{app.active_view}, app.LastStatusMessage);
            app.ProgressBar.Text = progressText(app.LastProgressPct);
            app.ProgressLabel.Text = sprintf('Stage: %s', app.LastProgressStage);
        catch
        end
    end

    function loadSavedUiState(app)
        % LOADSAVEDUISTATE Restore last lean scenario results and status if available.
        if isempty(app.cfg) || ~isfield(app.cfg, 'output_dir')
            return;
        end
        try
            resultFile = fullfile(app.cfg.output_dir, 'scenario_results.mat');
            if isfile(resultFile)
                S = load(resultFile, 'all_results');
                if isfield(S, 'all_results')
                    app.all_results = S.all_results;
                    app.all_results_ready = true;
                    for sid = [-1 0 1 2 3 4 5 6]
                        idx = scenarioResultIndex(sid);
                        if idx <= numel(app.all_results) && ~isempty(app.all_results{idx})
                            r = app.all_results{idx};
                            if isstruct(r) && isfield(r, 'error')
                                updateScenarioCardStatus(app, sid, 'failed');
                            else
                                updateScenarioCardStatus(app, sid, 'complete');
                            end
                        end
                    end
                    rLast = getLatestScenarioResult(app);
                    if ~isempty(rLast)
                        updateDashboardFromScenario(app, rLast);
                        updateScenarioLivePlot(app, rLast);
                    end
                    refreshResultsView(app);
                    log(app, sprintf('Restored saved scenario results from %s', resultFile));
                end
            end
        catch ME
            log(app, sprintf('Saved UI state restore warning: %s', ME.message));
        end
    end

    function saveUiState(app)
        % SAVEUISTATE Persist lightweight UI state for reopening the app later.
        try
            if isempty(app.cfg) || ~isfield(app.cfg, 'output_dir')
                return;
            end
            if exist(app.cfg.output_dir, 'dir') ~= 7
                mkdir(app.cfg.output_dir);
            end
            ui_state = struct(); %#ok<NASGU>
            ui_state.saved_on = datestr(now, 31);
            ui_state.active_view = app.active_view;
            ui_state.last_status_message = app.LastStatusMessage;
            ui_state.last_progress_pct = app.LastProgressPct;
            ui_state.last_progress_stage = app.LastProgressStage;
            ui_state.all_results_ready = app.all_results_ready;
            save(fullfile(app.cfg.output_dir, 'ui_app_state.mat'), 'ui_state', '-v7');
        catch ME
            log(app, sprintf('UI state save warning: %s', ME.message));
        end
    end

    function r = getLatestScenarioResult(app)
        % GETLATESTSCENARIORESULT Return the latest non-empty retained scenario result.
        r = [];
        try
            if isempty(app.all_results)
                return;
            end
            for k = numel(app.all_results):-1:1
                if ~isempty(app.all_results{k}) && isstruct(app.all_results{k}) && ~isfield(app.all_results{k}, 'error')
                    r = app.all_results{k};
                    if isfield(r, 'fast')
                        r = r.fast;
                    elseif isfield(r, 'slow')
                        r = r.slow;
                    end
                    return;
                end
            end
        catch
            r = [];
        end
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
        % ONRUNTESTS Dashboard quick action: switch to Tests view and run all.
        switchView(app, 9);
        onRunAllUiTests(app);
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


function lines = exportPathLines(titleText, paths)
% EXPORTPATHLINES Format export paths for UI text areas.
if ischar(paths) || isstring(paths), paths = cellstr(paths); end
lines = {sprintf('%s: %d file(s)', titleText, numel(paths))};
maxShow = min(numel(paths), 8);
for k = 1:maxShow
    lines{end+1,1} = char(string(paths{k})); %#ok<AGROW>
end
if numel(paths) > maxShow
    lines{end+1,1} = sprintf('... plus %d more file(s)', numel(paths) - maxShow); %#ok<AGROW>
end
end

function label = shortScenarioLabel(description, fallback)
% SHORTSCENARIOLABEL Compact label for result dropdown/table.
try
    txt = char(string(description));
    if contains(txt, 'Baseline', 'IgnoreCase', true), label = 'Baseline 0'; return; end
    tok = regexp(txt, 'Scenario\s*([0-9]+(?:\.[0-9]+)?)', 'tokens', 'once');
    if ~isempty(tok)
        label = ['Scenario ', tok{1}];
        return;
    end
catch
end
label = fallback;
end

function rows = buildResultsMetricRows(results, labels)
% BUILDRESULTSMETRICROWS Build lean-compatible comparison table rows.
rows = cell(numel(results), 8);
for k = 1:numel(results)
    r = results{k};
    rows{k,1} = labels{k};
    rows{k,2} = resultMetric(r, 'mean_vuf_pct');
    rows{k,3} = resultMetric(r, 'max_vuf_pct');
    rows{k,4} = resultMetric(r, 'min_voltage_pu');
    rows{k,5} = resultMetric(r, 'max_loading_pct');
    rows{k,6} = resultMetric(r, 'hosting_capacity_pct');
    rows{k,7} = resultMetric(r, 'mean_ci');
    rows{k,8} = mean(resultBills(r, 'Block'), 'omitnan');
end
end

function v = resultMetric(r, key)
% RESULTMETRIC Extract common scalar KPI from lean scenario result.
v = NaN;
if ~isstruct(r), return; end
try
    switch lower(key)
        case {'hosting_capacity_pct','hosting_cap_pct'}
            if isfield(r, 'hosting_capacity_pct'), v = scalarMean(r.hosting_capacity_pct); end
        case {'mean_ci','comfort_ci'}
            if isfield(r, 'comfort_summary') && isfield(r.comfort_summary, 'mean_ci')
                v = scalarMean(r.comfort_summary.mean_ci);
            end
        case {'max_thdi_pct'}
            if isfield(r, 'pq_summary')
                if isfield(r.pq_summary, 'max_thdi_pct'), v = scalarMean(r.pq_summary.max_thdi_pct); return; end
                if isfield(r.pq_summary, 'thdi_pct'), v = max(r.pq_summary.thdi_pct(:), [], 'omitnan'); return; end
            end
        case {'max_thdv_pct'}
            if isfield(r, 'pq_summary')
                if isfield(r.pq_summary, 'max_thdv_pct'), v = scalarMean(r.pq_summary.max_thdv_pct); return; end
                if isfield(r.pq_summary, 'thdv_pct'), v = max(r.pq_summary.thdv_pct(:), [], 'omitnan'); return; end
            end
        otherwise
            if isfield(r, 'pq_summary') && isfield(r.pq_summary, key)
                v = scalarMean(r.pq_summary.(key));
            elseif isfield(r, key)
                v = scalarMean(r.(key));
            end
    end
catch
    v = NaN;
end
end

function v = scalarMean(x)
% SCALARMEAN Mean numeric/cell/table values, fallback NaN.
try
    if istable(x), x = table2array(x); end
    if iscell(x), x = cell2mat(x); end
    v = mean(x(:), 'omitnan');
catch
    v = NaN;
end
end

function bills = resultBills(r, tariff)
% RESULTBILLS Extract bill vector for a selected tariff from result.costs.
bills = NaN;
try
    if isstruct(r) && isfield(r, 'costs') && isfield(r.costs, 'bill_total')
        bt = r.costs.bill_total;
        if isstruct(bt) && isfield(bt, tariff)
            bills = bt.(tariff);
        elseif istable(bt) && any(strcmpi(bt.Properties.VariableNames, tariff))
            bills = bt.(tariff);
        end
    end
catch
    bills = NaN;
end
if isempty(bills), bills = NaN; end
end

function inc = resultEvIncrement(r)
% RESULTEVINCREMENT Extract EV cost increment when available.
inc = NaN;
try
    if isstruct(r) && isfield(r, 'costs') && isfield(r.costs, 'ev_cost_increment')
        inc = scalarMean(r.costs.ev_cost_increment);
    end
catch
end
end

function c = inferBindingConstraint(meanVuf, vmin, maxTl, cfg)
% INFERBINDINGCONSTRAINT Human-readable likely binding constraint.
c = 'None / summary';
try
    if ~isnan(meanVuf) && meanVuf > cfg.pq_limits.vuf_max_pct
        c = 'VUF > limit';
    elseif ~isnan(vmin) && vmin < cfg.pq_limits.voltage_min_pu
        c = 'Voltage min';
    elseif ~isnan(maxTl) && maxTl > cfg.pq_limits.transformer_loading_max_pct
        c = 'Transformer loading';
    end
catch
end
end

function [rows, names] = twinFlexRows(windows, cfg)
% TWINFLEXROWS Convert HouseholdTwin flexibility API into table rows.
rows = cell(0,5);
names = {};
try
    if isempty(windows), return; end
    if isstruct(windows) && isfield(windows, 'count') && isfield(windows, 'appliance')
        A = double(windows.count);
        for k = 1:A
            w = struct();
            w.preferred_start_step = windows.preferred_start_step(k);
            w.window_start_step = windows.earliest_start_step(k);
            w.window_end_step = windows.latest_start_step(k);
            w.max_shift_steps = windows.max_shift_steps(k);
            nm = char(string(windows.appliance{k}));
            [rows, names] = addTwinWindowRow(rows, names, nm, w, cfg);
        end
    elseif isstruct(windows)
        f = fieldnames(windows);
        for k = 1:numel(f)
            w = windows.(f{k});
            [rows, names] = addTwinWindowRow(rows, names, f{k}, w, cfg);
        end
    elseif iscell(windows)
        for k = 1:numel(windows)
            w = windows{k};
            if isstruct(w) && isfield(w, 'appliance')
                nm = char(string(w.appliance));
            else
                nm = sprintf('Load_%d', k);
            end
            [rows, names] = addTwinWindowRow(rows, names, nm, w, cfg);
        end
    end
catch
end
end

function [rows, names] = addTwinWindowRow(rows, names, nm, w, cfg)
% ADDTWINWINDOWROW Append one flexibility row.
try
    pref = getStructFieldOr(w, 'preferred_start_step', 1);
    ws = getStructFieldOr(w, 'window_start_step', getStructFieldOr(w, 'win_start', 1));
    we = getStructFieldOr(w, 'window_end_step', getStructFieldOr(w, 'win_end', 96));
    maxShift = getStructFieldOr(w, 'max_shift_steps', abs(we-ws));
    ci = 1.0;
    dt = cfg.simulation.dt_min;
    row = {nm, stepToClock(pref, dt), sprintf('%s-%s', stepToClock(ws, dt), stepToClock(we, dt)), maxShift * dt, ci};
    rows(end+1,:) = row; %#ok<AGROW>
    names{end+1} = nm; %#ok<AGROW>
catch
end
end

function v = getStructFieldOr(s, name, default)
% GETSTRUCTFIELDOR Get struct field or default.
v = default;
if isstruct(s) && isfield(s, name), v = s.(name); end
end

function txt = stepToClock(step, dtMin)
% STEPTOCLOCK Convert 1-based step to HH:MM string.
mins = max(0, round((step-1) * dtMin));
hh = floor(mod(mins, 1440) / 60);
mm = mod(mins, 60);
txt = sprintf('%02d:%02d', hh, mm);
end

function ids = resultIdsFromLabels(labels)
% RESULTIDSFROMLABELS Backward-compatible helper for labels to scenario ids.
ids = nan(size(labels));
for k = 1:numel(labels)
    txt = char(string(labels{k}));
    if contains(txt, 'Baseline', 'IgnoreCase', true)
        ids(k) = -1;
    else
        tok = regexp(txt, 'Scenario\s*([0-9]+)', 'tokens', 'once');
        if ~isempty(tok), ids(k) = str2double(tok{1}); else, ids(k) = k - 2; end
    end
end
end

function idx = scenarioResultIndex(sid)
% SCENARIORESULTINDEX Map scenario ID to cell index: -1->1, 0->2, ..., 6->8.
idx = sid + 2;
end

function txt = scenarioDescriptionText(sid)
% SCENARIODESCRIPTIONTEXT Human-readable scenario description for UI.
switch sid
    case -1
        txt = 'Baseline 0 - no EVs and no DSM. Reference feeder and household behavior only.';
    case 0
        txt = 'Scenario 0 - no EVs with rule-based DSM for controllable household appliances.';
    case 1
        txt = 'Scenario 1 - uncontrolled EV integration with immediate charging at arrival.';
    case 2
        txt = 'Scenario 2 - slow 3.7 kW versus fast 7.4 kW uncontrolled EV comparison.';
    case 3
        txt = 'Scenario 3 - MILP-controlled EV charging only.';
    case 4
        txt = 'Scenario 4 - MILP-controlled household loads plus EV charging, without V2G.';
    case 5
        txt = 'Scenario 5 - MILP-controlled household loads plus EV and V2G.';
    case 6
        txt = 'Scenario 6 - full hierarchical AI-DSM with feeder supervisor and V2G.';
    otherwise
        txt = sprintf('Scenario %g', sid);
end
end

function rows = buildFlexibilityTable(cfg)
% BUILDFLEXIBILITYTABLE Convert DSM comfort maps into table rows.
apps = fieldnames(cfg.dsm.comfort_max_shift_min);
rows = cell(numel(apps), 4);
for k = 1:numel(apps)
    appName = apps{k};
    rows{k,1} = appName;
    rows{k,2} = cfg.dsm.comfort_max_shift_min.(appName);
    if isfield(cfg.dsm.comfort_weights, appName)
        rows{k,3} = cfg.dsm.comfort_weights.(appName);
    else
        rows{k,3} = 1.0;
    end
    rows{k,4} = true;
end
end

function cfg = applyFlexibilityTable(cfg, rows)
% APPLYFLEXIBILITYTABLE Apply edited flexibility table to cfg.
for k = 1:size(rows,1)
    name = matlab.lang.makeValidName(char(string(rows{k,1})));
    cfg.dsm.comfort_max_shift_min.(name) = rows{k,2};
    cfg.dsm.comfort_weights.(name) = rows{k,3};
end
end

function rows = buildAssignmentSummary(assignment, net)
% BUILDASSIGNMENTSUMMARY Summarize households/EVs/phases per zone.
Z = net.n_transformers;
rows = cell(Z+1, 7);
for z = 1:Z
    idx = find(assignment.zone == z);
    rows{z,1} = sprintf('T%d', z);
    rows{z,2} = numel(idx);
    rows{z,3} = sum(assignment.has_ev(idx));
    rows{z,4} = sum(assignment.has_ev(idx) & strcmpi(assignment.charger_type(idx), 'v2g'));
    rows{z,5} = sum(assignment.phase_id(idx) == 1);
    rows{z,6} = sum(assignment.phase_id(idx) == 2);
    rows{z,7} = sum(assignment.phase_id(idx) == 3);
end
rows{Z+1,1} = 'Total';
rows{Z+1,2} = numel(assignment.zone);
rows{Z+1,3} = sum(assignment.has_ev);
rows{Z+1,4} = sum(assignment.has_ev & strcmpi(assignment.charger_type(:), 'v2g'));
rows{Z+1,5} = sum(assignment.phase_id == 1);
rows{Z+1,6} = sum(assignment.phase_id == 2);
rows{Z+1,7} = sum(assignment.phase_id == 3);
end

function cal_day = buildUiCalDay(dayText)
% BUILDUICALDAY Convert UI day selection into cal_day struct.
cal_day.daytype = uint8(0);
cal_day.is_ramadan = false;
cal_day.season = categorical({'summer'});
if contains(dayText, 'Weekend', 'IgnoreCase', true)
    cal_day.daytype = uint8(1);
end
if contains(dayText, 'Winter', 'IgnoreCase', true)
    cal_day.season = categorical({'winter'});
end
if contains(dayText, 'Ramadan', 'IgnoreCase', true)
    cal_day.is_ramadan = true;
end
end

function rows = buildBlockSlabRows(cfg, kwh)
% BUILDBLOCKSLABROWS Build block tariff row breakdown.
slabs = cfg.pricing.block_slabs_kwh(:)';
rates = cfg.pricing.block_rates_egp(:)';
remaining = kwh;
prevUpper = 0;
rows = cell(numel(rates), 4);
for k = 1:numel(rates)
    if k <= numel(slabs)
        upper = slabs(k);
        slabName = sprintf('%g-%g', prevUpper, upper);
    else
        upper = Inf;
        slabName = sprintf('>%g', prevUpper);
    end
    width = min(max(remaining, 0), upper - prevUpper);
    charge = width * rates(k);
    rows{k,1} = slabName;
    rows{k,2} = width;
    rows{k,3} = rates(k);
    rows{k,4} = charge;
    remaining = remaining - width;
    prevUpper = upper;
end
end


function data = flattenStructForUi(section, groupName)
% FLATTENSTRUCTFORUI Convert simple config fields to a two-column cell table.
if nargin < 2, groupName = 'Config'; end
if ~isstruct(section)
    data = {groupName, valueToUiString(section)};
    return;
end
fields = fieldnames(section);
rows = {};
for i = 1:numel(fields)
    f = fields{i};
    v = section.(f);
    if isstruct(v)
        sub = fieldnames(v);
        for j = 1:numel(sub)
            rows(end+1,:) = {sprintf('%s.%s', f, sub{j}), valueToUiString(v.(sub{j}))}; %#ok<AGROW>
        end
    else
        rows(end+1,:) = {f, valueToUiString(v)}; %#ok<AGROW>
    end
end
if isempty(rows)
    data = {'No scalar values', ''};
else
    data = rows;
end
end

function s = valueToUiString(v)
% VALUETOUISTRING Render a MATLAB value for table display.
try
    if ischar(v)
        s = v;
    elseif isstring(v)
        s = char(strjoin(v(:)', ', '));
    elseif islogical(v) && isscalar(v)
        s = char(string(v));
    elseif isnumeric(v)
        if isscalar(v)
            s = sprintf('%.6g', v);
        else
            flat = v(:)';
            maxN = min(numel(flat), 8);
            s = mat2str(flat(1:maxN), 5);
            if numel(flat) > maxN
                s = [s, ' ...'];
            end
        end
    elseif iscell(v)
        maxN = min(numel(v), 6);
        tmp = cell(1, maxN);
        for k = 1:maxN
            tmp{k} = valueToUiString(v{k});
        end
        s = strjoin(tmp, ', ');
        if numel(v) > maxN, s = [s, ' ...']; end
    else
        s = class(v);
    end
catch
    s = '<unavailable>';
end
end


function f = makeCfgField(label, path, typeName, defaultValue, limits, slider)
% MAKECFGFIELD Construct a config control descriptor.
if nargin < 5, limits = []; end
if nargin < 6, slider = false; end
f = struct('label', label, 'path', path, 'type', typeName, ...
    'defaultValue', defaultValue, 'limits', limits, 'slider', slider);
end

function value = getNestedConfigValue(cfg, pathStr, defaultValue)
% GETNESTEDCONFIGVALUE Resolve dotted config path with fallback.
value = defaultValue;
try
    parts = strsplit(pathStr, '.');
    tmp = cfg;
    for k = 1:numel(parts)
        tmp = tmp.(parts{k});
    end
    value = tmp;
catch
end
end

function cfg = setNestedConfigValue(cfg, pathStr, value)
% SETNESTEDCONFIGVALUE Set a dotted path in a nested config struct.
parts = strsplit(pathStr, '.');
if numel(parts) == 1
    cfg.(parts{1}) = value;
elseif numel(parts) == 2
    cfg.(parts{1}).(parts{2}) = value;
elseif numel(parts) == 3
    cfg.(parts{1}).(parts{2}).(parts{3}) = value;
else
    error('Only dotted paths up to 3 levels are supported: %s', pathStr);
end
end

function txt = valueToText(value)
% VALUETOTEXT Render a scalar value for log messages.
try
    if isnumeric(value) || islogical(value)
        if isscalar(value)
            txt = sprintf('%.6g', double(value));
        else
            txt = mat2str(value);
        end
    else
        txt = char(string(value));
    end
catch
    txt = '<value>';
end
end

function txt = progressText(pct)
% PROGRESSTEXT Build a stable text progress bar.
pct = max(0, min(100, round(pct)));
nBlocks = 20;
nFill = round(nBlocks * pct / 100);
txt = ['[', repmat('#', 1, nFill), repmat('-', 1, nBlocks - nFill), sprintf('] %3d%%', pct)];
end


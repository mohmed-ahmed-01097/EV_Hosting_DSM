function theme = app_theme()
% APP_THEME Return shared UI colors, fonts, labels, and layout constants.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   theme (struct): Theme colors, font sizes, navigation labels, and layout.
%
% Example:
%   theme = app_theme();
%   app.UIFigure.Color = theme.colors.bg_dark;

% --- Section 1: Colors ---
theme.colors.bg_dark    = [0.10, 0.10, 0.18];
theme.colors.bg_panel   = [0.13, 0.13, 0.22];
theme.colors.bg_card    = [0.16, 0.16, 0.27];
theme.colors.accent     = [0.00, 0.71, 0.85];
theme.colors.success    = [0.16, 0.67, 0.44];
theme.colors.warning    = [0.97, 0.75, 0.00];
theme.colors.danger     = [0.84, 0.16, 0.16];
theme.colors.text_light = [0.92, 0.92, 0.95];
theme.colors.text_muted = [0.65, 0.67, 0.74];
theme.colors.grid       = [0.30, 0.32, 0.40];

% --- Section 2: Fonts ---
theme.font.name       = 'Segoe UI';
theme.font.mono       = 'Consolas';
theme.font.title_size = 18;
theme.font.h1_size    = 16;
theme.font.h2_size    = 13;
theme.font.body_size  = 11;
theme.font.small_size = 9;

% --- Section 3: Layout constants ---
theme.layout.sidebar_width = 220;
theme.layout.status_height = 30;
theme.layout.card_width    = 200;
theme.layout.card_height   = 80;
theme.layout.card_gap      = 10;
theme.layout.margin        = 12;

% --- Section 4: Navigation labels ---
theme.nav.labels = { ...
    'Dashboard', ...
    'Config', ...
    'Feeder', ...
    'Load', ...
    'Pricing', ...
    'Scenarios', ...
    'Results', ...
    'Export', ...
    'Tests' ...
};

% ASCII icon names are used for portability in compiled apps.
theme.nav.icon_names = { ...
    'home', 'gear', 'feeder', 'load', 'pricing', ...
    'scenarios', 'results', 'export', 'tests' ...
};

% --- Section 5: KPI defaults ---
theme.kpi.names  = {'VUF', 'V_min', 'TL', 'NCR', 'THDv', 'Losses'};
theme.kpi.units  = {'%', 'pu', '%', '%', '%', 'kW'};
theme.kpi.limits = [2.0, 0.90, 100.0, 30.0, 8.0, 50.0];
end

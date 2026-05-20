function style_app_axes(ax, theme, mode)
% STYLE_APP_AXES Apply professional UI styling to MATLAB axes/UIAxes.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   ax    - target axes or UIAxes handle
%   theme - optional app_theme() struct
%   mode  - optional char: 'dark' (default) or 'light'
%
% Outputs:
%   None
%
% Example:
%   style_app_axes(app.PricingAxes, app.Theme);

if nargin < 1 || isempty(ax) || ~isvalid(ax)
    return;
end
if nargin < 2 || isempty(theme) || ~isstruct(theme)
    theme = app_theme();
end
if nargin < 3 || isempty(mode)
    mode = 'dark';
end

c = theme.colors;
try
    switch lower(char(string(mode)))
        case 'light'
            ax.Color = [1 1 1];
            ax.XColor = [0.12 0.14 0.20];
            ax.YColor = [0.12 0.14 0.20];
            ax.GridColor = [0.72 0.74 0.80];
            ax.MinorGridColor = [0.86 0.87 0.90];
        otherwise
            ax.Color = c.plot_bg;
            ax.XColor = c.text_light;
            ax.YColor = c.text_light;
            ax.GridColor = c.grid;
            ax.MinorGridColor = c.grid * 0.8;
    end
    ax.Box = 'on';
    ax.LineWidth = 0.8;
    ax.FontName = theme.font.name;
    ax.FontSize = 10;
    ax.Title.Color = ax.XColor;
    ax.XLabel.Color = ax.XColor;
    ax.YLabel.Color = ax.YColor;
    grid(ax, 'on');
catch
    % Some plot types/axes implementations do not expose every property.
end

try
    fig = ancestor(ax, 'figure');
    if ~isempty(fig)
        lgds = findall(fig, 'Type', 'Legend');
        for k = 1:numel(lgds)
            if isvalid(lgds(k))
                lgds(k).TextColor = ax.XColor;
                lgds(k).Color = ax.Color;
                lgds(k).EdgeColor = c.grid;
            end
        end
    end
catch
end
end

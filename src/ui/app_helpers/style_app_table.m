function style_app_table(tbl, theme)
% STYLE_APP_TABLE Apply a dark professional table style consistent with UI plots.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   tbl   - matlab.ui.control.Table handle
%   theme - app_theme() struct
%
% Outputs:
%   None. Styles table in-place.
%
% Notes:
%   MATLAB releases differ in UITable style support. Unsupported properties
%   are applied inside try/catch blocks so the app remains compiler-safe.

if nargin < 2 || isempty(theme)
    theme = app_theme();
end
if isempty(tbl) || ~isvalid(tbl)
    return;
end

c = theme.colors;
try
    tbl.BackgroundColor = [c.bg_card; c.bg_panel];
catch
end
try
    tbl.FontColor = c.text_light;
catch
end
try
    tbl.FontName = theme.font.name;
catch
end
try
    tbl.FontSize = 11;
catch
end
try
    tbl.RowStriping = 'on';
catch
end
try
    tbl.ColumnSortable = true(1, numel(tbl.ColumnName));
catch
end
try
    tbl.ForegroundColor = c.text_light;
catch
end
try
    tbl.Enable = 'on';
catch
end
end

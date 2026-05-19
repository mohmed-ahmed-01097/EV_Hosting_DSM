function test_part_b_step14_export_view()
% TEST_PART_B_STEP14_EXPORT_VIEW Validate PART B Step 14 Export UI.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   None
%
% Outputs:
%   Prints PASS/FAIL validation results.
%
% Example:
%   test_part_b_step14_export_view()
%
% Notes:
%   Static source checks only. This keeps main([], 'validate') non-interactive.

fprintf('\n[test_part_b_step14_export_view] Starting PART B Step 14 validation...\n');

rootDir = fileparts(fileparts(mfilename('fullpath')));
appPath = fullfile(rootDir, 'src', 'ui', 'EVHostingDSM_App.m');
helperPath = fullfile(rootDir, 'src', 'ui', 'app_helpers', 'app_export_helper.m');

assert_pass(isfile(appPath), 'EVHostingDSM_App.m exists');
assert_pass(isfile(helperPath), 'app_export_helper.m exists');

src = fileread(appPath);
helperSrc = fileread(helperPath);

% Export view construction
assert_contains(src, 'function createExportView(app)', 'Export view builder exists');
assert_contains(src, 'Figure Export', 'Figure export card exists');
assert_contains(src, 'CSV / Table Export', 'CSV export card exists');
assert_contains(src, 'LaTeX Thesis Report', 'LaTeX report card exists');
assert_contains(src, 'ExportFigureChecks', 'Figure checkbox group exists');
assert_contains(src, 'ExportCsvChecks', 'CSV checkbox group exists');
assert_contains(src, 'ExportFormatPngCheck', 'PNG format checkbox exists');
assert_contains(src, 'ExportFormatEpsCheck', 'EPS format checkbox exists');
assert_contains(src, 'ExportFormatSvgCheck', 'SVG format checkbox exists');
assert_contains(src, 'ExportFolderEdit', 'Dynamic export folder field exists');

% Export callbacks
assert_contains(src, 'function onExportSelectedFigures(app)', 'Export selected figures callback exists');
assert_contains(src, 'function onExportAllFigures(app)', 'Export all figures callback exists');
assert_contains(src, 'function onExportSelectedCsv(app)', 'Export selected CSV callback exists');
assert_contains(src, 'function onGenerateLatexReport(app)', 'Generate LaTeX report callback exists');
assert_contains(src, 'function onBrowseExportFolder(app)', 'Browse export folder callback exists');
assert_contains(src, 'function refreshExportView(app)', 'Export refresh method exists');
assert_contains(src, 'elseif viewId == 8', 'Switching to Export view refreshes export view');

% Export helper capabilities
assert_contains(helperSrc, '''figures_selected''', 'Helper supports selected figure export');
assert_contains(helperSrc, '''tables_selected''', 'Helper supports selected table export');
assert_contains(helperSrc, '''latex_report''', 'Helper supports LaTeX report export');
assert_contains(helperSrc, 'export_results_tables(results, cfg)', 'Helper reuses thesis table exporter');
assert_contains(helperSrc, '\\includegraphics', 'Helper writes LaTeX includegraphics entries');
assert_contains(helperSrc, 'get_fig_dir(cfg, opts, ''png'')', 'Helper writes PNG figures to figures/png');
assert_contains(helperSrc, 'get_fig_dir(cfg, opts, ''eps'')', 'Helper writes EPS figures to figures/eps');
assert_contains(helperSrc, 'normalize_results(results)', 'Helper is lean-results compatible');
assert_contains(helperSrc, 'L_feeder_w', 'Helper can export retained load profile data');

% Expected Step 14 export labels from the plan
assert_contains(src, 'VUF Comparison Bar Chart', 'VUF comparison export option exists');
assert_contains(src, 'Hosting Capacity Curve', 'Hosting export option exists');
assert_contains(src, 'Monthly Bill Box Plots', 'Cost figure export option exists');
assert_contains(src, 'Tariff Slab Migration Chart', 'Tariff slab export option exists');
assert_contains(src, 'PQ Summary', 'PQ summary CSV option exists');
assert_contains(src, 'Monthly Costs', 'Monthly costs CSV option exists');

fprintf('[test_part_b_step14_export_view] Complete. PART B Step 14 Export UI is implemented.\n');
end

function assert_contains(textValue, pattern, message)
assert_pass(contains(textValue, pattern), message);
end

function assert_pass(condition, message)
if condition
    fprintf('  PASS: %s\n', message);
else
    fprintf('  FAIL: %s\n', message);
    error('test_part_b_step14_export_view:assertionFailed', '%s', message);
end
end

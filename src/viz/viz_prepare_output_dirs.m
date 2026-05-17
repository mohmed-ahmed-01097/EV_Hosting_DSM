function dirs = viz_prepare_output_dirs(cfg)
% VIZ_PREPARE_OUTPUT_DIRS Create and return Phase 6 visualization folders.
%
% Author: Mohammed Ahmed
% Date: 2026
%
% Inputs:
%   cfg (struct): Project configuration. Expected fields are output_dir and
%       figs_dir, but the function also supports a minimal cfg in tests.
%
% Outputs:
%   dirs (struct): Output folder paths:
%       .figures - main results/figures folder
%       .png     - PNG export folder
%       .eps     - EPS export folder
%       .tables  - results/tables folder
%
% Example:
%   dirs = viz_prepare_output_dirs(cfg);

% --- Section 1: Resolve folders ---
if nargin < 1 || isempty(cfg) || ~isstruct(cfg)
    cfg = struct();
end
if isfield(cfg, 'figs_dir') && ~isempty(cfg.figs_dir)
    figuresDir = cfg.figs_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    figuresDir = fullfile(cfg.output_dir, 'figures');
elseif isfield(cfg, 'root_folder') && ~isempty(cfg.root_folder)
    figuresDir = fullfile(cfg.root_folder, 'results', 'figures');
else
    figuresDir = fullfile(pwd, 'results', 'figures');
end
if isfield(cfg, 'tables_dir') && ~isempty(cfg.tables_dir)
    tablesDir = cfg.tables_dir;
elseif isfield(cfg, 'output_dir') && ~isempty(cfg.output_dir)
    tablesDir = fullfile(cfg.output_dir, 'tables');
elseif isfield(cfg, 'root_folder') && ~isempty(cfg.root_folder)
    tablesDir = fullfile(cfg.root_folder, 'results', 'tables');
else
    tablesDir = fullfile(pwd, 'results', 'tables');
end

dirs = struct();
dirs.figures = figuresDir;
dirs.png = fullfile(figuresDir, 'png');
dirs.eps = fullfile(figuresDir, 'eps');
dirs.tables = tablesDir;

% --- Section 2: Create folders ---
folderList = {dirs.figures, dirs.png, dirs.eps, dirs.tables};
for k = 1:numel(folderList)
    if ~exist(folderList{k}, 'dir')
        mkdir(folderList{k});
    end
end
end

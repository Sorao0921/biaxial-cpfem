% Notice!!: Before run this script, do "start_mtex" on the command window!!
%
% This script reads Bunge Euler angle CSV files generated from rotation matrices
% and outputs pole figures for each CSV.


clc
clear
close all

% Force every figure created by MATLAB or MTEX to remain hidden.
old_default_figure_visible = get(groot, 'defaultFigureVisible');
old_default_figure_create_fcn = get(groot, 'defaultFigureCreateFcn');
set(groot, 'defaultFigureVisible', 'off');
set(groot, 'defaultFigureCreateFcn', @(fig, ~) set(fig, 'Visible', 'off'));
%% Parameters

% Case settings
rho = 1;
seed = 1;

% Project paths
% Expected directory structure:
% pipeline/
% |- tools/
% |  |- postprocess/
% |     |- post_polefigure.m
% |- outputs/
%    |- rho_{*}/
%       |- rho_{*}_seed{*}/
%          |- angles/
%             |- id_set/
%
% The path is resolved from this script location, not from the current folder.
SCRIPT_DIR = fileparts(mfilename('fullpath'));
PIPELINE_DIR = fileparts(fileparts(SCRIPT_DIR));
DATA_DIR = fullfile(PIPELINE_DIR, 'outputs');
ANGLE_DIR = fullfile(DATA_DIR, rho_dir_name(rho), [rho_dir_name(rho) '_' seed_dir_name(seed)], 'angles');

INPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'id_set');
OUTPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'polefigure');

% Crystal and specimen symmetry
CS = crystalSymmetry.load('Al-Aluminum.cif');
SS = specimenSymmetry('triclinic');

% Pole figure indices
h = {Miller(1,1,1,CS)};

% Plot options
marker_size = 1;
marker_color = 'black';
resolution = 300;

if ~exist(INPUT_ROOT_DIR, 'dir')
    error('Input directory does not exist: %s', INPUT_ROOT_DIR);
end

if ~exist(OUTPUT_ROOT_DIR, 'dir')
    mkdir(OUTPUT_ROOT_DIR);
end

%% Process each texture_sd* folder

case_dirs = dir(INPUT_ROOT_DIR);
case_dirs = case_dirs([case_dirs.isdir]);
case_dirs = case_dirs(~ismember({case_dirs.name}, {'.', '..'}));

if isempty(case_dirs)
    fprintf('No case directories found in: %s\n', INPUT_ROOT_DIR);
end

total_csv_count = 0;
total_png_count = 0;

for di = 1:numel(case_dirs)
    case_name = case_dirs(di).name;
    input_case_dir = fullfile(INPUT_ROOT_DIR, case_name);
    output_case_dir = fullfile(OUTPUT_ROOT_DIR, case_name);

    if ~exist(output_case_dir, 'dir')
        mkdir(output_case_dir);
    end

    csv_files = dir(fullfile(input_case_dir, 'bunge_euler_*.csv'));

    if isempty(csv_files)
        fprintf('[skip] %s: no bunge_euler_*.csv files found\n', case_name);
        continue
    end

    fprintf('[case] %s: %d csv files\n', case_name, numel(csv_files));

    for fi = 1:numel(csv_files)
        csv_name = csv_files(fi).name;
        csv_path = fullfile(input_case_dir, csv_name);

        [~, stem, ~] = fileparts(csv_name);

        % Match the PNG filename directly to the CSV filename.
        % Example:
        %   bunge_euler_s_sd2_state_01.csv
        %   -> polefigure_s_sd2_state_01.png
        output_stem = regexprep(stem, '^bunge_euler_', '');
        png_name = ['polefigure_' output_stem '.png'];
        png_path = fullfile(output_case_dir, png_name);

        total_csv_count = total_csv_count + 1;

        if exist(png_path, 'file')
            fprintf('  skip existing: %s\n', png_path);
            continue
        end

        try
            T = readtable(csv_path);

            required_cols = {'element_id', 'phi1', 'Phi', 'phi2'};
            assert_required_columns(T, required_cols, csv_path);

            phi1 = T.phi1;
            Phi  = T.Phi;
            phi2 = T.phi2;

            % MTEX internally uses radians, so radian values can be passed directly.
            O = orientation('Euler', phi1, Phi, phi2, CS, SS);

            % Let MTEX create its own figure. The root CreateFcn above forces
            % that figure to stay invisible before it can appear on screen.
            plotPDF(O, h, 'antipodal', 'all', ...
                'MarkerSize', marker_size, ...
                'markercolor', marker_color);
            fig = gcf;
            set(fig, 'Visible', 'off', 'Color', 'w')

            try
                exportgraphics(fig, png_path, 'Resolution', resolution);
            catch
                print(fig, '-dpng', sprintf('-r%d', resolution), png_path);
            end

            close(fig);

            total_png_count = total_png_count + 1;
            fprintf('  saved: %s\n', png_path);

        catch ME
            if exist('fig', 'var') && isvalid(fig)
                close(fig);
            end
            fprintf(2, '  failed: %s\n', csv_path);
            fprintf(2, '    %s\n', ME.message);
        end
    end
end

fprintf('All done. %d / %d pole figures saved.\n', total_png_count, total_csv_count);
fprintf('Output root: %s\n', OUTPUT_ROOT_DIR);

set(groot, 'defaultFigureCreateFcn', old_default_figure_create_fcn);
set(groot, 'defaultFigureVisible', old_default_figure_visible);
%% Local helper

function name = rho_dir_name(rho)
    if abs(rho - round(rho)) < 1.0e-12
        rho_text = sprintf('%d', round(rho));
    else
        rho_text = sprintf('%.6g', rho);
    end

    %rho_text = strrep(rho_text, '-', 'm');
    %rho_text = strrep(rho_text, '.', 'p');
    name = ['rho_' rho_text];
end

function name = seed_dir_name(seed)
    name = sprintf('seed%d', seed);
end

function assert_required_columns(T, required_cols, csv_path)
    actual_cols = T.Properties.VariableNames;

    for i = 1:numel(required_cols)
        col = required_cols{i};
        if ~ismember(col, actual_cols)
            error('Missing required column "%s" in %s', col, csv_path);
        end
    end
end

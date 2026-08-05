% Notice!!: Before running this script, execute "start_mtex"
% in the MATLAB command window.
%
% This script calculates element-wise misorientation between state01
% and state02-state13 using MTEX.
%
% Input CSV columns:
%   element_id, part_id, phi1, Phi, phi2
%
% Euler-angle unit:
%   radians
%
% Output CSV columns:
%   element_id
%   part_id
%   reference_state
%   target_state
%   misorientation_angle_rad
%   misorientation_angle_deg


clc
clear
close all


%% Parameters

% Case settings
rho = 1;
seed = 1;

% Reference and target states
REFERENCE_STATE = 1;
TARGET_STATES = 2:13;

% Skip an output CSV when it already exists
SKIP_EXISTING = true;


%% Project paths

% Expected directory structure:
%
% pipeline/
% |- tools/
% |  |- postprocess/
% |     |- post_misorientation.m
% |
% |- outputs/
%    |- rho_{*}/
%       |- rho_{*}_seed{*}/
%          |- angles/
%             |- id_set/
%             |  |- brass_sd2/
%             |  |- cube_sd2/
%             |  |- ...
%             |
%             |- misorientation/
%
% The path is resolved from this script location,
% not from the current MATLAB folder.

SCRIPT_DIR = fileparts(mfilename('fullpath'));
PIPELINE_DIR = fileparts(fileparts(SCRIPT_DIR));

DATA_DIR = fullfile(PIPELINE_DIR, 'outputs');

ANGLE_DIR = fullfile( ...
    DATA_DIR, ...
    rho_dir_name(rho), ...
    [rho_dir_name(rho) '_' seed_dir_name(seed)], ...
    'angles' ...
);

INPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'id_set');
OUTPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'misorientation');


%% Crystal and specimen symmetry

% FCC aluminum crystal symmetry
CS = crystalSymmetry.load('Al-Aluminum.cif');

% No assumed specimen symmetry
SS = specimenSymmetry('triclinic');


%% Validate root directories

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

total_target_count = 0;
total_saved_count = 0;
total_skipped_count = 0;
total_failed_count = 0;


for di = 1:numel(case_dirs)

    case_name = case_dirs(di).name;

    input_case_dir = fullfile(INPUT_ROOT_DIR, case_name);
    output_case_dir = fullfile(OUTPUT_ROOT_DIR, case_name);

    if ~exist(output_case_dir, 'dir')
        mkdir(output_case_dir);
    end

    fprintf('\n[case] %s\n', case_name);


    %% Find state01 reference CSV

    reference_csv_path = find_state_csv( ...
        input_case_dir, ...
        REFERENCE_STATE ...
    );

    if isempty(reference_csv_path)
        fprintf( ...
            2, ...
            '  [skip] state%02d CSV was not found in: %s\n', ...
            REFERENCE_STATE, ...
            input_case_dir ...
        );

        continue
    end

    fprintf('  reference: %s\n', reference_csv_path);


    %% Read state01 data

    try
        reference_table = read_orientation_table(reference_csv_path);

        validate_unique_element_ids( ...
            reference_table, ...
            reference_csv_path ...
        );

        reference_orientation = orientation( ...
            'Euler', ...
            reference_table.phi1, ...
            reference_table.Phi, ...
            reference_table.phi2, ...
            CS, ...
            SS ...
        );

    catch ME
        fprintf(2, '  failed to read reference CSV:\n');
        fprintf(2, '    %s\n', reference_csv_path);
        fprintf(2, '    %s\n', ME.message);

        total_failed_count = total_failed_count + 1;
        continue
    end


    %% Compare state02-state13 with state01

    for target_state = TARGET_STATES

        total_target_count = total_target_count + 1;

        target_csv_path = find_state_csv( ...
            input_case_dir, ...
            target_state ...
        );

        if isempty(target_csv_path)
            fprintf( ...
                '  [skip] state%02d CSV was not found\n', ...
                target_state ...
            );

            total_skipped_count = total_skipped_count + 1;
            continue
        end


        %% Output filename

        [~, reference_stem, ~] = fileparts(reference_csv_path);

        case_stem = remove_state_suffix(reference_stem);

        % Remove the bunge_euler_ prefix because the output file itself
        % already starts with misorientation_.
        case_stem = regexprep( ...
            case_stem, ...
            '^bunge_euler_', ...
            '' ...
        );

        output_name = sprintf( ...
            'misorientation_%s_state%02d_to_state%02d.csv', ...
            case_stem, ...
            REFERENCE_STATE, ...
            target_state ...
        );

        output_path = fullfile(output_case_dir, output_name);


        %% Skip existing output

        if SKIP_EXISTING && exist(output_path, 'file')
            fprintf( ...
                '  skip existing state%02d: %s\n', ...
                target_state, ...
                output_path ...
            );

            total_skipped_count = total_skipped_count + 1;
            continue
        end


        %% Calculate misorientation

        try
            target_table = read_orientation_table(target_csv_path);

            validate_unique_element_ids( ...
                target_table, ...
                target_csv_path ...
            );


            % Match target rows to state01 using element_id.
            %
            % reference_row_index(i) gives the row in reference_table
            % corresponding to target_table.element_id(i).

            [exists_in_reference, reference_row_index] = ismember( ...
                target_table.element_id, ...
                reference_table.element_id ...
            );


            %% Remove target elements not found in state01

            if any(~exists_in_reference)
                missing_count = sum(~exists_in_reference);

                fprintf( ...
                    2, ...
                    ['  warning: %d element IDs in state%02d ' ...
                     'were not found in state%02d\n'], ...
                    missing_count, ...
                    target_state, ...
                    REFERENCE_STATE ...
                );
            end

            target_common = target_table(exists_in_reference, :);

            matched_reference_indices = ...
                reference_row_index(exists_in_reference);

            reference_common = ...
                reference_table(matched_reference_indices, :);

            reference_orientation_common = ...
                reference_orientation(matched_reference_indices);


            if isempty(target_common)
                error( ...
                    ['No common element IDs were found between ' ...
                     'state%02d and state%02d.'], ...
                    REFERENCE_STATE, ...
                    target_state ...
                );
            end


            %% Construct target-state orientations

            target_orientation = orientation( ...
                'Euler', ...
                target_common.phi1, ...
                target_common.Phi, ...
                target_common.phi2, ...
                CS, ...
                SS ...
            );


            %% MTEX misorientation angle

            % angle(orientation1, orientation2) calculates the minimum
            % misorientation angle while accounting for crystal symmetry.
            %
            % MTEX returns the angle in radians.

            misorientation_angle_rad = angle( ...
                reference_orientation_common, ...
                target_orientation ...
            );

            misorientation_angle_deg = ...
                misorientation_angle_rad ./ degree;


            %% Check part_id consistency

            valid_part_rows = ...
                ~isnan(reference_common.part_id) & ...
                ~isnan(target_common.part_id);

            inconsistent_part_rows = ...
                valid_part_rows & ...
                reference_common.part_id ~= target_common.part_id;

            if any(inconsistent_part_rows)
                fprintf( ...
                    2, ...
                    ['  warning: part_id differs for %d elements ' ...
                     'between state%02d and state%02d\n'], ...
                    sum(inconsistent_part_rows), ...
                    REFERENCE_STATE, ...
                    target_state ...
                );
            end


            %% Create output table

            row_count = height(target_common);

            result_table = table( ...
                target_common.element_id, ...
                reference_common.part_id, ...
                repmat(REFERENCE_STATE, row_count, 1), ...
                repmat(target_state, row_count, 1), ...
                reference_common.phi1, ...
                reference_common.Phi, ...
                reference_common.phi2, ...
                target_common.phi1, ...
                target_common.Phi, ...
                target_common.phi2, ...
                misorientation_angle_rad, ...
                misorientation_angle_deg, ...
                'VariableNames', { ...
                    'element_id', ...
                    'part_id', ...
                    'reference_state', ...
                    'target_state', ...
                    'phi1_state01', ...
                    'Phi_state01', ...
                    'phi2_state01', ...
                    'phi1_target', ...
                    'Phi_target', ...
                    'phi2_target', ...
                    'misorientation_angle_rad', ...
                    'misorientation_angle_deg' ...
                } ...
            );

            result_table = sortrows( ...
                result_table, ...
                'element_id' ...
            );


            %% Save CSV

            writetable(result_table, output_path);

            total_saved_count = total_saved_count + 1;

            fprintf( ...
                ['  saved state%02d: %s\n' ...
                 '    elements = %d, mean = %.6f deg, ' ...
                 'max = %.6f deg\n'], ...
                target_state, ...
                output_path, ...
                height(result_table), ...
                mean( ...
                    result_table.misorientation_angle_deg, ...
                    'omitnan' ...
                ), ...
                max( ...
                    result_table.misorientation_angle_deg, ...
                    [], ...
                    'omitnan' ...
                ) ...
            );

        catch ME
            total_failed_count = total_failed_count + 1;

            fprintf( ...
                2, ...
                '  failed state%02d: %s\n', ...
                target_state, ...
                target_csv_path ...
            );

            fprintf(2, '    %s\n', ME.message);
        end
    end
end


%% Final summary

fprintf('\n');
fprintf('All done.\n');
fprintf('------------------------------------------------------------\n');
fprintf('Target states processed : %d\n', total_target_count);
fprintf('CSV files saved         : %d\n', total_saved_count);
fprintf('Skipped                 : %d\n', total_skipped_count);
fprintf('Failed                  : %d\n', total_failed_count);
fprintf('Output root             : %s\n', OUTPUT_ROOT_DIR);
fprintf('------------------------------------------------------------\n');


%% Local helpers

function name = rho_dir_name(rho)

    if abs(rho - round(rho)) < 1.0e-12
        rho_text = sprintf('%d', round(rho));
    else
        rho_text = sprintf('%.6g', rho);
    end

    % Keep the same notation as post_polefigure.m.
    %
    % Examples:
    %   rho = 1    -> rho_1
    %   rho = -0.5 -> rho_-0.5

    % rho_text = strrep(rho_text, '-', 'm');
    % rho_text = strrep(rho_text, '.', 'p');

    name = ['rho_' rho_text];
end


function name = seed_dir_name(seed)

    name = sprintf('seed%d', seed);
end


function csv_path = find_state_csv(case_dir, state)
%FIND_STATE_CSV Find a Bunge Euler CSV corresponding to a state.
%
% Supported suffixes:
%   state01.csv
%   state_01.csv
%   state1.csv
%   state_1.csv

    csv_path = '';

    csv_files = dir(fullfile(case_dir, 'bunge_euler_*.csv'));

    if isempty(csv_files)
        return
    end

    matched_paths = {};

    for i = 1:numel(csv_files)

        csv_name = csv_files(i).name;

        state_number = extract_state_number(csv_name);

        if ~isnan(state_number) && state_number == state
            matched_paths{end + 1} = fullfile( ... %#ok<AGROW>
                case_dir, ...
                csv_name ...
            );
        end
    end

    if isempty(matched_paths)
        return
    end

    if numel(matched_paths) > 1
        error( ...
            ['Multiple CSV files corresponding to state%02d ' ...
             'were found in %s:\n%s'], ...
            state, ...
            case_dir, ...
            strjoin(matched_paths, newline) ...
        );
    end

    csv_path = matched_paths{1};
end


function state = extract_state_number(filename)
%EXTRACT_STATE_NUMBER Extract state number from a CSV filename.

    token = regexp( ...
        filename, ...
        '_state_?(\d+)\.csv$', ...
        'tokens', ...
        'once' ...
    );

    if isempty(token)
        state = NaN;
        return
    end

    state = str2double(token{1});
end


function stem_without_state = remove_state_suffix(stem)
%REMOVE_STATE_SUFFIX Remove stateXX or state_XX from a filename stem.

    stem_without_state = regexprep( ...
        stem, ...
        '_state_?\d+$', ...
        '' ...
    );
end


function T = read_orientation_table(csv_path)
%READ_ORIENTATION_TABLE Read and validate an Euler-angle CSV.

    T = readtable( ...
        csv_path, ...
        'VariableNamingRule', ...
        'preserve' ...
    );

    required_cols = { ...
        'element_id', ...
        'part_id', ...
        'phi1', ...
        'Phi', ...
        'phi2' ...
    };

    assert_required_columns(T, required_cols, csv_path);

    % Retain only the columns used by this script.
    T = T(:, required_cols);

    % Convert to double explicitly.
    T.element_id = double(T.element_id);
    T.part_id = double(T.part_id);
    T.phi1 = round(double(T.phi1),7);
    T.Phi = round(double(T.Phi),7);
    T.phi2 = round(double(T.phi2),7);


    %% Remove invalid rows

    invalid_rows = ...
        isnan(T.element_id) | ...
        isnan(T.phi1) | ...
        isnan(T.Phi) | ...
        isnan(T.phi2);

    if any(invalid_rows)
        fprintf( ...
            2, ...
            '  warning: removing %d invalid rows from %s\n', ...
            sum(invalid_rows), ...
            csv_path ...
        );

        T(invalid_rows, :) = [];
    end

    T = sortrows(T, 'element_id');
end


function assert_required_columns(T, required_cols, csv_path)

    actual_cols = T.Properties.VariableNames;

    for i = 1:numel(required_cols)

        col = required_cols{i};

        if ~ismember(col, actual_cols)
            error( ...
                'Missing required column "%s" in %s', ...
                col, ...
                csv_path ...
            );
        end
    end
end


function validate_unique_element_ids(T, csv_path)
%VALIDATE_UNIQUE_ELEMENT_IDS Ensure each element appears only once.

    [unique_ids, ~, group_indices] = unique(T.element_id);

    counts = accumarray(group_indices, 1);

    duplicated_ids = unique_ids(counts > 1);

    if isempty(duplicated_ids)
        return
    end

    shown_count = min(10, numel(duplicated_ids));
    shown_ids = duplicated_ids(1:shown_count);

    error( ...
        ['Duplicated element IDs were found in %s.\n' ...
         'Number of duplicated IDs: %d\n' ...
         'Examples: %s'], ...
        csv_path, ...
        numel(duplicated_ids), ...
        mat2str(shown_ids') ...
    );
end
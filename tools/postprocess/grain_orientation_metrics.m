% Grain-average rotation and GOS calculation with MTEX.
%
% Run tools/postprocess/start_mtex.m before this script.  Input files are the
% element-wise Bunge Euler CSVs produced by id_set.py (angles in radians).
% Each output row represents one grain/part.  All orientation operations use
% MTEX orientation objects, so Euler-angle singularities and FCC crystal
% symmetry are handled by MTEX rather than by subtracting Euler angles.

clc
clear

%% Parameters
rho = 1;
seed = 3;

REFERENCE_STATE = 1;
TARGET_STATES = 2:13;
SKIP_EXISTING = true;

%% Paths and symmetry
SCRIPT_DIR = fileparts(mfilename('fullpath'));
PIPELINE_DIR = fileparts(fileparts(SCRIPT_DIR));
ANGLE_DIR = fullfile(PIPELINE_DIR, 'outputs', rho_dir_name(rho), ...
    [rho_dir_name(rho) '_' sprintf('seed%d', seed)], 'angles');
INPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'id_set');
OUTPUT_ROOT_DIR = fullfile(ANGLE_DIR, 'grain_orientation_metrics');

CS = crystalSymmetry.load('Al-Aluminum.cif');
SS = specimenSymmetry('triclinic');
if ~exist(INPUT_ROOT_DIR, 'dir')
    error('Input directory does not exist: %s', INPUT_ROOT_DIR);
end
if ~exist(OUTPUT_ROOT_DIR, 'dir'); mkdir(OUTPUT_ROOT_DIR); end

case_dirs = dir(INPUT_ROOT_DIR);
case_dirs = case_dirs([case_dirs.isdir]);
case_dirs = case_dirs(~ismember({case_dirs.name}, {'.', '..'}));

for di = 1:numel(case_dirs)
    case_name = case_dirs(di).name;
    input_case_dir = fullfile(INPUT_ROOT_DIR, case_name);
    output_case_dir = fullfile(OUTPUT_ROOT_DIR, case_name);
    if ~exist(output_case_dir, 'dir'); mkdir(output_case_dir); end

    reference_path = find_state_csv(input_case_dir, REFERENCE_STATE);
    if isempty(reference_path)
        fprintf(2, '[skip] %s: reference state not found\n', case_name);
        continue
    end
    reference = read_orientation_table(reference_path);

    for target_state = TARGET_STATES
        target_path = find_state_csv(input_case_dir, target_state);
        if isempty(target_path); continue; end

        case_stem = regexprep(remove_state_suffix(erase(case_name, 'id_set_')), ...
            '^bunge_euler_', '');
        output_path = fullfile(output_case_dir, sprintf( ...
            'grain_metrics_%s_state%02d_to_state%02d.csv', ...
            case_stem, REFERENCE_STATE, target_state));
        if SKIP_EXISTING && exist(output_path, 'file')
            fprintf('[skip existing] %s\n', output_path);
            continue
        end

        target = read_orientation_table(target_path);
        [common_ids, ia, ib] = intersect(reference.element_id, target.element_id, 'stable');
        if isempty(common_ids)
            fprintf(2, '[skip] %s state%02d: no common elements\n', case_name, target_state);
            continue
        end
        ref = reference(ia, :);
        tar = target(ib, :);
        if any(ref.part_id ~= tar.part_id)
            fprintf(2, '[warning] %s state%02d: part IDs changed; using target IDs\n', ...
                case_name, target_state);
        end

        ref_ori = orientation('Euler', ref.phi1, ref.Phi, ref.phi2, CS, SS);
        tar_ori = orientation('Euler', tar.phi1, tar.Phi, tar.phi2, CS, SS);
        part_ids = unique(tar.part_id);
        n = numel(part_ids);
        element_count = zeros(n, 1);
        rotation_deg = zeros(n, 1);
        gos_deg = zeros(n, 1);
        ref_euler = zeros(n, 3);
        tar_euler = zeros(n, 3);

        for gi = 1:n
            selected = tar.part_id == part_ids(gi);
            element_count(gi) = sum(selected);
            mean_ref = mean(ref_ori(selected));
            mean_tar = mean(tar_ori(selected));

            % Minimum crystallographic angle between grain-average states.
            rotation_deg(gi) = angle(mean_ref, mean_tar) ./ degree;
            % GOS: arithmetic mean of element-to-current-grain-mean angles.
            gos_deg(gi) = mean(angle(tar_ori(selected), mean_tar)) ./ degree;
            [ref_phi1, ref_Phi, ref_phi2] = Euler(mean_ref);
            [tar_phi1, tar_Phi, tar_phi2] = Euler(mean_tar);
            ref_euler(gi, :) = [ref_phi1, ref_Phi, ref_phi2] ./ degree;
            tar_euler(gi, :) = [tar_phi1, tar_Phi, tar_phi2] ./ degree;
        end

        result = table(part_ids, element_count, ...
            repmat(REFERENCE_STATE, n, 1), repmat(target_state, n, 1), ...
            rotation_deg, gos_deg, ...
            ref_euler(:,1), ref_euler(:,2), ref_euler(:,3), ...
            tar_euler(:,1), tar_euler(:,2), tar_euler(:,3), ...
            'VariableNames', {'part_id','element_count','reference_state', ...
            'target_state','grain_rotation_deg','gos_deg', ...
            'mean_phi1_reference_deg','mean_Phi_reference_deg','mean_phi2_reference_deg', ...
            'mean_phi1_target_deg','mean_Phi_target_deg','mean_phi2_target_deg'});
        writetable(sortrows(result, 'part_id'), output_path);
        fprintf('[saved] %s (%d grains)\n', output_path, n);
    end
end

function T = read_orientation_table(path)
    T = readtable(path, 'VariableNamingRule', 'preserve');
    required = {'element_id','part_id','phi1','Phi','phi2'};
    if ~all(ismember(required, T.Properties.VariableNames))
        error('Missing required columns in %s', path);
    end
    T = T(:, required);
    T{:, :} = double(T{:, :});
    T = T(all(isfinite(T{:, :}), 2), :);
    if numel(unique(T.element_id)) ~= height(T)
        error('Duplicate element IDs in %s', path);
    end
    T = sortrows(T, 'element_id');
end

function path = find_state_csv(case_dir, state)
    files = dir(fullfile(case_dir, 'bunge_euler_*.csv'));
    path = '';
    for i = 1:numel(files)
        token = regexp(files(i).name, '_state_?(\d+)\.csv$', 'tokens', 'once');
        if ~isempty(token) && str2double(token{1}) == state
            if ~isempty(path); error('Multiple state%02d files in %s', state, case_dir); end
            path = fullfile(case_dir, files(i).name);
        end
    end
end

function stem = remove_state_suffix(stem)
    stem = regexprep(stem, '_state_?\d+$', '');
end

function name = rho_dir_name(rho)
    name = ['rho_' sprintf('%.6g', rho)];
end

% Notice!!: Before run this script, do "start_mtex" on the command window!!

clc
clear
close all

% Parameters
CS = crystalSymmetry.load('Al-Aluminum.cif');
SS = specimenSymmetry('triclinic');
N_base = 210;             % grains per variant (base only)
include_mirror_variants = true;
sd_values = 2:10;         % sigma 2..10 (degree)
textures = {'cube','goss','brass','copper','s'}; % 5 components

%% Case Settings
seed_category = 'seed4';  % category name for this random seed set
seed_offset = 4;          % seed set number
%%

% Output folders
ORI_DIR = fullfile(pwd, '..', '..', 'inputs', 'orientation');
csv_dir = fullfile(ORI_DIR, ['texture_' seed_category]);
png_dir = fullfile(ORI_DIR, ['polefigure_' seed_category]);
if ~exist(csv_dir, 'dir'); mkdir(csv_dir); end
if ~exist(png_dir, 'dir'); mkdir(png_dir); end

% Miller indices for pole figures
h = {Miller(1,1,1,CS)};

% Generate for all combinations
for ti = 1:numel(textures)
    tname = lower(textures{ti});

    % Get center orientation for the texture component using explicit
    % Bunge Euler angles (degree) for fcc rolling components to avoid
    switch tname
        case 'cube'   % {001}<100>
            eul_deg = [0, 0, 0];
        case 'goss'   % {110}<001>
            eul_deg = [0, 45, 0];
        case 'brass'  % {110}<112>
            eul_deg = [35, 45, 0];
        case 'copper' % {112}<111>
            eul_deg = [90, 35, 45];
        case 's'      % {123}<634>
            eul_deg = [59, 37, 63];
        otherwise
            error('Unsupported texture name: %s', tname);
    end

    % Build the center orientation explicitly from Euler (degree)
    ori0 = orientation('Euler', eul_deg(1)*degree, eul_deg(2)*degree, eul_deg(3)*degree, CS, SS);

    for sd = sd_values
        % Seed per combo for reproducibility but variability
        rng_seed = 1000 + seed_offset*10000 + sd*10 + ti;

        % Generate base orientations around the center orientation
        O_base = generate_orientations_mtex(ori0, sd, N_base, CS, SS, rng_seed);
        O_base = O_base(:);

        if include_mirror_variants
            % Explicit 4 variants: base + specimen mirror counterparts
            O_flipTD   = mirror_orientations_specimen(O_base, 'flipTD',   CS, SS); % TD -> -TD
            O_flipRD   = mirror_orientations_specimen(O_base, 'flipRD',   CS, SS); % RD -> -RD
            O_flipRDTD = mirror_orientations_specimen(O_base, 'flipRDTD', CS, SS); % RD,TD -> -RD,-TD

            O_all = [O_base(:); O_flipTD(:); O_flipRD(:); O_flipRDTD(:)];
        else
            O_all = O_base(:);
        end

        % Save orientations as CSV
        phi1_rad = O_all.phi1(:);
        Phi_rad  = O_all.Phi(:);
        phi2_rad = O_all.phi2(:);

        orientation_matrix = [phi1_rad(:), Phi_rad(:), phi2_rad(:)];

        csvname = sprintf('%s_sigma%d_%s.csv', tname, sd, seed_category);
        writematrix(orientation_matrix, fullfile(csv_dir, csvname));

        % Save pole figure as PNG (invisible figure for batch)
        f = figure('Visible','off');
        plotPDF(O_all, h, 'antipodal', 'all', 'MarkerSize', 3, 'markercolor', 'blue');
        set(f, 'Color', 'w');
        pngname = sprintf('polefigure_%s_sigma%d_%s.png', tname, sd, seed_category);
        pngpath = fullfile(png_dir, pngname);
        try
            exportgraphics(f, pngpath, 'Resolution', 300);
        catch
            print(f, '-dpng', '-r300', pngpath);
        end
        close(f);

        fprintf('Generated %s (CSV) -> %s\n', csvname, csv_dir);
        fprintf('Generated %s (PNG) -> %s\n', pngname, png_dir);
        if include_mirror_variants
            fprintf('length(O_base)=%d, length(O_flipTD)=%d, length(O_flipRD)=%d, length(O_flipRDTD)=%d, length(O_all)=%d\n', ...
                length(O_base), length(O_flipTD), length(O_flipRD), length(O_flipRDTD), length(O_all));
        else
            fprintf('length(O_base)=%d, length(O_all)=%d\n', length(O_base), length(O_all));
        end
    end
end

fprintf('All done. CSV in: %s\n', csv_dir);
fprintf('All done. PNG in: %s\n', png_dir);

%% Local helper (self-contained)
function O = generate_orientations_mtex(o0, sigma_deg, N, cs, ss, rng_seed)
    % Generate N orientations around a major orientation o0.
    % o0 can be [phi1, PHI, phi2] in degree or an MTEX orientation.

    if nargin < 4 || isempty(cs) || isempty(ss)
        cs = crystalSymmetry('cubic');
        ss = specimenSymmetry('triclinic');
    end
    if nargin >= 6 && ~isempty(rng_seed)
        rng(rng_seed, 'twister');
    else
        rng('shuffle');
    end

    if isnumeric(o0) && numel(o0) == 3
        o0 = orientation('Euler', o0(1)*degree, o0(2)*degree, o0(3)*degree, cs, ss);
    end

    O = repmat(o0, N, 1);

    for k = 1:N
        v = randn(3,1); v = v / norm(v);
        angle_rad = sigma_deg * randn() * (pi/180);
        try
            R = rotation('axis', v, 'angle', angle_rad);
        catch
            K = [    0, -v(3),  v(2);
                  v(3),     0, -v(1);
                 -v(2),  v(1),     0];
            Rmat = eye(3) + sin(angle_rad)*K + (1-cos(angle_rad))*(K*K);
            try
                R = rotation('matrix', Rmat);
            catch
                R = orientation(Rmat, cs, ss);
            end
        end
        try
            O(k) = R * o0;
        catch
            O(k) = o0 * R;
        end
    end
end

function O_out = mirror_orientations_specimen(O_in, mode, cs, ss)

    n = length(O_in);

    switch lower(mode)
        case 'fliptd'
            % Mirror in RD-ND plane: TD -> -TD
            M = diag([1, -1, 1]);
        case 'fliprd'
            % Mirror in TD-ND plane: RD -> -RD
            M = diag([-1, 1, 1]);
        case 'fliprdtd'
            % Both in-plane axes flipped
            M = diag([-1, -1, 1]);
        otherwise
            error('Unsupported mirror mode: %s', mode);
    end

    % Build the output orientation array explicitly, one element at a time.
    % This avoids MTEX collapsing a 3x3xN matrix input into a single orientation.
    O_out(1,n) = O_in(1);

    for i = 1:n
        g = O_in(i).matrix;
        g_new = M * g;

        % Recover proper rotation matrix for MTEX
        if det(g_new) < 0
            g_new = -g_new;
        end

        O_out(i) = orientation('matrix', g_new, cs, ss);
    end

    O_out = O_out(:);
end

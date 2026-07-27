function start_mtex
mtexDir = fullfile(pwd, '..', '..', 'src', 'mtex-5.11.1');
addpath(genpath(mtexDir));
startup_mtex;
end
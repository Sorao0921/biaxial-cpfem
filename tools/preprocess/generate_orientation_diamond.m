function records = generate_orientation_diamond(varargin)
% Five grains with random, within-model specimen-mirror variants (MTEX).
% Safe default: generate_orientation_diamond('Seeds',1:50)
% Grain order: center, upper right, upper left, lower left, lower right.
% Existing CSV or MAT output stops the entire batch before any data change.
% Overwrite=true first creates and verifies a ZIP backup (BackupDir defaults
% to OutputDir/_backups). Generation is staged; concurrent runs are locked.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
p = inputParser;
addParameter(p,'Seeds',1:50);
addParameter(p,'Degrees',[5 15 25]);
addParameter(p,'Textures',{'cube','goss','brass','copper','s'});
addParameter(p,'SamplesPerSeed',1);
addParameter(p,'VariantSampling','balanced');
addParameter(p,'OutputDir',fullfile(root,'inputs','orientation_diamond'));
addParameter(p,'MTEXDir',fullfile(root,'src','mtex-5.11.1'));
addParameter(p,'Overwrite',true);
addParameter(p,'BackupDir','');
parse(p,varargin{:}); opts = p.Results;
seeds=opts.Seeds(:)'; angles=opts.Degrees(:)';
textures=cellfun(@(t) lower(char(t)),cellstr(opts.Textures),'UniformOutput',false);
assert(islogical(opts.Overwrite) && isscalar(opts.Overwrite),'Overwrite must be logical true or false');
assert(~isempty(seeds) && all(isfinite(seeds)) && all(seeds>=0 & seeds==fix(seeds)) && numel(unique(seeds))==numel(seeds),'Invalid seeds');
assert(~isempty(angles) && all(isfinite(angles)) && all(angles>=0 & angles<45) && numel(unique(angles))==numel(angles),'Invalid degrees');
assert(isscalar(opts.SamplesPerSeed) && opts.SamplesPerSeed>=1 && opts.SamplesPerSeed==fix(opts.SamplesPerSeed),'Invalid sample count');
assert(any(strcmp(opts.VariantSampling,{'balanced','independent'})),'Invalid variant sampling');
assert(~isempty(textures) && numel(unique(textures))==numel(textures),'Invalid textures');
for i=1:numel(textures), reference_euler(textures{i}); end

% Protect the complete batch, including the shared MAT record.
relativeFiles={};
for seed=seeds
 for theta=angles
  for ti=1:numel(textures)
   for sample=1:opts.SamplesPerSeed
    relativeFiles{end+1}=csv_path('',seed,theta,textures{ti},sample,opts.SamplesPerSeed); %#ok<AGROW>
   end
  end
 end
end
relativeFiles{end+1}='generation_manifest.mat';
outputs=cellfun(@(f) fullfile(opts.OutputDir,f),relativeFiles,'UniformOutput',false);
preflight_outputs(outputs,opts.Overwrite);
if ~isfolder(opts.OutputDir),mkdir(opts.OutputDir);end
lockDir=fullfile(opts.OutputDir,'.diamond_generation.lock');
[locked,lockMessage,lockId]=mkdir(lockDir);
if ~locked || ~isempty(lockId)
 error('diamond:OutputLocked',['Another generation may be using this output folder: %s. ' ...
  'Remove the lock only after confirming no generation is running. %s'],lockDir,lockMessage);
end
lockCleanup=onCleanup(@() remove_tree(lockDir)); %#ok<NASGU>
% Recheck after acquiring the lock to cover simultaneous launches.
preflight_outputs(outputs,opts.Overwrite);
existed=cellfun(@isfile,outputs);
originalBytes=cell(size(outputs));
for i=find(existed),originalBytes{i}=file_bytes(outputs{i});end
manifest=fullfile(opts.OutputDir,'generation_manifest.mat');
previous=struct([]);
if existed(end)
 old=load(manifest,'records');
 if ~isfield(old,'records'),error('diamond:InvalidManifest','Existing MAT record has no records field: %s',manifest);end
 previous=reshape(old.records,1,[]);
end
last_backup='';
if opts.Overwrite && any(existed)
 backupDir=opts.BackupDir;
 if isempty(backupDir),backupDir=fullfile(opts.OutputDir,'_backups');end
 last_backup=backup_outputs(outputs,relativeFiles,existed,originalBytes,opts.OutputDir,backupDir);
 fprintf('Verified backup: %s\n',last_backup);
end
% Produce all CSVs and the MAT file here, and publish only after validation.
[~,stageName]=fileparts(tempname(opts.OutputDir));
stageDir=fullfile(opts.OutputDir,['.diamond_stage_' stageName]);
mkdir(stageDir);
stageCleanup=onCleanup(@() remove_tree(stageDir)); %#ok<NASGU>
initialize_geometry_mtex(opts.MTEXDir);
cs=crystalSymmetry('m-3m'); ss=specimenSymmetry('triclinic');
symmetry_matrices=matrix(cs.properGroup.rot);
variant_names={'base','flipRD','flipTD','flipRDTD'};
% FCC centrosymmetric lattice: det(M)*M is the proper representative.
Q=cat(3,eye(3),diag([1 -1 -1]),diag([-1 1 -1]),diag([-1 -1 1]));
n=numel(seeds)*numel(angles)*numel(textures)*opts.SamplesPerSeed;
newRecords=struct([]); k=0;
for seed=seeds
 for sample=1:opts.SamplesPerSeed
  stream=RandStream('mt19937ar','Seed',mod(double(seed)*104729+double(sample)*13007+1009,4294967295));
  axes=randn(stream,5,3); axes=axes./sqrt(sum(axes.^2,2));
  if strcmp(opts.VariantSampling,'balanced')
   variants=[1:4 randi(stream,4)]; variants=variants(randperm(stream,5));
  else
   variants=randi(stream,4,1,5);
  end
  for theta=angles
   for ti=1:numel(textures)
    texture=textures{ti}; e0=reference_euler(texture);
    reference=orientation.byEuler(e0(1)*degree,e0(2)*degree,e0(3)*degree,cs,ss);
    R0=matrix(reference); ori=repmat(reference,5,1);
    matrices=zeros(3,3,5); refs=matrices; sampleAxes=zeros(5,3); offsets=zeros(5,1);
    for g=1:5
     d=rotation.byAxisAngle(vector3d(axes(g,1),axes(g,2),axes(g,3)),theta*degree);
     base=d*reference;
     matrices(:,:,g)=Q(:,:,variants(g))*matrix(base);
     refs(:,:,g)=Q(:,:,variants(g))*R0;
     sampleAxes(g,:)=(Q(:,:,variants(g))*axes(g,:)')';
     ori(g)=orientation.byMatrix(matrices(:,:,g),cs,ss);
     reflectedReference=orientation.byMatrix(refs(:,:,g),cs,ss);
     offsets(g)=angle(ori(g),reflectedReference)/degree;
    end
    assert(max(abs(offsets-theta))<1e-6,'Reference-angle validation failed');
    [phi1,Phi,phi2]=Euler(ori);
    euler=[mod(phi1(:),2*pi),Phi(:),mod(phi2(:),2*pi)];
    f=csv_path(stageDir,seed,theta,texture,sample,opts.SamplesPerSeed);
    folder=fileparts(f); if ~isfolder(folder),mkdir(folder);end
    writematrix(euler,f,'Delimiter',',');
    pairs=[1 2;1 3;1 4;1 5;2 3;2 5;3 4;4 5];
    raw=zeros(3,3,8); minimum=raw; neighborAngles=zeros(1,8); symmetryIndex=zeros(1,8);
    for j=1:8
     a=matrices(:,:,pairs(j,1));b=matrices(:,:,pairs(j,2));raw(:,:,j)=b*a';
     best=-inf; bestIndex=1;
     for si=1:size(symmetry_matrices,3)
      candidate=b*symmetry_matrices(:,:,si)*a'; tr=trace(candidate);
      if tr>best,best=tr;bestIndex=si;minimum(:,:,j)=candidate;end
     end
     neighborAngles(j)=acos(max(-1,min(1,(best-1)/2)))/degree;
     symmetryIndex(j)=bestIndex;
     assert(abs(neighborAngles(j)-angle(ori(pairs(j,1)),ori(pairs(j,2)))/degree)<1e-6,'Neighbor-angle validation failed');
    end
    k=k+1;
    rec=struct('seed',seed,'degree',theta,'texture',texture,'sample',sample,...
     'variant_sampling',opts.VariantSampling,'variant_ids',variants,...
     'axes_before_mirror',axes,'axes_sample',sampleAxes,'euler_rad',euler,...
     'R_crystal_to_sample',matrices,'reference_R_variant',refs,...
     'reference_euler_deg',e0,'reference_offset_deg',offsets,...
     'neighbor_ids',2:5,'neighbor_angle_deg',neighborAngles(1:4),...
     'neighbor_raw_sample_rotation',raw(:,:,1:4),'neighbor_min_sample_rotation',minimum(:,:,1:4),...
     'neighbor_symmetry_operator_index',symmetryIndex(1:4),...
     'grain_pair_ids',pairs,'pair_angle_deg',neighborAngles,...
     'pair_raw_sample_rotation',raw,'pair_min_sample_rotation',minimum,...
     'pair_symmetry_operator_index',symmetryIndex);
    if k==1,newRecords=rec;else,newRecords(k)=rec;end %#ok<AGROW>
   end
  end
 end
end
assert(k==n,'Unexpected case count');
% One MAT record for the entire batch; preserve metadata for unselected cases.
records=newRecords;
if ~isempty(previous)
 oldKeys=arrayfun(@case_key,previous,'UniformOutput',false);
 newKeys=arrayfun(@case_key,newRecords,'UniformOutput',false);
 [present,loc]=ismember(newKeys,oldKeys);
 previous(loc(present))=newRecords(present);
 records=[previous newRecords(~present)];
end
schema='diamond_mtex_mixed_mirror_v1';
last_request=opts; matlab_version=version;
save(fullfile(stageDir,'generation_manifest.mat'),'records','symmetry_matrices','variant_names','Q','schema','last_request','matlab_version','last_backup','-v7');
% Abort without publishing if any target changed since preflight/backup.
for i=1:numel(outputs),assert_unchanged(outputs{i},existed(i),originalBytes{i});end
for i=1:numel(outputs)
 assert_unchanged(outputs{i},existed(i),originalBytes{i});
 parent=fileparts(outputs{i});if ~isfolder(parent),mkdir(parent);end
 [ok,message]=movefile(fullfile(stageDir,relativeFiles{i}),outputs{i},'f');
 if ~ok,error('diamond:PublishFailed','Cannot publish %s: %s. Backup: %s',outputs{i},message,last_backup);end
end
clear stageCleanup lockCleanup;
fprintf('Generated %d five-grain CSVs with %s within-model mirror variants.\n',n,opts.VariantSampling);
fprintf('MTEX manifest: %s\n',manifest);
end

function f=csv_path(root,seed,theta,texture,sample,samples)
if samples>1,stem=sprintf('%s_case%02d',texture,sample);else,stem=texture;end
f=fullfile(root,sprintf('seed_%d',seed),sprintf('deg_%g',theta),[stem '.csv']);
end

function key=case_key(r)
key=sprintf('%d|%.12g|%s|%d',r.seed,r.degree,r.texture,r.sample);
end

function e=reference_euler(name)
switch lower(char(name))
 case 'cube',e=[0 0 0];
 case 'goss',e=[0 45 0];
 case 'brass',e=[35 45 0];
 case 'copper',e=[90 35 45];
 case 's',e=[59 37 63];
 otherwise,error('Unsupported texture: %s',char(name));
end
end

function initialize_geometry_mtex(folder)
% Only geometry/option code is needed. Do not invoke optional MEX/NFFT checks.
assert(isfolder(folder),'MTEX folder not found: %s',folder);
if exist('orientation','class')~=8
 addpath(folder);
 addpath(genpath(fullfile(folder,'geometry')));
 addpath(genpath(fullfile(folder,'tools')));
 setMTEXpref('mtexPath',folder);
 global useBSXFUN;useBSXFUN=false;
end
setMTEXpref('EulerAngleConvention','Bunge');
end

function preflight_outputs(files,overwrite)
for i=1:numel(files)
 if isfolder(files{i}),error('diamond:OutputDirectory','Output filename is a directory: %s',files{i});end
end
existing=files(cellfun(@isfile,files));
if ~overwrite && ~isempty(existing)
 listing=strjoin(existing(1:min(10,numel(existing))),newline);
 error('diamond:OutputExists',['%d output files already exist, including CSV/MAT records. No data changed.\n%s\n' ...
  'Use Overwrite=true only to intentionally replace them; a verified ZIP backup will be created.'],numel(existing),listing);
end
end

function bytes=file_bytes(file)
fid=fopen(file,'rb');
if fid<0,error('diamond:ReadFailed','Cannot read protected file: %s',file);end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes=fread(fid,inf,'*uint8');
end

function assert_unchanged(file,existed,bytes)
if existed
 if ~isfile(file) || ~isequal(file_bytes(file),bytes)
  error('diamond:OutputChanged','Protected output changed during generation; refusing replacement: %s',file);
 end
elseif isfile(file) || isfolder(file)
 error('diamond:OutputChanged','A new output appeared during generation; refusing replacement: %s',file);
end
end

function archive=backup_outputs(files,relativeFiles,existed,bytes,root,backupDir)
if isfile(backupDir),error('diamond:BackupFailed','Backup directory is a file: %s',backupDir);end
if ~isfolder(backupDir)
 [ok,message]=mkdir(backupDir);
 if ~ok,error('diamond:BackupFailed','Cannot create backup directory: %s',message);end
end
[~,uniqueName]=fileparts(tempname(backupDir));
archive=fullfile(backupDir,['diamond_mtex_' datestr(now,'yyyymmdd_HHMMSS_FFF') '_' uniqueName '.zip']);
if isfile(archive),error('diamond:BackupFailed','Backup filename already exists: %s',archive);end
checkDir=tempname;mkdir(checkDir);
cleanup=onCleanup(@() remove_tree(checkDir)); %#ok<NASGU>
try
 zip(archive,relativeFiles(existed),root);
 unzip(archive,checkDir);
 for i=find(existed)
  copy=fullfile(checkDir,relativeFiles{i});
  if ~isfile(copy) || ~isequal(file_bytes(copy),bytes{i})
   error('diamond:BackupFailed','ZIP backup verification failed for %s',files{i});
  end
 end
catch failure
 if isfile(archive),delete(archive);end
 rethrow(failure);
end
end

function remove_tree(folder)
if isfolder(folder),rmdir(folder,'s');end
end

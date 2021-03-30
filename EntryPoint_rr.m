function EntryPoint_rr(data_dir)

mex -setup C++

homepath = '/om/user/rishir/lib/';
kilosort_suffix = 'Kilosort'

addpath(genpath([homepath,kilosort_suffix])) % path to kilosort folder
addpath(genpath([homepath,'npy-matlab'])) % for converting to Phy

ks_output_dname = '/ks3_output/';

display(data_dir)
rootZ = data_dir; % the raw data binary file is in this folder
rootH = data_dir; % path to temporary binary file (same size as data, should be on fast SSD)
rootKS = strcat(rootZ, ks_output_dname);
if isfolder(rootKS) == 0
    mkdir(rootKS);
end


pathToYourConfigFile = [homepath, kilosort_suffix, '/configFiles/']; % take from Github folder and put it somewhere else (together with the master_file)
chanMapFile = 'chanMap_vprobe64.mat';
run([homepath, kilosort_suffix, '/CUDA/mexGPUall.m']);
run(fullfile(pathToYourConfigFile, 'config_rr_vprobe64.m'))

ops.fproc   = fullfile(rootH, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(pathToYourConfigFile, chanMapFile);

opt_datashift.NrankPC = 6;
opt_datashift.dd  = 50; % binning width across Y (um)
opt_datashift.spkTh = 10; % same as the usual "template amplitude", but for the generic templates

%%%
ops.NchanTOT  = 64;
ops.trange    = [0 Inf]; % time range to sort

%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', rootZ)

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option.

% main parameter changes from Kilosort2.5 to v3.0
ops.Th       = [9 9];

% find the binary file
fs          = [dir(fullfile(rootZ, '*.bin')) dir(fullfile(rootZ, '*.dat'))];
ops.fbinary = fullfile(rootZ, fs(1).name);

rez                = preprocessDataSub(ops);
rez                = datashift2(rez, 1, opt_datashift);

[rez, st3, tF]     = extract_spikes(rez);

rez                = template_learning(rez, tF, st3);

[rez, st3, tF]     = trackAndSort(rez);

rez                = final_clustering(rez, tF, st3);

rez                = find_merges(rez, 1);

rootZ = fullfile(rootZ, 'kilosort3');
mkdir(rootZ)
rezToPhy2(rez, rootZ);
%%%



%
%pathToYourConfigFile = [homepath, kilosort_suffix, '/configFiles/']; % take from Github folder and put it somewhere else (together with the master_file)
%chanMapFile = 'chanMap_vprobe64.mat';
%run([homepath, kilosort_suffix, '/CUDA/mexGPUall.m']);
%run(fullfile(pathToYourConfigFile, 'config_rr_vprobe64.m'))
%
%
%ops.fproc   = fullfile(rootH, 'temp_wh.dat'); % proc file on a fast SSD
%ops.chanMap = fullfile(pathToYourConfigFile, chanMapFile);
%
%
%%% this block runs all the steps of the algorithm
%fprintf('Looking for data inside %s \n', rootZ)
%%
%%% is there a channel map file in this folder?
%%fs = dir(fullfile(rootZ, 'chan*.mat'));
%%if ~isempty(fs)
%%    ops.chanMap = fullfile(rootZ, fs(1).name);
%%end
%
%% find the binary file
%fs          = [dir(fullfile(rootZ, '*.bin')) dir(fullfile(rootZ, '*.dat'))];
%ops.fbinary = fullfile(rootZ, fs(1).name);
%
%%%
%
%disp('preprocessing...')
%[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
%disp('fit templates..')
%rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
%disp('fullMPMU-ing...')
%rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)
%disp('done MPMUing')
%% AutoMerge. rez2Phy will use for clusters the new 5th column of st3 if you run this)
%%     rez = merge_posthoc2(rez);
%
%disp('Saving final results in rez  \n')
%fname = fullfile(rootKS, 'rez2.mat');
%save(fname, 'rez', '-v7.3');
%
%
%
%disp('save python')
%% save python results file for Phy
%rezToPhy(rez, rootKS);
%
%disp('delete temp')
%% remove temporary file
%delete(ops.fproc);
%disp('done deleting temp file')

end

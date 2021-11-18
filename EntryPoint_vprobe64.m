function EntryPoint_vprobe64(data_dir)

mex -setup C++

homepath = '/om/user/rishir/lib/';

kilosort_suffix = 'Kilosort'

addpath(genpath([homepath,kilosort_suffix])) % path to kilosort folder
addpath(genpath([homepath,'npy-matlab'])) % for converting to Phy
high_cutoff = 0; % by default off

if high_cutoff == 1
    ks_output_dname = '/ks3_output_th9/';
    ops_th_2 = 9;
else
    ks_output_dname = '/ks3_output/';
    ops_th_2 = 4;
end
display(data_dir)

rootZ = data_dir; % the raw data binary file is in this folder
rootH = strrep(data_dir,'/om4/group/jazlab/rishir/data/', '/om/user/rishir/data/'); % path to temporary binary file (same size as data, should be on fast SSD)
if isfolder(rootH) == 0
    mkdir(rootH);
end

rootKS = strcat(rootZ, ks_output_dname);
if isfolder(rootKS) == 0
    mkdir(rootKS);
end

pathToYourConfigFile = [homepath, kilosort_suffix, '/configFiles/']; % take from Github folder and put it somewhere else (together with the master_file)
chanMapFile = 'chanMap_vprobe64.mat';

%run([homepath, kilosort_suffix, '/CUDA/mexGPUall.m']);
run(fullfile(pathToYourConfigFile, 'config_rr_vprobe64.m'))

ops.fproc   = fullfile(rootH, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(pathToYourConfigFile, chanMapFile);

opt_datashift.NrankPC = 6;
opt_datashift.dd  = 50/4; % binning width across Y (um)
opt_datashift.spkTh = 10; % same as the usual "template amplitude", but for the generic templates

%%%
ops.NchanTOT  = 64;
ops.trange    = [0 Inf]; % time range to sort

%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', rootZ)

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 0; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option.
% rishi edit: nblocks was 5

% main parameter changes from Kilosort2.5 to v3.0
ops.Th       = [9 ops_th_2];
% rishi edit: was [9 9]

% find the binary file
fs          = [dir(fullfile(rootZ, '*.bin')) dir(fullfile(rootZ, '*.dat'))];
ops.fbinary = fullfile(rootZ, fs(1).name);

rez                = preprocessDataSub(ops);                        %preProcess/preprocessDataSub
rez                = datashift2(rez, 1, opt_datashift);             %preProcess/datashift2

[rez, st3, tF]     = extract_spikes(rez);                           %clustering/extract_spikes

rez                = template_learning(rez, tF, st3);

[rez, st3, tF]     = trackAndSort(rez);

rez                = final_clustering(rez, tF, st3);

rez                = find_merges(rez, 1);


rezToPhy2(rez, rootKS);

% rishi: diary to keep track of option specs
diary_filename = sprintf('%s/diary_%s.txt', rootKS,  datestr(now, 'mm-dd-yy'));
diary(diary_filename);
disp(ops);
disp(opt_datashift);
diary off;

% delete temp_wh.dat, it's just a duplicate
delete(ops.fproc)

end


% If you use the source code or impliment pcStream, please cite the following paper:
% Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

clc
display('Loading Dataset')
load KDD_Sample_Dataset

driftThreshold = 4; %Drift threshold (number of stds away to say that not likeli part of the model)
maxDriftSize = 20; %Number of instances in a row that have "drifted"
percentVarience = 0.98;
modelMemSize = 100;

% run pca stream clustering
display('Begining pcStream...')
[ modelCollection, outLabels, TransitionCounts] = pcStream(dataset, driftThreshold, maxDriftSize,percentVarience,modelMemSize);
MarkovModel = TransitionCounts./repmat(sum(TransitionCounts,2),1,length(TransitionCounts));

display(['Adjusted Rand Index: ' num2str(RandIndex(labels,outLabels))]) %a measure of clustering accuracy compared to some ground truth.

display(['Observation x belongs to cluster: ' num2str( predictObs( dataset(end,:), modelCollection))])
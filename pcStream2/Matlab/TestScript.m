% Please cite:
% Mirsky, Yisroel, et al. "pcstream: A stream clustering algorithm for dynamically detecting and managing temporal contexts." Pacific-Asia Conference on Knowledge Discovery and Data Mining. Springer International Publishing, 2015.
% Mirsky, Y., Halpern, T., Upadhyay, R. and Toledo, S., 2016, Enhanced Situation Space Mining for Data Streams, the 32nd ACM Symposium on Applied Computing

load SCA_data
X = zscore(X_SCA);
Y = Y_SCA;

phi = 1.0; %Situation space fuziness - a threshold determing the number of stds away to say that not likeli part of the situation space (note, needs to be normalizes to the number of dimensions of the dataset)
t_min = 70; %minimum duration of a situation
varPC = .8; %percent of varience to retain in each PCA model
modelMem = 1000; %model memory capacity
initModelSize = t_min + 1; %the number of instaces to take as the inital model
display('Begin: Running pcStream');

start = tic;
[modelCollection1,numSituationSpaces1, Labels1] = pcStream(X, phi, t_min,varPC,modelMem,initModelSize);
fin1 = toc(start);
Adj_1 = adjrand(Y_SCA+1,Labels1);

display('Begin: Running pcStream with IPCA');
start = tic;
[modelCollection2,numSituationSpaces2, Labels2] = pcStream_IPCA(X, phi, t_min,varPC,initModelSize);
fin2 = toc(start);
Adj_2 = adjrand(Y_SCA+1,Labels2);

display('Begin: Running pcStream2');
start = tic;
[modelCollection3,numSituationSpaces3, Labels3] = pcStream2(X, phi, t_min,varPC,modelMem);
fin3 = toc(start);
Adj_3 = adjrand(Y_SCA+1,Labels3);

display('done:')
display(['pcStream took ' num2str(fin1) ' seconds to run and got an Adjusted Rand Index (accuracy score) of ' num2str(Adj_1)])
display(' ')
display(['pcStream with IPCA took ' num2str(fin2) ' seconds to run and got an Adjusted Rand Index (accuracy score) of ' num2str(Adj_2)])
display('Note: this ARI can be improved if the approprate paramaters (phi, t_min) are set')
display(' ')
display(['pcStream2 took ' num2str(fin3) ' seconds to run and got an Adjusted Rand Index (accuracy score) of ' num2str(Adj_3)])

% Note: a 'label' assigned to an observation is the index to the situation
% space model in modelCollection which was assigned to the observation.
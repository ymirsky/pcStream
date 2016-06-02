function [ modelCollection, Labels, A] = pcStream( X, driftThreshold, maxDriftSize, Pvar, modelMemSize, initModelSize)
%Trains pcStream on the dataset (stream) X given the paramaters
%driftThreshold, maxDriftSize, Pvar, modelMemSize, initModelSize.

%Note: This implimentation performs significantly slower than the R and python
%implimentaitons.

%Input:
% X is a m-by-n matrix with m instances and n feature dimensions.
% driftThreshold is the (max score) to detect a drifting instance
% maxDriftSize is the number of consequtive drifters needed to be considured a new cluster
% Pvar is the percent of varience (0.0-1.0) each model should retain -typically set to 0.98-0.99
% modelMemSize is the number of observations retained in each model
% initModelSize (optional) defines the initial number of observations to take as the first model. Default = maxDriftSize


%Output:
% modelCollection is a cell collection of model structures for each of the clusters (X,A,mu). 
% Labels is a vector of m labels (cluster assingments)
% A is a numClusters-by-numClusters matrix of observed transitions between
% each cluster. I.e., A(i,j) is the number of transisions observed from
% cluster i to cluster j. A can be used to compute a Markov Chain.

% If you use the source code or impliment pcStream, please cite the following paper:
% Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

%%%%%%%%%%%%%%%%%%
%init
dim = size(X,2); %dimensionality of the dataset
modelCollection = {};
numClusters = 0;
driftBuffer = zeros(maxDriftSize,dim);
numDrifters = 0;
Labels = zeros(size(X,1),1);
numTics = size(X,1);
A = []; % the transition matrix. Value Aij is the number of transisitons tha thave occured from Cluster i to j

% Initial model
if exist('initModelSize')
    if initModelSize > modelMemSize
        len = modelMemSize;
    else
        len = initModelSize;
    end
else
    len = maxDriftSize;
end
numClusters = numClusters + 1;
modelCollection{numClusters} = ModelCluster_pcS(X(1:len,:),Pvar);
Labels(1:len) = 1;
LabelCounter = len+1;
CurCntxt = 1;
A(1,1) = len; % add first model to transition matrix;

% Method1: for each new instance, vote, then add matching model -else make new model
tic
for t = (len+1):numTics 
    if mod(t,10000)==0
        display(['t:' num2str(t) ' numClusters:' num2str(numClusters) ' BlockTime:' num2str(toc)]);
        tic
    end
    %Calculate likelihood scores
    scores = zeros(1,numClusters);
    for i = 1:numClusters
        %convert X to the  from standard basis to new one:
        Xtag = (X(t,:)-modelCollection{i}.centroid); % the points after zero-meaned
        transPoint = Xtag*modelCollection{i}.coeff;
        scores(i) = transPoint*transPoint';
    end
    scores = sqrt(scores);
    
    %Find Most likely model
    [~,bestModl] = min(scores);
    %Detect drift
    if min(scores) > driftThreshold
       % Add the drifter to a buffer
       numDrifters = numDrifters + 1;
       driftBuffer(numDrifters,:) = X(t,:);
       
       %Check if the buffer is full (has enough to make a substantial model
       if numDrifters == maxDriftSize
           % Make new model based on the bufferd instances
           numClusters = numClusters+1;
           modelCollection{numClusters} = ModelCluster_pcS(driftBuffer,Pvar);
           Labels(LabelCounter:(LabelCounter+maxDriftSize-1)) = numClusters; % assign labels to these instances
           LabelCounter=LabelCounter+maxDriftSize;
           
           A(numClusters,:) = 0; A(:,numClusters) = 0; % make space for new Cluster in the transition matrix;
           A(CurCntxt,numClusters) = 1;
           CurCntxt = numClusters; %update the current model to this new one
           A(CurCntxt,CurCntxt) = numDrifters-1;


           % Clear the buffer
           driftBuffer = zeros(maxDriftSize,dim);
           numDrifters = 0;
       end
    else %there was no drift
        
        % Clear driftBuffer (consistency broken): assign all contents to
% TODO (test): half point goto curmodl, half goes to best model (and then fix the drift buffer dump (in full drift) accordingly)
        if numDrifters > 0
            M = [modelCollection{CurCntxt}.origInstances;driftBuffer(1:numDrifters,:)]; % add new instnaces to bottom
            M = M((size(M,1)-min([modelMemSize,size(M,1)])+1):end,:); % take the memSize most recent instnaces
            modelCollection{CurCntxt} = ModelCluster_pcS(M,Pvar);
            Labels(LabelCounter:(LabelCounter+numDrifters-1)) = CurCntxt;
            LabelCounter=LabelCounter+numDrifters;
            
            A(CurCntxt,CurCntxt) = A(CurCntxt,CurCntxt) + numDrifters;
            
           % Clear the buffer
           driftBuffer = zeros(maxDriftSize,dim);
           numDrifters = 0;
        end
        
        % Assign this instance to its most similar model (update that model)
        M = [modelCollection{bestModl}.origInstances;X(t,:)]; % add new instnaces to bottom
        M = M((size(M,1)-min([modelMemSize,size(M,1)])+1):end,:); % take the memSize most recent instnaces
        modelCollection{bestModl} = ModelCluster_pcS(M,Pvar);
        Labels(LabelCounter) = bestModl;
        LabelCounter=LabelCounter+1;
        
        A(CurCntxt,bestModl) = A(CurCntxt,bestModl) + 1;
        CurCntxt = bestModl; %set the "current" model to this model
    end
    
    
    
    
end

% empty buffer last time:
if numDrifters > 0
            M = [modelCollection{CurCntxt}.origInstances;driftBuffer(1:numDrifters,:)]; % add new instnaces to bottom
            M = M((size(M,1)-min([modelMemSize,size(M,1)])+1):end,:); % take the memSize most recent instnaces
            modelCollection{CurCntxt} = ModelCluster_pcS(M,Pvar);
            Labels(LabelCounter:(LabelCounter+numDrifters-1)) = CurCntxt;
            A(CurCntxt,CurCntxt) = A(CurCntxt,CurCntxt) + numDrifters;
end


end


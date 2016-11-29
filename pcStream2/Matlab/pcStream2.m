function [ modelCollection,numSS, Labels] = pcStream2( X, phi, t_min, Pvar, modelMemSize)
% Matlab implimentation of pcStream2. Please cite:
% Mirsky, Y., Halpern, T., Upadhyay, R. and Toledo, S., 2016
% Enhanced Situation Space Mining for Data Streams, the 32nd ACM Symposium on Applied Computing

%Input:
% X is a m-by-n matrix with m instances and n feature dimensions.
% phi is the (max score) to detect a drifting instance
% t_min is the number of consequtive drifters needed to trigger a new
% Pvar is the percent of variance to retain in each model (e.g. 0.98)
% modelMemSize is the number of instaces to retain in each model's memory buffer
% initModelSize, is the number of instaces to take from the start of X to initilize the firt model (e.g., t_min + 1)

%Output:
% modelCollection is a cell collection of the models which each capture a situationspace detected from X. 
% numSS is the number of situation spaces detect (the size of the modelCollection)
% Labels the Situation space IDs assigned to each instace in X as they arrive. Note, this algorithm is a one-pass online algorithm. 

% init
dim = size(X,2); %dimensionality of the dataset
maxModels = 1000; %the maximun number of models to detect (any more will not be added)
modelCollection = cell(1,maxModels);
numSS = 0;
B = {};
Labels = zeros(size(X,1),1);
numTics = size(X,1);

% init first model
numSS = numSS + 1;
modelCollection{numSS} = ModelSituationSpace_pcS(X(1:t_min,:),Pvar);
Labels(1:t_min) = 1;
LabelCounter = t_min+1;
CurMdl = 1;

tic
for t = (t_min+1):numTics
    if mod(t,1000)==0
        display(['t:' num2str(t) ' num Situation Spaces:' num2str(numSS) ' BlockTime:' num2str(toc)]);
        tic
    end
    x_t = X(t,:);
    
    %%% PUSH
    % check x_t's distance
    scores = zeros(1,numSS);
    Xtag = (x_t-modelCollection{CurMdl}.centroid); % the points after zero-meaned
    transPoint = Xtag*modelCollection{CurMdl}.coeff;
    scores(CurMdl) = sqrt(transPoint*transPoint');
    
    if scores(CurMdl) <= phi
        u_in = {x_t, scores(CurMdl), CurMdl};
    else
        for i = 1:numSS
            if i ~= CurMdl
                 Xtag = (x_t-modelCollection{i}.centroid); % the points after zero-meaned
                 transPoint = Xtag*modelCollection{i}.coeff;
                 scores(i) = sqrt(transPoint*transPoint');
            end
        end
        %find the situation space which is closest to x_t
        [bestScore,bestMdl] = min(scores);
        CurMdl = bestMdl;
        u_in = {x_t, bestScore, CurMdl};
    end
    B = [u_in ; B]; %push

    %%% PROCESS
    if size(B,1) > t_min
        u_out = B(t_min + 1,:); %pop
        B(t_min+1,:) = [];
        M = [u_out{1};modelCollection{u_out{3}}.origInstances]; % add new instnaces to bottom
        M = M(1:min([modelMemSize,size(M,1)]),:); % take the memSize most recent instnaces
        modelCollection{u_out{3}} = ModelSituationSpace_pcS(M,Pvar);
        
        Labels(LabelCounter) = u_out{3};
        LabelCounter = LabelCounter + 1;
    end
    
    %%% DETECT
    if size(B,1) == t_min
        scores = cell2mat(B(:,2));
        O = scores > phi; %the outliers
        if O(1) && O(t_min) && (sum(O) > t_min/2)
           numSS = numSS+1;
           M = cell2mat(B(:,1));
           B = {};
           modelCollection{numSS} = ModelSituationSpace_pcS(M,Pvar);
           CurMdl = numSS;
           
           Labels(LabelCounter:(LabelCounter+t_min-1)) = numSS;
           LabelCounter = LabelCounter + t_min;
        end
    end   
end

% empty buffer last time: (so that we have all the labels)
if size(B,1) > 0
    for b = fliplr(1:size(B,1))
        u_out = B(b,:); 
        M = [u_out{1};modelCollection{u_out{3}}.origInstances]; % add new instnaces to bottom
        M = M(1:min([modelMemSize,size(M,1)]),:); % take the memSize most recent instnaces
        modelCollection{u_out{3}} = ModelSituationSpace_pcS(M,Pvar);
        Labels(LabelCounter) = u_out{3};
        LabelCounter = LabelCounter + 1;
    end
end

modelCollection = modelCollection(1:numSS);

end


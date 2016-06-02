function [Labels, Scores] = predictObs(X, modelCollection)
% takes a m-by-n collection of observations and associates their cluster
% labels based on the given pcStream modelCollection. Scores(i,j) is the
% Mahalanobis distance of observation i to cluster j

m = size(X,1);
numModels = length(modelCollection);
Labels = zeros(m,1);
Scores = zeros(m,numModels);

parfor i = 1:m
    scores = zeros(1,numModels);
    for ii = 1:numModels
        %convert X to the  from standard basis to new one:
        Xtag = (X(i,:)-modelCollection{ii}.centroid); % the points after zero-meaned
        transPoint = Xtag*modelCollection{ii}.coeff;
        scores(ii) = transPoint*transPoint';
    end
    scores = sqrt(scores);
    
    %Find Most likely model
    [~,bestModl] = min(scores);
    Labels(i) = bestModl;
    Scores(i,:) = scores;
end
function [ model ] = ModelCluster_pcS( X , Pvar)
%computes a pcStream cluster model from a collection of observations X, while retaining Pvar percent of the varience.

% X is a m x n matrix with m instances and n features. 
% returns a model (structure) containing:
%   coeff: the priciple components of X
%   W: the respective wieghts (eigenvalues). 
%   cent is the centroid of the PCA basis PC. 

% If you use the source code or impliment pcStream, please cite the following paper:
% Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

[coeff,~,W] = princomp(X);
cent = mean(X); %cluster's centroid
conts = W./sum(W); %percent that each dim contrivutes to the total variation

%only retain the PCs that contain the Pvar percent of varience of the data.
if Pvar == 1
    model.numPCs = length(W);
else
    model.numPCs = find(cumsum(conts) >= Pvar,1);
    
    if isempty(model.numPCs)
        model.numPCs = 1;
    end
end

model.variences = W;

Wtag = W(1:model.numPCs);
D = sqrt(Wtag);
C = coeff(:,1:model.numPCs);
model.coeff = C*diag(D);


%model.contributions = conts;
model.centroid = cent;

model.origInstances = X;

end


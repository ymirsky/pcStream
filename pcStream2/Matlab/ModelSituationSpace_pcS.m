function [ model ] = ModelSituationSpace_pcS( X , Pvar)
%Recieves a set of observations X and returns a PCA represenation model of it.

% X is a m x n matrix with m instances and n features. 
% returns a model (structure) containing:
%   coeff: the priciple components of X
%   W: the respective wieghts (eigenvalues). 
%   cent is the centroid of the PCA basis PC. 

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
D = sqrt(Wtag); %the added epsilon prevents the rounding to 0
C = coeff(:,1:model.numPCs);
model.coeff = C*diag(D);

%model.contributions = conts;
model.centroid = cent;
model.origInstances = X;

end


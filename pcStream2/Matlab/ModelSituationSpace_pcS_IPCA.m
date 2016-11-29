function [ model ] = ModelSituationSpace_pcS_IPCA( X , Pvar)
%Recieves a set of observations X and returns a JIT-PCA represenation model of it.

% X is a m x n matrix with m instances and n features. 
% returns a model (structure) containing:
%   coeff: The Mahalanobis transformation matrix. 
%   tals: The IPCA model for incremental updates
%   centroid: the incrementally updated centroid
    
ipca.rho=Pvar*100;
u=[];
s=[];
approx_rank=[];
total_mass=[];
counter=[];
to_pad=0;
used=0;
t=1;
m = size(X,1);
model.centroid = mean(X);
X=X-ones(m,1)*model.centroid; % zero mean X
% u,s,total_mass,counter,model_base,model_var,approx_rank,used,method
[ipca.u,ipca.s,ipca.total_mass,ipca.counter,ipca.model_base,ipca.model_var,ipca.approx_rank,ipca.used,ipca.t]=tals_exterior_for_pca...
    (X,approx_rank,u,s,total_mass,counter,ipca.rho,used,t);

model.ipca = ipca;
model.numPCs = length(ipca.model_var);

D = sqrt(ipca.model_var); %the added epsilon prevents the rounding to 0
model.coeff = ipca.model_base*diag(D);

end


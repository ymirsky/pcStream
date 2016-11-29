function [ model ] = UpdateSituationSpace_pcS_IPCA( X, model)
%Recieves new observations in X and updates the JIT-PCA model with it.

% X is a m x n matrix with m instances and n features. 
m = size(X,1);
[row,column]=size(X);
priorCount = model.ipca.counter;

if row==1
    X_with_mean=X;
else
    X_with_mean=sum(X);
end
model.centroid = (priorCount*model.centroid +X_with_mean)/(model.ipca.counter+row);
X=X-ones(row,1)*model.centroid;

[model.ipca.u,model.ipca.s,model.ipca.total_mass,model.ipca.counter,model.ipca.model_base,model.ipca.model_var,model.ipca.approx_rank,model.ipca.used,model.ipca.t]=tals_exterior_for_pca(X,model.ipca.approx_rank,model.ipca.u,model.ipca.s,model.ipca.total_mass,model.ipca.counter,model.ipca.rho,model.ipca.used,model.ipca.t);

model.numPCs = length(model.ipca.model_var);
D = sqrt(model.ipca.model_var); 
model.coeff = model.ipca.model_base*diag(D);
end


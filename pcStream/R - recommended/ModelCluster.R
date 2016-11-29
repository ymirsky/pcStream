ModelCluster = function( X , Pvar, updateTime)  
{
  
  # If you use the source code or impliment pcStream, please cite the following paper:
  # Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.
  
  
  #Recieves a single cluster and returns a PCA represenation model of it.
  
  # X is a m x n matrix with m instances and n features. 
  # returns a model (structure) containing:
  #   coeff: the priciple components of X
  #   W: the respective wieghts (eigenvalues). 
  #   cent is the centroid of the PCA basis PC. 

  
  res=prcomp(X)#[coeff,~,W] = princomp(X);
  W=(t(res[[1]]))^2
  coeff=res[[2]]
  cent <- colMeans(X)#mean(X); #cluster's centroid
  conts = W/sum(W); #percent that each dim contrivutes to the total variation

  #only retain the PCs that contain the Pvar percent of varience of the data.
  if (Pvar == 1)
  {
    numPCs = length(W);
  }
  else if (sum(W)==0)
  {
    numPCs = ncol(W)
  }
  else
  {
    numPCs = which(cumsum(conts) >= Pvar)[1];
    
    
    if (length(numPCs)==0)
      numPCs = 1;
  }
  
  variences = W;
  
  Wtag = W[1:numPCs];
  D = sqrt(Wtag); 
  C = coeff[,1:numPCs];

  if (length(D)>1) {
    coeff = C%*%diag(D)
  }
  else {
    coeff = C*D
  }

  centroid = cent;
  origInstances = X;
  
  
  model=list(numPCs=numPCs,variences=variences,coeff=coeff,
             centroid=centroid,origInstances=origInstances,lastUpdateTime = updateTime)
  
  
  return(model)
  
}

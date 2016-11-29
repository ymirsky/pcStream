predict<-function( X, modelCollection, driftThreshold) #given the m-by-n matrix of m observations, 
  #this function returns the cluster assinments of ech observation with resprect to mthe pcStream 'modelCollection'. The Scores[i,j] is the mahalanobis distance between observation i to cluster j
{
  X = as.matrix(X)
  if (ncol(X) == 1) { m = 1 } else { m = nrow(X) }
  numModels = length(modelCollection)
  Labels = matrix(0,m,1);
  DistMat = matrix(0,m,numModels)
  
  for (i in 1:numModels){
    
    centr = modelCollection[[i]]$centroid
    coeff = modelCollection[[i]]$coeff
    
    #convert X to the  from standard basis to new one:
    Xtag = X-repmat(centr,m,1); # the points after zero-meaned
    transPoints = Xtag%*%coeff;
    if (ncol(transPoints) == 1){DistMat[,i]=transPoints^2}
    else { DistMat[,i] = apply(transPoints,1,ssq<-function(x){sum(x^2)}) }
  }
  
  Scores = sqrt(DistMat);
  
  #Find Most likely model
  Labels =  apply(Scores,1,which.min);
  
  return (list(Labels,Scores))
}
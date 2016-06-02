DetectPointAnom<-function( X, modelCollection, driftThreshold) #given the m-by-n matrix of m observations, 
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
  
  S = sqrt(DistMat)

  #Find Most likely model
  bestScores =  apply(S,1,min);

  return (bestScores)
}
DetectContextAnom<-function( X, modelCollection, driftThreshold, A) #given the m-by-n matrix of m observations, 
  #A is the transition count matrix for the model collection
  {
  Ar = apply(A,2,sum)/sum(A) #node rarity
  X = as.matrix(X)
  if (ncol(X) == 1) { m = 1 } else { m = nrow(X) }
  numModels = length(modelCollection)
  finalScores = matrix(0,m,1);
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
  
  S = sqrt(DistMat);
  
  #Find Most likely model
  bestModels = apply(S,1,which.min);
  bestScores = apply(S,1,min)
  test = bestScores<driftThreshold;
  finalScores[test] = Ar[bestModels[test]];
  
  return (finalScores)
}
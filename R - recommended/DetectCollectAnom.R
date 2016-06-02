DetectCollectAnom<-function( X, modelCollection, driftThreshold, A, w)
  #A is the transition count matrix for the model collection
  #w is the size of sliding window in which the probabilites are smoothed
{
  M = A/repmat(as.matrix(apply(A,1,sum)),1,dim(A)[1]) #Transition Matrix
  X = as.matrix(X)
  if (ncol(X) == 1) { m = 1 } else { m = nrow(X) }
  numModels = length(modelCollection)
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
  test = bestScores>driftThreshold;
  
  #generate the entire transition prob vector
  T = matrix(0,m,1)
  T[1]=1
  for (i in 2:m){
    T[i] = M[bestModels[i-1],bestModels[i]]
  }

  TranProbs = T
  #TranProbs[test] = 0 #definate point anomalies are given a probability of 0
  
  # smooth the probability trace with a averaging sliding window
  scores = matrix(1,length(TranProbs),1)
  for (i in w:length(TranProbs))
  {
    scores[i]=mean(TranProbs[(i-w+1):i])
  }

  return (scores)
}
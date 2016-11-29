pcStream<-function( X, driftThreshold, maxDriftSize, Pvar, modelMemSize,modelLimit)
{
  # If you use the source code or impliment pcStream, please cite the following paper:
  # Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.
  
  #   X is a m by n matrix of m observations (on use this version on smaller datasets (in-memory)).
  
  source('ModelCluster.R')
  require(gdata)
  require(pracma)
  
  dim = ncol(X) # size(X,2); #dimensionality of the dataset
  
  modelCollection = vector('list',1);
  numModels = 0;
  driftBuffer = matrix(0,maxDriftSize,dim);
  numDrifters = 0;
  Labels = c() #matrix(0,nrow(X),1);  Removed for training
  m = nrow(X); #size(X,1);
  A = matrix(0,1,1);
  

  # Initial model
  numModels = numModels + 1;
  modelCollection[[numModels]] = ModelCluster(X[1:maxDriftSize,],Pvar,maxDriftSize);
  #Labels[1:maxDriftSize] = 1;
  #LabelCounter = maxDriftSize+1;
  CurModl = 1;
  A[1,1] = maxDriftSize;
  
  for(t in (maxDriftSize+1):m) {
    if (t %% 10000 == 0) { print(paste("t:",t,"/",m,"   Number of Clusters found:",numModels)) }
    
    #Calculate likelihood scores
    scores = matrix(0,1,numModels);
    
    for (i in 1:numModels)
    {
      #convert X to the  from standard basis to new one:
      Xtag = X[t,]-modelCollection[[i]]$centroid; # the points after zero-meaned
      transPoint = Xtag%*%modelCollection[[i]]$coeff;
      scores[i] = transPoint%*%t(transPoint);
    }
    
    scores = sqrt(scores);
    
    #Find Most likely model
    bestModl = which.min(scores);
    #Detect drift
    if (min(scores) > driftThreshold) {
      # Add the drifter to a buffer
      numDrifters = numDrifters + 1;
      driftBuffer[numDrifters,] = X[t,];
      
      #Check if the buffer is full (has enough to make a substantial model
      if (numDrifters == maxDriftSize) 
      {
        if (numModels != modelLimit){
          # Make new model based on the bufferd instances
          numModels = numModels+1;
          #       
        } else { #merge models
          
          #merge the oldest model with its closest neighbour
          #find the oldest model
          modelTimes = matrix(-1,1,numModels);
          for (mm in 1:length(modelCollection)){
            modelTimes[mm]=modelCollection[[mm]]$lastUpdateTime;
          }
          oldestModel = which.min(modelTimes);
          
          dists = matrix(0,1,numModels)
          #find closest neighbor to oldesmodel
          for (mm in 1:length(modelCollection)){
            df = modelCollection[[oldestModel]]$centroid - modelCollection[[mm]]$centroid;
            dists[mm] = transPoint%*%t(transPoint);
          }
          closestModel = which.min(dists);
          
          #merge the two (preserve knowledge)
          l1 = modelCollection[[oldestModel]]$origInstances
          l2 = modelCollection[[closestModel]]$origInstances
          d1 = dim(l1)
          d2 = dim(l2)
          mSize = min((d1[1]+d2[1]),modelMemSize)
          l1 <- "[<-"(matrix(0,mSize,d1[2]), 1:nrow(l1), 1:ncol(l1), value = l1)
          l2 <- "[<-"(matrix(0,mSize,d2[2]), 1:nrow(l2), 1:ncol(l2), value = l2)
          M = interleave(l1,l2)
          modelCollection[[closestModel]] = ModelCluster(M[1:mSize,],Pvar,modelCollection[[closestModel]]$lastUpdateTime);
          
          #update transition matrix
          t_oldst = list(A[oldestModel,],A[,oldestModel])
          interTrans = A[oldestModel,oldestModel]
          A[closestModel,] = A[closestModel,] + t_oldst[[1]]
          A[,closestModel] = A[,closestModel] + t_oldst[[2]]
          A[closestModel,closestModel] = A[closestModel,closestModel] + interTrans;
          A = A[-oldestModel,]
          A = A[,-oldestModel]
          
          
          if (CurModl == oldestModel){CurModl=closestModel}
          else if (CurModl > oldestModel){CurModl = CurModl - 1} #because we shifted everything over
        }
        
        
        modelCollection[[numModels]] = ModelCluster(driftBuffer,Pvar,t);
        #Labels[LabelCounter:(LabelCounter+maxDriftSize-1)] = numModels; # assign labels to these instances
        #LabelCounter=LabelCounter+maxDriftSize;
        
        # update transition matrix:
        #expand matrix
        tmp = A;
        A = matrix(0,numModels,numModels);
        A[1:numModels-1,1:numModels-1] = tmp;
        # assign transitions
        A[CurModl,numModels] = A[CurModl,numModels] + 1;
        A[numModels,numModels] = maxDriftSize-1;
        
        CurModl = numModels; #update the current model to this new one
        
        # Clear the buffer
        driftBuffer = matrix(0,maxDriftSize,dim);
        numDrifters = 0;
      }
    }
      else 
      { #there was no drift
        x = X[t,];
        
        # Clear driftBuffer (consistency broken): assign all contents to current model
        if (numDrifters > 0) {
          x <- rbind(driftBuffer[1:numDrifters,],x);

          #Labels[LabelCounter:(LabelCounter+numDrifters-1)] = CurModl;
          #LabelCounter=LabelCounter+numDrifters;
          
          # update transition matrix:
          A[CurModl,CurModl] = A[CurModl,CurModl] + numDrifters;
          
          # Clear the buffer
          driftBuffer = matrix(0,maxDriftSize,dim);
          numDrifters = 0;
        }
        
        # Assign this instance to its most similar model (update that model)
        M <- rbind(modelCollection[[bestModl]]$origInstances,x);
        M = M[(nrow(M)-min(modelMemSize,nrow(M))+1):nrow(M),]; #take the modelMemSize most recent observations
        modelCollection[[bestModl]] = ModelCluster(M,Pvar,t);
        
        # update transition matrix:
        A[CurModl,bestModl] = A[CurModl,bestModl] + 1;
        
        CurModl = bestModl; #set the "current" model to this model
        #Labels[LabelCounter] = bestModl;
        #LabelCounter=LabelCounter+1;
      } # end of else
      
      
    } # end of main for loop 
    
    
    # empty buffer last time:
    if (numDrifters > 0) {
      M <- rbind(modelCollection[[CurModl]]$origInstances,driftBuffer[1:numDrifters,]);
      M = M[(nrow(M)-min(modelMemSize,nrow(M))+1):nrow(M),]; #take the modelMemSize most recent observations
      modelCollection[[CurModl]] = ModelCluster(M,Pvar,t);
      #Labels[LabelCounter:(LabelCounter+numDrifters-1)] = CurModl;
      
      # update transition matrix:
      A[CurModl,CurModl] = A[CurModl,CurModl] + numDrifters;
    }
    
    return(list(modelCollection[1:numModels], Labels, A))
  } # end of function
  

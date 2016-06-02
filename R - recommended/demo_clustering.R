# If you use the source code or impliment pcStream, please cite the following paper:
# Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

#setwd("...")

source('pcStream.R')
source('predict.R')
library(pracma)

X=as.matrix(read.csv("KDD_data_sample.csv",stringsAsFactors=F))
Y=as.matrix(read.csv("KDD_data_sample_labels.csv",stringsAsFactors=F))

#perform zscore on the stream
means = apply(X,2,mean)
stds = apply(X,2,sd)+matrix(.00000000000001,1,ncol(X)) #avoid divide by zero error
X = (X-repmat(means,nrow(X),1))/repmat(stds,nrow(X),1)

#create datasets
top=floor(dim(X)[1]*.8); #take first %80 of stream as train -the rest as test
Xtrain = X[1:top,]
Xtest = X[-(1:top),]
Ytest = Y[-(1:top),]

#set pcStream Paramaters
driftThreshold = 4 # Phi: Drift threshold (number of stds away to say that an observation not likeli part of the model)
maxDriftSize = 20 # t_min: Number of instances in a row that have "drifted"
percentVarience = 0.98 # rho
modelMemSize = 500 # m: the number of observatiosn retained by each model
modelLimit = 2000 #|C|:Limits the number of pcStream models to store in the collection. If more than modelLimit clusters are detected, then 'knowledge freshness' merging is performed

print("Starting pcStream...")
output<-pcStream(Xtrain, driftThreshold, maxDriftSize,percentVarience, modelMemSize, modelLimit)
print("done.")
modelCollection = output[[1]]
print(paste("The number of contexts found:",length(modelCollection)))

#predict labels (cluster assignments) on test set
out = predict(Xtest, modelCollection )
predictions = out[[1]]

#Print the Ajusted Rand Index (performance)
library(mclust)
print(paste("Adjusted Rand Index:",  adjustedRandIndex(predictions,Ytest) ))

#plot the cluster frequency
A = output[[3]] # Transition count matrix
MC = A/repmat(t(t(apply(A,1,sum))),1,dim(A)[1]) #Markov chain
hist(apply(A,1,sum)) #histogram of transition node degrees
plot(sort(apply(A,1,sum))) #Plot of out degrees


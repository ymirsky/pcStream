# If you use the source code or impliment pcStream, please cite the following paper:
# Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

#setwd("...")

source('pcStream.R')
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
Ytest[Ytest==12] = 0 #12 indicates normal traffic, so it is labeled as benign (0)
Ytest[Ytest!=0] = 1 #All other labels are types of attacks, so they are labled as malicious (1)

#Sanitize the training set (remove all malicous labes so that only the normal behavior is recorded)
Xtrain = Xtrain[Y[1:top,]==12,] #12 is the label for 'normal'

#set pcStream Paramaters
driftThreshold = 4 # Phi: Drift threshold (number of stds away to say that an observation not likeli part of the model)
maxDriftSize = 20 # t_min: Number of instances in a row that have "drifted"
percentVarience = 0.98 # rho
modelMemSize = 500 # m: the number of observatiosn retained by each model
modelLimit = 2000 #|C|:Limits the number of pcStream models to store in the collection. If more than modelLimit clusters are detected, then 'knowledge freshness' merging is performed

print("Starting pcStream...")
output<-pcStream(Xtrain, driftThreshold, maxDriftSize,percentVarience, modelMemSize,modelLimit)
print("done.")

modelCollection = output[[1]]
A = output[[3]] #the transition matrix

print(paste("The number of contexts found:",length(modelCollection)))



##Use the modelCollection to evaluation anomaly detection on the testset:
source('DetectPointAnom.R')
source('DetectContextAnom.R')
source('DetectCollectAnom.R')
library('ROCR') #for measuring performance

#point anomaly detection
scores1 = DetectPointAnom( Xtest, modelCollection, driftThreshold)
AUC1 = performance(prediction(scores1,Ytest), 'auc')@y.values[[1]]
AUC1 = max(AUC1,1-AUC1) #encase the scores are inverted

#contextual anomlay detection
scores2 = DetectContextAnom( Xtest, modelCollection, driftThreshold,A)
AUC2 = performance(prediction(scores2,Ytest), 'auc')@y.values[[1]]
AUC2 = max(AUC2,1-AUC2) #encase the scores are inverted

#collective anomaly detection
windowSize = 5
scores3 = DetectCollectAnom( Xtest, modelCollection, driftThreshold,A,windowSize)
AUC3 = performance(prediction(scores3,Ytest), 'auc')@y.values[[1]]
AUC3 = max(AUC1,1-AUC1) #encase the scores are inverted

print(paste("The AUC of detecting point anomalies is:",AUC1))
print(paste("The AUC of detecting contextual anomalies is:",AUC2))
print(paste("The AUC of detecting collective anomalies is:",AUC3))


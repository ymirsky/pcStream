#!/usr/bin/python
# Filename: pcStream.py

# If you use the source code or impliment pcStream, please cite the following paper:
# Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

import numpy as np

# Use this function when you have a pcS model collection, and which to classify a new observation (i.e. label it's cluster by index)
def classifyOb(x, modelCollection):
	#x is a single 1-by-n observation. modelCollection is a list of pcS models in the form: (X,A,mu) -see paper
	#score observation
	scores = np.zeros(len(modelCollection))
	for i in range(0,len(scores)):
		#transform the observation to the new basis
		xtag = (x - modelCollection[i][2])
		transPoint = np.dot(xtag,modelCollection[i][1])
		scores[i] = np.dot(transPoint,transPoint.T)
	scores = np.sqrt(scores)
	
	#Find most likely model
	bestScore = min(scores)
	return np.where(scores==bestScore)[0][0]

def modelCluster(X, pVar):
	#perform pca on X
	X = np.array(X)
	mu = np.mean(X.T,axis=1)
	M = (X-mu).T # subtract the mean (along columns)
	[latent,coeff] = np.linalg.eig(np.cov(M)) # attention:not always sorted
	order = [i[0] for i in sorted(enumerate(np.absolute(latent)), key=lambda x:x[1],reverse=True)]
	latent = latent[order]
	coeff = coeff[:,order]	
	contributions = latent/sum(latent)
	
	#only retain the PCs that contain the Pvar percent of variance of the data.
	if pVar == 1:
		numPCs = len(latent)
	else:
		numPCs = next((i for i, v in enumerate(np.cumsum(contributions)) if v >= pVar),len(latent)-1)+1
	
	Ltag = latent[0:numPCs]
	D = np.sqrt(Ltag); 
	C = coeff[:,0:numPCs]
	A = np.dot(C,np.diag(D))
	return (X,A,mu)


def pcS(X, pcS_args): #dataset is an ordered rdd with each row being an observation 
  #pcS_args: (DriftThreshold, DriftSize -must be greater than n, PercentVareince, ModelMemorySize -greater then driftSize)
	if isinstance(X,list):
		X = np.array(X)
	n = X.shape[1] #the number of features
	m = X.shape[0]
	
	driftThr = pcS_args[0] #Drift Threshold -set to 1/4th the dataset's std
	driftSize = pcS_args[1] #Buffer size: max drift size -set to 10 times the number of features
	pVar = pcS_args[2] #Percent variance to retain
	modelMemSize = pcS_args[3] #the memory size of each model - 10times the drift size
	
	modelCollection = list()
	modelCollection.append(modelCluster(X[0:driftSize,:],pVar)) #initial model
	
	labels = [0]*driftSize
	driftBuffer = list()
	curModel = 0
	
	#Begin reading stream
	print "beginning stream"
	for x in X[driftSize+1:,:]: #continue pcStream
		# process next observation
		#score observation
		scores = np.zeros(len(modelCollection))
		for i in range(0,len(scores)):
			#transform the observation to the new basis
			xtag = (x - modelCollection[i][2])
			transPoint = np.dot(xtag,modelCollection[i][1])
			scores[i] = np.dot(transPoint,transPoint.T)
		scores = np.sqrt(scores)
		#Find most likely model
		bestScore = min(scores)
		bestModl = np.where(scores==bestScore)[0][0]
		del scores
		
		#Detect drift
		if bestScore > driftThr:
			# Add the drifter to a buffer
			driftBuffer.append(x)
			
			#Check if the buffer is full (has enough to make a substantial model
			if len(driftBuffer) == driftSize:
				modelCollection.append(modelCluster(driftBuffer,pVar))
				curModel = len(modelCollection)-1
				labels = labels + [curModel]*len(driftBuffer)
				del driftBuffer[:]
				
		
		else: # there was no drift
			#Check for partial drift
			if len(driftBuffer) > 0:
				x = [x] + driftBuffer
				labels = labels + [bestModl]*len(driftBuffer)
				del driftBuffer[:]
			
			# assign current observation
			curModel = bestModl
			if isinstance(x,np.ndarray):
				x = [x]
			
			modelCollection[curModel] = modelCluster( (x+list(modelCollection[curModel][0]))[0:modelMemSize], pVar)
			labels.append(curModel)
			#time.sleep(1) #for debugging...   					
	# empty dirftBuffer one last time
	modelCollection[curModel] = modelCluster( (driftBuffer + list(modelCollection[curModel][0]))[0:modelMemSize], pVar)
	labels = labels + [curModel]*len(driftBuffer)
	
	# End of pcStream:
	return (modelCollection, labels)


def genDataset(conceptDurations,conceptScale,ConceptOffsetScale,numConcepts,numFeatures):
	conceptScale = float(conceptScale)
	ConceptOffsetScale = float(ConceptOffsetScale)		
	curConcept = 0
	while curConcept < numConcepts:
		curConcept += 1
		curObs = 0 # there are "conceptDurations" of observation in each concept
		while curObs < conceptDurations:
			curObs += 1
			yield (np.random.randn(1,numFeatures)*(np.random.rand(1,numFeatures)*conceptScale)-np.random.rand(1,numFeatures)*ConceptOffsetScale)[0]



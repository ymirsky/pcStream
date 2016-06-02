import time
import timeit
import numpy as np
from pyspark import SparkContext
from pyspark import SparkConf, SparkContext
conf = (SparkConf().setAppName("My app"))
sc = SparkContext(conf = conf)

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


def pcStream_RDD(dataset, pcS_args, batchSize): #dataset is an ordered rdd with each row being an observation 
	X = dataset.zipWithIndex()
	n = dataset.take(1)[0].shape[0] #the number of features
	m = dataset.count()
	
	#init pcStream
	driftThr = pcS_args[0] #Drift Threshold -set to 1/4th the dataset's std
	driftSize = pcS_args[1] #Buffer size: max drift size -set to 10 times the number of features
	pVar = pcS_args[2] #Percent variance to retain
	modelMemSize = pcS_args[3] #the memory size of each model - 10times the drift size
	
	modelCollection = list()
	startModelData = X.filter(lambda x: (x[1] < driftSize)).map(lambda x: x[0]).collect()
	
	modelCollection.append(modelCluster(startModelData,pVar)) #initial model
	
	labels = [0]*driftSize
	driftBuffer = list()
	curModel = 0
	
	if batchSize == []:
		batchSize = modelMemSize
	
	#Begin reading stream
	print "beginning stream"
	for i in range(driftSize+1, m+1, batchSize): #for each chunk of the stream...
		Xbatch = X.filter(lambda x: (x[1] > i) & (x[1] < i + batchSize)).map(lambda x: x[0]).collect() #take next ordered chunk into memory
		for x in Xbatch:  #continue pcStream
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

def init_pcStream(broadcastedChunk, pcS_args): #dataset is an ordered rdd with each row being an observation 
	X = broadcastedChunk.value
	if isinstance(X,list):
		X = np.array(X)
	
	driftThr = pcS_args[0] #Drift Threshold -set to 1/4th the dataset's std
	driftSize = pcS_args[1] #Buffer size: max drift size -set to 10 times the number of features
	pVar = pcS_args[2] #Percent variance to retain
	modelMemSize = pcS_args[3] #the memory size of each model - 10times the drift size
	
	modelCollection = list()
	modelCollection.append(modelCluster(X[0:driftSize,:],pVar)) #initial model
	
	labels = [0]*driftSize
	driftBuffer = list()
	curModel = 0
	return (driftThr, driftSize, pVar, modelMemSize, modelCollection, labels, driftBuffer, curModel)

def progress_pcStream(broadcastedChunk, context ):
	print "      Running pcStream on chunk. Clusters found: " + str(len(context[4]))
	X = broadcastedChunk.value
	if isinstance(X,list):
		X = np.array(X)
	driftThr = context[0] #Drift Threshold -set to 1/4th the dataset's std
	driftSize = context[1] #Buffer size: max drift size -set to 10 times the number of features
	pVar = context[2] #Percent variance to retain
	modelMemSize = context[3] #the memory size of each model - 10times the drift size
	
	modelCollection = context[4]
	labels = context[5]
	driftBuffer = context[6]
	curModel = context[7]
	
	#Begin reading stream
	print "beginning stream"
	for x in X: #continue pcStream
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
	
	return (driftThr, driftSize, pVar, modelMemSize, modelCollection, labels, driftBuffer, curModel)

def close_pcStream(context):
	pVar = context[2] #Percent variance to retain
	modelMemSize = context[3] #the memory size of each model - 10times the drift size
	
	modelCollection = context[4]
	labels = context[5]
	driftBuffer = context[6]
	curModel = context[7]
	
	# empty the drift buffer into the current model
	modelCollection[curModel] = modelCluster( (driftBuffer + list(modelCollection[curModel][0]))[0:modelMemSize], pVar)
	labels = labels + [curModel]*len(driftBuffer)
	
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


def batch_pcS(X,paramSet,batchSize): #X is an RDD of the stream, paramSet is a list of pcStream configuration tuples, batchSize is the number of observations to process by each pcS concurrently
	#prepare the dataset for batched processing
	X = X.zipWithIndex()  #order the rows by a generated timestamp: 0,1,2,3...
	
	# Setup the different pcStream runtime parameters
	paramSet = sc.parallelize(paramSet, len(paramSet))
	
	# Perform initialization on each pcStream
	Chunk = X.filter(lambda x: (x[1] > 0) & ( x[1]< batchSize)).map(lambda x: x[0]).collect()
	Chunk = sc.broadcast(Chunk)
	pcS_Collection = paramSet.map(lambda param: init_pcStream(Chunk,param))#.collect()  #map preserves the order
	
	# Run all pcStreams in parallel, on each parameter setting in paramSet, one batch of data at a time
	for i in range(batchSize+1, m, batchSize): #for each chunk of the stream...
		print "=================================="
		print "      Batch progress: " + str(float(i)*100/float(m)) + "%"
		print "% ================================"
		Chunk = sc.broadcast(X.filter(lambda x: (x[1] > i) & (x[1] < i + batchSize)).map(lambda x: x[0]).collect()) #take next ordered chunk into memory
		pcS_Collection = pcS_Collection.map(lambda context: progress_pcStream(Chunk,context))#.collect()
	
	# Close all pcStreams
	return pcS_Collection.map(lambda context: close_pcStream(context)).collect()


#######  Demo  #######
# run code: spark-submit --master yarn-client --num-executors 7 --executor-memory 4g --executor-cores 24 --driver-memory 4g --driver-cores 24 --conf spark.driver.maxResultSize=3g pcStream_Multi.py
# make test dataset
print "Generating dataset"
Ds = list()
n = 100
D = genDataset(1000,1,3,10,n)
for i in D:
	Ds.append(i)

m = len(Ds)
X= sc.parallelize(Ds)
del Ds

#50 pcStream configurations to test in parallel
paramSet = [(2,int(n*1.08000000000000),0.98,n*2),(2,int(n*1.16000000000000),0.98,n*2),(2,int(n*1.24000000000000),0.98,n*2),(2,int(n*1.32000000000000),0.98,n*2),(2,int(n*1.40000000000000),0.98,n*2),(2,int(n*1.48000000000000),0.98,n*2),(2,int(n*1.56000000000000),0.98,n*2),(2,int(n*1.64000000000000),0.98,n*2),(2,int(n*1.72000000000000),0.98,n*2),(2,int(n*1.80000000000000),0.98,n*2),(2,int(n*1.88000000000000),0.98,n*2),(2,int(n*1.96000000000000),0.98,n*2),(2,int(n*2.04000000000000),0.98,n*2),(2,int(n*2.12000000000000),0.98,n*2),(2,int(n*2.20000000000000),0.98,n*2),(2,int(n*2.28000000000000),0.98,n*2),(2,int(n*2.36000000000000),0.98,n*2),(2,int(n*2.44000000000000),0.98,n*2),(2,int(n*2.52000000000000),0.98,n*2),(2,int(n*2.60000000000000),0.98,n*2),(2,int(n*2.68000000000000),0.98,n*2),(2,int(n*2.76000000000000),0.98,n*2),(2,int(n*2.84000000000000),0.98,n*2),(2,int(n*2.92000000000000),0.98,n*2),(2,int(n*3),0.98,n*2),(2,int(n*3.08000000000000),0.98,n*2),(2,int(n*3.16000000000000),0.98,n*2),(2,int(n*3.24000000000000),0.98,n*2),(2,int(n*3.32000000000000),0.98,n*2),(2,int(n*3.40000000000000),0.98,n*2),(2,int(n*3.48000000000000),0.98,n*2),(2,int(n*3.56000000000000),0.98,n*2),(2,int(n*3.64000000000000),0.98,n*2),(2,int(n*3.72000000000000),0.98,n*2),(2,int(n*3.80000000000000),0.98,n*2),(2,int(n*3.88000000000000),0.98,n*2),(2,int(n*3.96000000000000),0.98,n*2),(2,int(n*4.04000000000000),0.98,n*2),(2,int(n*4.12000000000000),0.98,n*2),(2,int(n*4.20000000000000),0.98,n*2),(2,int(n*4.28000000000000),0.98,n*2),(2,int(n*4.36000000000000),0.98,n*2),(2,int(n*4.44000000000000),0.98,n*2),(2,int(n*4.52000000000000),0.98,n*2),(2,int(n*4.60000000000000),0.98,n*2),(2,int(n*4.68000000000000),0.98,n*2),(2,int(n*4.76000000000000),0.98,n*2),(2,int(n*4.84000000000000),0.98,n*2),(2,int(n*4.92000000000000),0.98,n*2),(2,int(n*5),0.98,n*2),(2,int(n*5.08000000000000),0.98,n*2),(2,int(n*5.16000000000000),0.98,n*2),(2,int(n*5.24000000000000),0.98,n*2),(2,int(n*5.32000000000000),0.98,n*2),(2,int(n*5.40000000000000),0.98,n*2),(2,int(n*5.48000000000000),0.98,n*2),(2,int(n*5.56000000000000),0.98,n*2),(2,int(n*5.64000000000000),0.98,n*2),(2,int(n*5.72000000000000),0.98,n*2),(2,int(n*5.80000000000000),0.98,n*2),(2,int(n*5.88000000000000),0.98,n*2),(2,int(n*5.96000000000000),0.98,n*2),(2,int(n*6.04000000000000),0.98,n*2),(2,int(n*6.12000000000000),0.98,n*2),(2,int(n*6.20000000000000),0.98,n*2),(2,int(n*6.28000000000000),0.98,n*2),(2,int(n*6.36000000000000),0.98,n*2),(2,int(n*6.44000000000000),0.98,n*2),(2,int(n*6.52000000000000),0.98,n*2),(2,int(n*6.60000000000000),0.98,n*2),(2,int(n*6.68000000000000),0.98,n*2),(2,int(n*6.76000000000000),0.98,n*2),(2,int(n*6.84000000000000),0.98,n*2),(2,int(n*6.92000000000000),0.98,n*2),(2,int(n*7),0.98,n*2),(2,int(n*7.08000000000000),0.98,n*2),(2,int(n*7.16000000000000),0.98,n*2),(2,int(n*7.24000000000000),0.98,n*2),(2,int(n*7.32000000000000),0.98,n*2),(2,int(n*7.40000000000000),0.98,n*2),(2,int(n*7.48000000000000),0.98,n*2),(2,int(n*7.56000000000000),0.98,n*2),(2,int(n*7.64000000000000),0.98,n*2),(2,int(n*7.72000000000000),0.98,n*2),(2,int(n*7.80000000000000),0.98,n*2),(2,int(n*7.88000000000000),0.98,n*2),(2,int(n*7.96000000000000),0.98,n*2),(2,int(n*8.04000000000000),0.98,n*2),(2,int(n*8.12000000000000),0.98,n*2),(2,int(n*8.20000000000000),0.98,n*2),(2,int(n*8.28000000000000),0.98,n*2),(2,int(n*8.36000000000000),0.98,n*2),(2,int(n*8.44000000000000),0.98,n*2),(2,int(n*8.52000000000000),0.98,n*2),(2,int(n*8.60000000000000),0.98,n*2),(2,int(n*8.68000000000000),0.98,n*2),(2,int(n*8.76000000000000),0.98,n*2),(2,int(n*8.84000000000000),0.98,n*2),(2,int(n*8.92000000000000),0.98,n*2),(2,int(n*9),0.98,n*2),(2,int(n*9.08000000000000),0.98,n*2),(2,int(n*9.16000000000000),0.98,n*2),(2,int(n*9.24000000000000),0.98,n*2),(2,int(n*9.32000000000000),0.98,n*2),(2,int(n*9.40000000000000),0.98,n*2),(2,int(n*9.48000000000000),0.98,n*2),(2,int(n*9.56000000000000),0.98,n*2),(2,int(n*9.64000000000000),0.98,n*2),(2,int(n*9.72000000000000),0.98,n*2),(2,int(n*9.80000000000000),0.98,n*2),(2,int(n*9.88000000000000),0.98,n*2),(2,int(n*9.96000000000000),0.98,n*2),(2,int(n*10.0400000000000),0.98,n*2),(2,int(n*10.1200000000000),0.98,n*2),(2,int(n*10.2000000000000),0.98,n*2),(2,int(n*10.2800000000000),0.98,n*2),(2,int(n*10.3600000000000),0.98,n*2),(2,int(n*10.4400000000000),0.98,n*2),(2,int(n*10.5200000000000),0.98,n*2)]
batchSize = 1000 #how many records should be processed at a time (chunks of the stream)

#begin
start = timeit.default_timer()
pcS_CollectionSET = batch_pcS(X,paramSet,batchSize)
stop = timeit.default_timer()

print "============  Done.  ============"
print "It took " + str(stop-start) + " seconds to train " + str(len(pcS_CollectionSET)) + " pcStreams over a stream of " + str(m) + "  " + str(n) + "-dimensional observations, with a batch size of " + str(batchSize) + "."
print "The following are the number of clusters each of the pcSs found:"
clusterCounts = list()
for model in pcS_CollectionSET:
	clusterCounts.append(len(model[0]))
print clusterCounts
	






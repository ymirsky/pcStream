import time
import timeit
import numpy as np
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


def pcStream_RDD(dataset, pcS_args): #dataset is an ordered rdd with each row being an observation
  #pcS_args: (DriftThreshold, DriftSize -must be greater than n, PercentVareince, ModelMemorySize -greater then driftSize) 
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

def pcStream(X, pcS_args): #dataset is an ordered rdd with each row being an observation 
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

#### Demo ####
#run code:  spark-submit --master yarn-client --num-executors 7 --executor-memory 4g --executor-cores 24 --driver-memory 4g --driver-cores 24 pcStream_FeatureDecomposition.py
# make test dataset
Ds = list()
n = 100
Dgen = genDataset(1000,1,3,10,n)
for i in Dgen:
	Ds.append(i)

dataset= sc.parallelize(Ds)
m = len(Ds)
del Ds

# split the dataset by mapping (feature decomposition)
numGroups = 5
mapping = np.random.randint(numGroups,size=(1,100)) #fake feature grouping as test
l = sc.parallelize(range(0,numGroups))
res = l.map(lambda x: dataset.map(lambda row: row[:,np.nonzero(mapping==x)[0]])  )
Decomposite = sc.parallelize([])
for i in range(0,numGroups): #split the given dataset into "numGroups" datasets each accorind to their subspace (selected dimensions)
	Decomposite = Decomposite.union(dataset.map(lambda x: (i,x[:,np.nonzero(mapping==i)[0]])))

# Run pcStreams in parallel on each dimension subset of the original dataset
pcS_args = (0.01,int(n*1.5),0.98,10000)  
start = timeit.default_timer()	
pcS_CollectionSET = Decomposite.groupByKey().map(lambda x: (x[0],list(x[1]))).map(lambda x: (x[0], pcStream(x[1], pcS_args))).collect()
stop = timeit.default_timer()

print "============  Done.  ============"
print "It took " + str(stop-start) + " seconds to train " + str(len(pcS_CollectionSET)) + " pcStreams over a streams over " + str(m) + "  " + str(n) + "-dimensional observations, with an even/random decomposition of " + str(n/numGroups) + " features (dimensions) per stream."
print "The following are the number of clusters each of the pcSs found:"
clusterCounts = list()
for model in pcS_CollectionSET:
	clusterCounts.append(len(model[1]))
print clusterCounts
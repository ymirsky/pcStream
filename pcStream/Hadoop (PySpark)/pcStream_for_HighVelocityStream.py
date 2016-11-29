from multiprocessing import Process, Pipe
import time
import timeit
import numpy as np
from pyspark import SparkContext
from pyspark import SparkConf, SparkContext
conf = (SparkConf().setAppName("My app"))
sc = SparkContext(conf = conf)

#note: in this version, the pipe does not have sufficient memory for more than n=30 features. Perhaps a scala conversion will solve the issue. Migration to Storm would be better
def offlineComponent(conn,pcS_args):
	taskList = [] #list of observation updates
	updatedModels = list()
	modelCollection = list() #models are the tuple (modelIndex, ModelTuple)
	modelCount = 0
	updateCount = 0
	while True:
		#look for new work
		conn.poll(None) #Wait for work
		while conn.poll(): #for each item in the pipe...
			task = conn.recv()
			if task == 'DONE':
				print "============  Report from Offline Component  ============="
				print "           Number of Batch Updates Processed: " + str(updateCount)
				print "  Number of Initial Models Received from Online Component: " + str(modelCount)
				print "=========================================================="
				return #abort
			
			if task[0]+1 > modelCount: #this task is a new model
				modelCollection.append(task[1])
				modelCount = modelCount + 1
			else: #this task is an observation update
				taskList.append(task)
			
		if len(taskList) > 0 :
			updateCount = updateCount + 1
			#broadcast the models
			modelBroadcast = sc.broadcast(modelCollection)
			
			#update models with observations
			fullUpdatedModels = sc.parallelize(taskList).groupByKey().map(lambda x: (x[0],modelUpdate(x[0],np.array(list(x[1])),pcS_args,modelBroadcast=modelBroadcast))).collect()
			
			for model in fullUpdatedModels:
				modelCollection[model[0]] = model[1][0] #just take the model's observations X
				updatedModels.append((model[0],model[1][1]))
			
			#give online the new model collection
			conn.send(updatedModels)
			
			del taskList[:]
			del updatedModels[:]


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
	return (A,mu)


def onlineComponent(dataset,pcS_args,dataPeriod):
	#dataset is an iteratable collection (not RDD). pcS_args have the form: (driftThreshold, minDriftSize, percentVarience, ModelMemorySize). 
	#dataPeriod is how often the online component processes a new observation (i.e: 1/dataPeriod is the stream's data rate)
	
	#prepare Batch-updater
	Onl_conn, Offl_conn = Pipe()
	p = Process(target=offlineComponent, args=(Offl_conn,pcS_args))
	p.start()
	start = timeit.default_timer()

	#init pcStream
	print "initializing pcS"
	driftThr = pcS_args[0] #Drift Threshold
	driftSize = pcS_args[1] #Buffer size: max drift size
	pVar = pcS_args[2] #Percent variance to retain
	modelMemSize = pcS_args[3] #the memory size of each model
	
	X = iter(dataset) #make the dataset iteratable
	modelCollection = list()
	startModelData = list()
	startModelData.append(X.next())
	print "creating initial model dataset"
	n=len(startModelData[0])
	for i in range(0,startModelData[0].shape[0]-1): #number of observations should not be rank deficient
		startModelData.append(X.next())
	print "modeling first cluster"
	modelCollection.append(modelCluster(startModelData,pVar)) #initial model
	Onl_conn.send((0,np.array(startModelData))) #send model (only its observations) to offline component
	labels = [0]*len(startModelData)
	driftBuffer = list()
	curModel = 0;
	
	#Begin reading stream
	print "beginning stream"
	count = 0
	for x in X: #x is one row (observation)
		try:
			count += 1; time.sleep(dataPeriod) #the best rate spark can handel over a pipe
			if count%100 == 0:
				print "Observations processed: " + str(count)
				
			# look for model updates
			if Onl_conn.poll():
				updatedModels = Onl_conn.recv()
				for model in updatedModels:
					modelCollection[model[0]] = model[1]  #model is a tuple (modelIndex, FullmodelTuple)
			
			# process next observation
			#score observation
			scores = np.zeros(len(modelCollection))
			for i in range(0,len(scores)):
				#transform the observation to the new basis
				xtag = (x - modelCollection[i][1])
				transPoint = np.dot(xtag,modelCollection[i][0])
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
					Onl_conn.send((curModel,np.array(driftBuffer))) #send model (only its observations) to offline component
					labels = labels + [curModel]*len(driftBuffer)
					del driftBuffer[:]
					
			
			else: # there was no drift
				#Check for partial drift
				if len(driftBuffer) > 0:
					for ob in driftBuffer:
						Onl_conn.send((curModel,np.array(ob)))
					labels = labels + [curModel]*len(driftBuffer)
					del driftBuffer[:]
				
				# assign current observation
				curModel = bestModl
				Onl_conn.send((curModel,np.array(x)))
				labels.append(curModel)
		
			#time.sleep(1) #for debugging...
		except Exception as excpt:
			print excpt
	# End of stream:
	#time.sleep(100)
	stop = timeit.default_timer()
	labels = labels + [curModel]*len(driftBuffer) #set labels of those in the drift buffer to be the current model
	Onl_conn.send('DONE')
	p.join()
	print "=================  Report from Online Component  =================="
	print "   Stream processing time: " + str(stop-start) + " at " + str(1/dataPeriod)+ " observations per second."
	print "          Stream size: " + str(len(labels)) + "  " + str(n) + "-dimensional observations."
	print "                      Contexts found: " + str(len(modelCollection))
	print "==================================================================="
	print "Online Component waiting for Offline Component to finish..."
	
	return ( map(lambda x : ([],x[0],x[1]), modelCollection) , labels) #we add an empty 'X' to each model so that it forms (X,A,mu) to be compatible with pcS_predict()

def modelUpdate(modelIndex, newObs, pcS_args, modelBroadcast): #takes the model index to update, and the new observations (list of tuples)
	pVar = pcS_args[2]
	m = pcS_args[3]
	X = np.concatenate((np.array(newObs),np.array(modelBroadcast.value[modelIndex])), axis=0)
	return (X[0:m,:], modelCluster(X[0:m,:], pVar) )

#this method is a generator for a dataset. params is a tuple describing the random dataset to generate -all durations are uniform in length, concepts appear sequentially and are unique
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

######## Demo #######
# Run code: spark-submit --master yarn-client --num-executors 7 --executor-memory 4g --executor-cores 24 --driver-memory 4g --driver-cores 24 --conf spark.driver.maxResultSize=3g pcStream_for_HighVelocityStream.py
#note: the returned modelCollection from the online component is missing 'X' in each model tuple (X,A,mu). However, pcStream_Predict() is still compatible.
n=50
pcS_args = (5,n*4,.98,n*2)
#X = np.random.rand(1000,99)
X = genDataset(1000,1,3,10,n)
modelCollection = onlineComponent(X,pcS_args,0.005)
print "============  Done.  ============"

from multiprocessing import Process, Pipe
import time
import timeit
import numpy as np
from pyspark import SparkConf, SparkContext
import sys

conf = (SparkConf().setAppName("My app"))
sc = SparkContext(conf = conf)


def score(x, modelCollection):
  #x is a single 1-by-n observation. modelCollection is a list of pcS models in the form: (X,A,mu) -see paper
	#score observation
	scores = np.zeros(len(modelCollection.value))
	for i in range(0,len(scores)):
		#transform the observation to the new basis
		xtag = (x - modelCollection.value[i][2])
		transPoint = np.dot(xtag,modelCollection.value[i][1])
		scores[i] = np.dot(transPoint,transPoint.T)
	scores = np.sqrt(scores)
		
	#Find most likely model
	bestScore = min(scores)
	return np.where(scores==bestScore)[0][0]

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

#### Demo ####
#run code:  spark-submit --master yarn-client --num-executors 7 --executor-memory 4g --executor-cores 24 --driver-memory 4g --driver-cores 24 pcStream_Predict.py
# make test dataset
n=100
m=10000
Gen = genDataset(100,2,2,m,n)
D = list()
for i in range(0,m):
  D.append(Gen.next())

X = sc.parallelize(D)

# Generate fake pcS models
C = list()
for i in range(0,n):
	C.append((np.random.rand(200,n),np.random.rand(n,5),np.random.rand(1,n)))

modelCollection = sc.broadcast(C)
start = timeit.default_timer()
labels = X.map(lambda x : score(x,modelCollection=modelCollection)).collect()
stop = timeit.default_timer()

print "============  Done.  ============"
print "It took " + str(stop-start) + " seconds to score " + str(m) + "  " + str(n) + "-dimensional observations using " + str(len(C)) + " models."



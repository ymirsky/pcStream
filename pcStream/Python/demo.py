import pcStream
import timeit

# If you use the source code or impliment pcStream, please cite the following paper:
# Mirsky, Yisroel, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

#### Demo ####

# generate a test dataset
conceptDuration = 1000
conceptDistributionScale = 1
conceptOffset = 3
numSequentialConcepts = 10
n = 100 #number of features

DataGen = pcStream.genDataset(conceptDuration,conceptDistributionScale,conceptOffset,numSequentialConcepts,n) #pcStream.genDataset is a python generator for testing purposes. It generates random sequential overalping normal distributions
Dataset = list()

for x in DataGen:
    Dataset.append(x)

m = len(Dataset) #length of stream

# Run pcStream
driftThreshold = 8.7 # note, it is generally reccoemnded to zscore the dataset before hand. In which case, the driftThreshold is typically slightly above 1
maxDriftSize = int(n*1.5)
percentVarience = 0.98
modelMemory = 10000

pcS_args = (driftThreshold,maxDriftSize,percentVarience,modelMemory) #pcStream argumetns are passed to the function as a tuple
start = timeit.default_timer()	
Result = pcStream.pcS(Dataset,pcS_args) #Result is the tuple (pcStreamModelCollection, clusterLabels)
stop = timeit.default_timer()
modelCollection  = Result[0]

print "============  Done.  ============"
print "It took " + str(stop-start) + " seconds to train pcStream over a stream of " + str(m) + "  " + str(n) + "-dimensional observations."
print "   Number of clusters found: " + str(len(modelCollection))
print "   The clusters have the following number of assigned observations:  "
for cluster in range(0,len(modelCollection)): #a pcStream cluster has the form (X,A,mu) -see the paper
    print "       Cluster " + str(cluster) + ": " + str(len(modelCollection[cluster][0]))

print "  "
print "Predicting (scoring) new observation x:"
x = pcStream.genDataset(conceptDuration,conceptDistributionScale,conceptOffset,numSequentialConcepts,n).next() # some random observation...
print "   x belongs to cluster: " + str( pcStream.classifyOb(x, modelCollection) )
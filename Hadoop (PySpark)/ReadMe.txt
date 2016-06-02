In this folder you will find various tools and implementations for running pcStream on a Hadoop cluster with PySpark. 
Each file has a demo script and example command line instruction for running it.

-FeatureDecomposition
This file contains an example of how a stream with many dimensions can be split into multiple streams, 
each contain a subset of dimensions from the original stream, then each processed in parallel by pcStream. 
The motivation of this script is that sometimes streams have set of features which are correlated together, 
These sets should be clusters separately by pcStream. 

-HighVelocity
This file contains an implementation of a consumer producer version of pcStream. 
In this version there is an on-line component for pcStream which scores the incoming observations and then 
send them to worker threads which use the cluster to perform the updated on the models. 
The updates are performed as minibatches.

-Multi
In this file there is a script for running multiple instances of pcStream in parallel on the same dataset, 
but with different parameters. This is useful for finding the best pcStream parameter for a dataset, 
and for performing context mining.

-Predict
This file contains the code for taking a dataset with a pcStream collection 9already trained) and detecting 
the labels for that dataset efficiently (distributed over the cluster)

# If you use the source code or implement pcStream, please cite the following paper:
# Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. 
"pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." 
In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.
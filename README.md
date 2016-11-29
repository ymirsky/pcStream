# Overview
In this repository you will find  implementations of the pcStream algorithm for Java, Python, MATLAB, R, Android, and Hadoop.
We recommend using the source code for R since it has the latest features and it is well organized.

# What is pcStream?
The clustering of unbounded data-streams is a difficult problem since the observed instances cannot be stored for future clustering decisions. Moreover, the probability distribution of streams tends to change over time, making it challenging to differentiate between a concept-drift and an anomaly. Although many excellent data-stream clustering algorithms have been proposed in the past, they are not suitable for capturing the temporal contexts of an entity.
 
pcStream is a machine learning algorithm for finding contexts or concepts in a numerical stream in an unsupervised manner.
 
Some points about pcStream:
It mines dynamically changing sensor streams for  contexts (concepts)
It can detect overlapping clusters in geometric space
It can be used to infer the current context as well as predict the coming context (when merged with a Markov Chain).
It can be distributed over multiple threads or machines
 
Example usages of pcStream:
-Features for Context aware Recommender Systems
-Anomaly detection
-Behavioural Analysis

# What is pcStream2?
An improvement to pcStream so that overlapping clusters can be detected from the outset (and not just due to a concept drift). For example, imagine the x-y-z acceleration of your smartphone when you jump or walk. These two distrubutions overlap the same space, yet now can be detected and modeled one after the other.
Included in the source code of pcStream2 is a version of pcStream implimented with IPCA (several orders faster then regular pcStream that uses PCA). The IPCA implimentation is JIT-PCA.

# Citations
If you use the source code or impliment pcStream, please cite the following paper:
Yisroel Mirsky, Bracha Shapira, Lior Rokach, and Yuval Elovici. "pcStream: A Stream Clustering Algorithm for Dynamically Detecting and Managing Temporal Contexts." In Advances in Knowledge Discovery and Data Mining (PAKDD), pp. 119-133. Springer International Publishing, 2015.

Yisroel Mirsky, Halpern, T., Upadhyay, R. and Toledo, S., 2016, Enhanced Situation Space Mining for Data Streams, the 32nd ACM Symposium on Applied Computing

Yisroel Mirsky
yisroel@post.bgu.ac.il


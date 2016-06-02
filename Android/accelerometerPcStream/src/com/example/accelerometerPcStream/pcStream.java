package com.example.accelerometerPcStream;

/**
 * Converted by mazor, student position, on 18/05/2016.
 */
import android.content.Context;
import android.util.Log;
import android.widget.Toast;
import org.jmat.data.AbstractMatrix;
import org.jmat.data.Matrix;
import org.jmat.data.matrixDecompositions.EigenvalueDecomposition;
import org.simpleframework.xml.Serializer;
import org.simpleframework.xml.core.Persister;

import java.io.File;
import java.io.IOException;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.Semaphore;

import static org.jmat.MatlabSyntax.*;


public class pcStream {


    private double m_driftThreshold;
    private int m_maxDriftSize;
    private double m_percentVarience;
    private int m_modelMemory;
    private boolean m_stop;
    private boolean m_first;
    private boolean m_hasStoped;
    private boolean m_loaded;
    public String Module_Location = "/storage/emulated/0/xposed/";

    public String getModule_Location() {
        return Module_Location;
    }

    public void setModule_Location(String module_Location) {
        Module_Location = module_Location;
    }

//	public List<model> getM_moodelCollection() {
//        return m_moodelCollection;
//    }

//    public void setM_moodelCollection(List<model> m_moodelCollection) {
//        this.m_moodelCollection = m_moodelCollection;
//    }

    //  private transient Queue<double[]> m_data;
    //  Semaphore semaphore = new Semaphore(0);

    public int modelCount;

    private Queue<model> m_moodelCollectionQueue;

    //   private List<model> m_moodelCollection;
    private Matrix m_driftBuffer;
    private List<double[]> m_List;


    private String m_name;
    boolean isCpu;
    boolean isMemory;
    boolean isBattery;
    boolean isTraffic;
    boolean isSaveData;

    public int numOfSamples;

    public transient Context m_context;

    private transient Queue<double[]> m_data;
    private transient Semaphore semaphore ;
    private transient Semaphore semaphore2;
    private transient int sizeList = 3;

    public void setSizeList(int i){sizeList=i;}

    public pcStream(Context c , double driftThreshold, int maxDriftSize, double percentVarience, int modelMemory,String name, boolean cpu, boolean mem, boolean battery, boolean trafic, boolean data){

        m_driftThreshold = driftThreshold;
        m_maxDriftSize = maxDriftSize;
        m_percentVarience = percentVarience;
        m_modelMemory = modelMemory;
        m_stop = false;
        //  m_moodelCollection = new ArrayList<model>();
        m_first = true;
        m_context = c;
        m_hasStoped = false;
        m_loaded = false;
        m_name = name;
        numOfSamples=0;
        modelCount=0;

        isCpu = cpu;
        isMemory = mem;
        isBattery = battery;
        isTraffic = trafic;
        isSaveData = data;

        m_moodelCollectionQueue = new LinkedList<model>();
        m_data = new LinkedList<>();
        semaphore = new Semaphore(0);
        semaphore2 = new Semaphore(1);
        //   m_data = new LinkedList<double[]>();
        ////Log.d("Run",m_name +" start pcStream");
        Toast.makeText(c, "pcStream created", Toast.LENGTH_LONG).show();
    }

    public pcStream(Context c , double driftThreshold, int maxDriftSize, double percentVarience, int modelMemory,String name){

        m_driftThreshold = driftThreshold;
        m_maxDriftSize = maxDriftSize;
        m_percentVarience = percentVarience;
        m_modelMemory = modelMemory;
        m_stop = false;
        //  m_moodelCollection = new ArrayList<model>();
        m_first = true;
        m_context = c;
        m_hasStoped = false;
        m_loaded = false;
        m_name = name;
        numOfSamples=0;
        modelCount=0;


        m_moodelCollectionQueue = new LinkedList<model>();
        m_data = new LinkedList<>();
        semaphore = new Semaphore(0);
        semaphore2 = new Semaphore(1);
        //   m_data = new LinkedList<double[]>();
        //Log.d("Run",m_name +" start pcStream");
        Toast.makeText(c, "pcStream created", Toast.LENGTH_LONG).show();
    }

    public pcStream() {
    }

    public synchronized void addToQueue(double[] d){
        try {
            semaphore2.acquire();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        m_data.add(d);
        //Log.d("tag","unlock1 "+m_name);
        //Log.d("Run","add Queue size = "+m_data.size()+ " "+m_name);
        semaphore.release(1);
        semaphore2.release();
        //Log.d("tag","unlock2");
    }

    public double[] readNext() {
        // double [] temp = arr[currIndex];
        // currIndex++;
        try {
            Log.d("tag","lock1 "+ m_name);
            semaphore.acquire(1);
        //    Log.d("tag","lock2");
        } catch (InterruptedException e) {
        //    Log.d("tag","lock3");
            e.printStackTrace();
        }
        //Log.d("Run","read Queue size = "+m_data.size() + " "+m_name);
        return m_data.poll();

        // return takeAppSample.getDataLine();
    }

    public boolean isSaveData() {
        return isSaveData;
    }

    public void setIsSaveData(boolean isSaveData) {
        this.isSaveData = isSaveData;
    }

    public int getModelCount() {
        return modelCount;
    }

    public void setModelCount(int modelCount) {
        this.modelCount = modelCount;
    }

    public boolean isCpu() {
        return isCpu;
    }

    public void setIsCpu(boolean isCpu) {
        this.isCpu = isCpu;
    }

    public boolean isMemory() {
        return isMemory;
    }

    public void setIsMemory(boolean isMemory) {
        this.isMemory = isMemory;
    }

    public boolean isBattery() {
        return isBattery;
    }

    public void setIsBattery(boolean isBattery) {
        this.isBattery = isBattery;
    }

    public boolean isTraffic() {
        return isTraffic;
    }

    public void setIsTraffic(boolean isTraffic) {
        this.isTraffic = isTraffic;
    }


    public void saveModel() {
        //Log.d("tagS","saving!!");
        File folder = new File(Module_Location+ m_name);
        boolean success = true;
        if (!folder.exists()) {
            success = folder.mkdir();
        }
        File xmlFile = new File(Module_Location+m_name + "/pcStream.xml");
        try{
            Serializer serializer = new Persister();
            serializer.write(this, xmlFile);
        }
        catch(Exception e){
        //    Log.d("tagS","error saving!!");
        }

    }

    public boolean isM_loaded() {
        return m_loaded;
    }

    public void setM_loaded(boolean m_loaded) {
        this.m_loaded = m_loaded;
    }

    public String getM_name() {
        return m_name;
    }

    public void setM_name(String m_name) {
        this.m_name = m_name;
    }

    public int getNumOfSamples() {
        return numOfSamples;
    }

    public void setNumOfSamples(int numOfSamples) {
        this.numOfSamples = numOfSamples;
    }

    public Queue<model> getM_moodelCollectionQueue() {
        return m_moodelCollectionQueue;
    }

    public void setM_moodelCollectionQueue(Queue<model> m_moodelCollectionQueue) {
        this.m_moodelCollectionQueue = m_moodelCollectionQueue;
    }

    //pcStream Algorithm

    public void pcS() throws IOException {
        double[][] X = new double[m_maxDriftSize][sizeList];
        int currIndex = 0;
        int n = X[0].length;
        int m = m_maxDriftSize;




        if(!m_loaded) {
            //Log.d("tagS",numOfSamples +" start");
            m_loaded = true;

            while (currIndex < m_maxDriftSize) {

                double [] d= readNext();
                //Log.d("data",d.toString());
                if(d == null){
                    break;
                }
                X[currIndex] = d;
                currIndex++;
                numOfSamples++;

            }


            model mod = modelCluster(X);
            modelCount++;
            m_moodelCollectionQueue.add(mod);
            //Log.d("tagS","m_moodelCollectionQueue "+m_moodelCollectionQueue.size());
            X = new double[m][n];
            currIndex = 0;
        }

        Iterator <model> it;

        while((!m_stop) || (m_data.size()>0) ){
            //Log.d("Run",m_name+" "+m_data.size());
            //Log.d("tagS","1");
            double [] d= readNext();
            //Log.d("tagS","2");
            if(d == null){
                //Log.d("tagS","3");
                break;
            }
            X[currIndex] = d;
            //Log.d("tagS","4");
            numOfSamples++;
            //Log.d("tagS",numOfSamples +"");
            //Log.d("sssP",numOfSamples +" " +m_name);

            if(X[currIndex]==null){
                //Log.d("tagS","5");
                break;
            }


            double [] scores = new double[m_moodelCollectionQueue.size()];
            //Log.d("tagS","6 + "+m_moodelCollectionQueue.size());
            it = m_moodelCollectionQueue.iterator();
            for (int i = 0; i < scores.length ; i++) {
                double [][] temp = new double[1][scores.length];
                temp[0] = X[currIndex];
                Matrix x = matrix(temp);
                //Log.d("tagS","6.1");
                model model = it.next();
                //Log.d("tagS","6.2");
                double [][] meanTemp = new double[1][model.getM_mean().length];
                meanTemp[0] = model.getM_mean();
                Matrix tempM = matrix(meanTemp);
                Matrix xtag = minus(x,tempM);
                Matrix tempTrans = matrix(model.getM_transformation());
                Matrix transPoint = times(xtag,tempTrans);
                Matrix tempScore = times(transPoint,matrix(transPoint.transpose().getArrayCopy()));
                scores[i] = tempScore.toDouble();

            }
            //Log.d("tagS","7");
            double [][] tempScore2 = new double[1][scores.length];
            tempScore2[0] = scores;
            Matrix tempScores3 = matrix(tempScore2);
            tempScores3 = sqrt(tempScores3);
            scores = tempScores3.toDoubleArray();
            //***********************
            double bestScore = findMin(scores);
            int bestModel = 0;
            for(int j = 0 ; j < scores.length ; j++){
                if(scores[j] == bestScore){
                    bestModel = j;
                    break;
                }
            }
            //Log.d("tagS","8");
            //Detect drift
            if(bestScore>m_driftThreshold){

                //Log.d("tagS","9");
                //Add the drifter to a buffer
                currIndex++;

                //Check if the buffer is full (has enough to make a substantial model
                if(currIndex == m_maxDriftSize){
                    //Log.d("tagS","10");
                    //Log.d("data","10.1 = "+X.toString());
                    // m_moodelCollection.add(modelCluster(X));
                    int currModel = m_moodelCollectionQueue.size()-1;
                    double [][] temp = X;
                    if(m_moodelCollectionQueue.size() == m_modelMemory){
                        temp = margeModels(temp);
                    }
                    m_moodelCollectionQueue.add(modelCluster(temp));
                    modelCount++;
                    X = new double[m][n];
                    currIndex = 0;
                }
                //Log.d("tagS","11");
            }else{
                //Log.d("tagS","12");
                if(currIndex>0){
                    // currIndex++;
                }
                int currModel = bestModel;

                it = m_moodelCollectionQueue.iterator();
                //Log.d("tagS","12.1");
                for (int i = 0; i < currModel ; i++) {
                    it.next();
                }
                //Log.d("tagS","12.2");
                model model2 = it.next();
                //Log.d("tagS","12.3");
                double [][] tempMemory = model2.getM_memory();
                double [][] tempMemory2 = new double[tempMemory.length+currIndex+1][tempMemory[0].length];
                //Log.d("tagS","13");
                for (int i = 0; i < tempMemory2.length  ; i++) {
                    if(i<=currIndex)
                        tempMemory2[i] = X[currIndex - i];
                    else
                        tempMemory2[i] = tempMemory[i-currIndex-1];
                }
                //Log.d("tagS","14");
                // m_moodelCollection.remove(currModel);
                //Log.d("tagS","m_moodelCollectionQueue 1"+m_moodelCollectionQueue.size());
                it.remove();
                //Log.d("tagS","m_moodelCollectionQueue 2"+m_moodelCollectionQueue.size());
                //Log.d("data","14.1 = "+tempMemory2.toString());
                if(m_moodelCollectionQueue.size() == m_modelMemory){
                    tempMemory2 = margeModels(tempMemory2);
                }
                m_moodelCollectionQueue.add( modelCluster(tempMemory2));
                //modelCount++;
                X = new double[m][n];
                currIndex = 0;
                //Log.d("tagS","15");
            }

        }
        //Log.d("tagS","16");
        if(currIndex>0 && X[currIndex] != null) {
            double [][] tempMemory = new double[currIndex][n];
            for (int i = 0; i < currIndex ; i++) {
                tempMemory[i] = X[i];
            }
            if(m_moodelCollectionQueue.size() == m_modelMemory){
                tempMemory = margeModels(tempMemory);
            }
            m_moodelCollectionQueue.add(modelCluster(tempMemory));
            modelCount++;
        }
        //Log.d("tagS","17");
        m_hasStoped = true;
        //Log.d("tagS",numOfSamples +" "+m_name+" finish");
        //Log.d("Run",m_name +" finish");
        saveModel();

    }

    //margeModels when Queue is full

    private double[][] margeModels(double[][] matrix1){
        double[][] matrix2 = m_moodelCollectionQueue.poll().getM_memory();
        double[][] margeMatrix = new double[matrix1.length][matrix1[0].length];
        int index1 = 0;
        int index2 = 0;
        for (int i = 0; i < matrix1.length; i++) {
            if(i%2==0){
                margeMatrix[i] = matrix1[index1];
                index1++;
            }else {
                margeMatrix[i] = matrix2[index2];
                index2++;
            }
        }
        return margeMatrix;
    }

    public Context getM_context() {
        return m_context;
    }

    public void setM_context(Context m_context) {
        this.m_context = m_context;
    }

    public boolean isM_hasStoped() {
        return m_hasStoped;
    }

    public void setM_hasStoped(boolean m_hasStoped) {
        this.m_hasStoped = m_hasStoped;
    }

    public boolean isM_first() {
        return m_first;
    }

    public void setM_first(boolean m_first) {
        this.m_first = m_first;
    }



    private double findMin(double [] arr){
        double min = arr[0];
        for (int i = 1; i < arr.length ; i++) {
            if(min>arr[i])
                min = arr[i];
        }
        return min;
    }
    /*
        public void pcS(double [][] data){
            int currIndex;
            int lastInsert;
            int max;
            int n;
            int m ;
            Matrix X1= matrix(data);;
            double [][] X;

            if(m_first){
            m_first = false;
            X = get(X1,1,m_maxDriftSize,1,X1.getColumnDimension()).getArrayCopy();
            currIndex = m_maxDriftSize;
            lastInsert = currIndex-1;

          //  while(currIndex<m_maxDriftSize){
          //      X[currIndex] = m_stream.readNext();
          //      currIndex++;
          //  }

            max = data.length;
            n = X[0].length;
            m = m_maxDriftSize;

         //   m_moodelCollection.add(modelCluster(X));

            }else{
                currIndex = 0;
                lastInsert = 0;
                max = data.length;
                n = data[0].length;
                m = m_maxDriftSize;
            }

            while(currIndex<max){

                double [] scores = new double[m_moodelCollection.size()];

                for (int i = 0; i < scores.length ; i++) {
                    double [][] temp = new double[1][scores.length];
                    temp[0] = data[currIndex];
                    Matrix x = matrix(temp);
                    double [][] meanTemp = new double[1][m_moodelCollection.get(i).getM_mean().length];
                    meanTemp[0] = m_moodelCollection.get(i).getM_mean();
                    Matrix tempM = matrix(meanTemp);
                    Matrix xtag = minus(x,tempM);
                    Matrix tempTrans = matrix(m_moodelCollection.get(i).getM_transformation());
                    Matrix transPoint = times(xtag,tempTrans);
                    Matrix tempScore = times(transPoint,matrix(transPoint.transpose().getArrayCopy()));
                    scores[i] = tempScore.toDouble();
                }

                double [][] tempScore2 = new double[1][scores.length];
                tempScore2[0] = scores;
                Matrix tempScores3 = matrix(tempScore2);
                tempScores3 = sqrt(tempScores3);
                scores = tempScores3.toDoubleArray();
                //***********************
                double bestScore = findMin(scores);
                int bestModel = 0;
                for(int j = 0 ; j < scores.length ; j++){
                    if(scores[j] == bestScore){
                        bestModel = j;
                        break;
                    }
                }

                //Detect drift
                if(bestScore>m_driftThreshold){


                    //Add the drifter to a buffer
                    currIndex++;

                    //Check if the buffer is full (has enough to make a substantial model
                    if(currIndex - lastInsert == m_maxDriftSize){
                        X = get(X1,currIndex-m_maxDriftSize + 2,currIndex+1,1,X1.getColumnDimension()).getArrayCopy();
                        m_moodelCollection.add(modelCluster(X));
                        int currModel = m_moodelCollection.size()-1;
                        lastInsert = currIndex;
                        currIndex++;
                    }

                }else{
                    if(currIndex>0){
                        // currIndex++;
                    }
                    int currModel = bestModel;

                    double [][] tempMemory = m_moodelCollection.get(currModel).getM_memory();
                    Matrix t = matrix(tempMemory);
                    Matrix tt = get(X1,currIndex+1,currIndex+1,1,X1.getColumnDimension());
                    Matrix ttt = get(X1,lastInsert+2,currIndex,1,X1.getColumnDimension());
                    tt.insertRowsEquals(tt.getRowDimension(), ttt);
                    tt.insertRowsEquals(tt.getRowDimension(), t);

                    m_moodelCollection.remove(currModel);
                    m_moodelCollection.add(currModel, modelCluster(tt.getArrayCopy()));
                    lastInsert = currIndex;
                    currIndex++;
                }

            }
            if(currIndex - lastInsert >1) {
                double [][] tempMemory = get(X1,lastInsert,currIndex,1,X1.getColumnDimension()).getArrayCopy();

                m_moodelCollection.add(modelCluster(tempMemory));
            }

        }
    */
    private void initPc(double [][] X) {

    }

    //generate model

    public static model modelCluster(double [][] x){

        //Log.d("tagS","18");
        Matrix X = matrix(x);

        Matrix mu = mean(X);
        Matrix muT = matrix(mu.transpose().getArrayCopy());
        AbstractMatrix M = matrix(X.getRowDimension(),X.getColumnDimension(),0);
        for (int i = 0; i < M.getRowDimension() ; i++) {
            AbstractMatrix sub = X.getRow(i).minus(mu);
            M.setRow(i,sub);
        }
        //Log.d("tagS","19");
        Matrix M1 = matrix(M.getArrayCopy());
        //Log.d("tagS","19.1");
        Matrix m = cov(M1);
        //Log.d("tagS","19.2");
        //  //Log.d("tagS",m_stream.getQueueSize() + "");
        for (int i = 0; i <x.length ; i++) {
            String s = "";
            for (int j = 0; j <x[i].length ; j++) {
                s+= x[i][j]+" ";
            }
            //Log.d("tagS",s);
        }
//        AbstractMatrix covariance =  m.covariance();
//        Log.d("tagS","19.3");
//        EigenvalueDecomposition e = covariance.eig();
//        Log.d("tagS","19.4");
//        AbstractMatrix EigenValues = e.getD();
//        Log.d("tagS","19.5");
        Matrix tttt = new Matrix(0,0);
//        Log.d("tagS","19.6");
        try{
            tttt = (Matrix)new EigenvalueDecomposition(m).getD();
            // tttt = eig_D(m);
            //Log.d("tagS","19.3");
        }catch (Exception eh){
            //Log.d("tagS","19.3.1");
            //Log.d("error",eh.getMessage());
        }
//
//        Jama.Matrix copy = new Jama.Matrix(m.getArrayCopy());
//        Log.d("tagS","19.3");
//        Jama.EigenvalueDecomposition eeee = copy.eig();
//        Log.d("tagS","19.4");
//        Jama.Matrix ddd = eeee.getD();
//        Log.d("tagS","19.5");
//        Matrix tttt = new Matrix(ddd.getArray());
//        Log.d("tagS","19.6");

//        DoubleMatrix matrix = new DoubleMatrix(m.getArrayCopy());
//        ComplexDoubleMatrix eigenvalues = Eigen.eigenvalues(matrix);
//        double [][] eigeig = new double[eigenvalues.rows][eigenvalues.columns];
//        for (int i = 0; i < eigenvalues.rows; i++) {
//            for (int j = 0; j < eigenvalues.columns; j++) {
//
//
//            }
//        }

        Matrix latent = diag(tttt);
        //Log.d("tagS","19.7");
        Matrix coeff = eig_V(m);
        //Log.d("tagS","20");
        Matrix sortIlan = sort_I(latent);
        double [] order = sortIlan.getColumnArrayCopy(0);
        latent = matrix(latent.transpose().getArrayCopy());
        Matrix coeff2 = matrix(coeff.getRowDimension(),coeff.getColumnDimension(),0);
        Matrix latent2 = matrix(latent.getRowDimension(),latent.getColumnDimension(),0);
        //Log.d("tagS","21");
        for( int j = 0 ; j < order.length ; j++){
            coeff2.setColumn((int)(order.length-order[j]-1),coeff.getColumn((int)order[j]));
            latent2.setColumn((int)(order.length-order[j]-1),latent.getColumn((int)order[j]));
        }
        //Log.d("tagS","22");
        double [][] zeros = latent2.getArrayCopy();
        for (int i = zeros[0].length-1; i > 0 ; i--) {
            if(zeros[0][i]<0)
                zeros[0][i]=0;
            else
                break;
        }
        //Log.d("tagS","23");
        latent = matrix(zeros);
        latent2 = matrix(latent.transpose().getArrayCopy());

        Matrix contributions = matrix(latent2.divide(sum(latent2)).getArrayCopy());
        //Log.d("tagS","24");
        double pVar = 0.98;
        int numPCs = 0;
        if(pVar==1){
            //Log.d("tagS","25");
            numPCs = latent.getColumnDimension();
        }else{
            //Log.d("tagS","26");
            double [] con = contributions.getColumnArrayCopy(0);
            double sum = 0;
            for ( int index = 0 ; index < con.length ; index++) {
                sum += con[index];
                numPCs = index;
                if(sum>=pVar){
                    break;
                }
            }
        }
        //Log.d("tagS","27");
        Matrix Ltag = get(latent,1,latent.getRowDimension(),1,numPCs+1);
        //Ltag.plusEquals(0.0003);
        Matrix d1 = sqrt(Ltag);
        Matrix D = matrix(d1.getArrayCopy());
        Matrix C = get(coeff2,1,coeff2.getRowDimension(),1,numPCs+1);
        //Log.d("tagS","28");
        double [][] temp = new double[D.getColumnDimension()][D.getColumnDimension()];
        double [] temp2 = D.getRowArrayCopy(0);
        for (int i = 0; i < temp.length ; i++) {
            temp[i][i]= temp2[i];
        }
        //Log.d("tagS","29");
        D = matrix(temp);
        Matrix A = times(C,D);

        model mod = new model(mu.getRowArrayCopy(0),x,A.getArrayCopy());
        //Log.d("tagS","30");
        //modelCount++;
        return mod;
    }


    public double getM_driftThreshold() {
        return m_driftThreshold;
    }

    public void setM_driftThreshold(float m_driftThreshold) {
        this.m_driftThreshold = m_driftThreshold;
    }

    public int getM_maxDriftSize() {
        return m_maxDriftSize;
    }

    public void setM_maxDriftSize(int m_maxDriftSize) {
        this.m_maxDriftSize = m_maxDriftSize;
    }

    public double getM_percentVarience() {
        return m_percentVarience;
    }

    public void setM_percentVarience(float m_percentVarience) {
        this.m_percentVarience = m_percentVarience;
    }

    public int getM_modelMemory() {
        return m_modelMemory;
    }

    public void setM_modelMemory(int m_modelMemory) {
        this.m_modelMemory = m_modelMemory;
    }


    public void setM_driftThreshold(double m_driftThreshold) {
        this.m_driftThreshold = m_driftThreshold;
    }

    public void setM_percentVarience(double m_percentVarience) {
        this.m_percentVarience = m_percentVarience;
    }

    public boolean isM_stop() {
        return m_stop;
    }

    public void setM_stop(boolean m_stop) {
        this.m_stop = m_stop;
        //Log.d("Run",m_name+" set stop");
        //saveModel();
    }

    public Matrix getM_driftBuffer() {
        return m_driftBuffer;
    }

    public void setM_driftBuffer(Matrix m_driftBuffer) {
        this.m_driftBuffer = m_driftBuffer;
    }

    public List<double[]> getM_List() {
        return m_List;
    }

    public void setM_List(List<double[]> m_List) {
        this.m_List = m_List;
    }


}

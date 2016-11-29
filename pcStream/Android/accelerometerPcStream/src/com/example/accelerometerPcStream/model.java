package com.example.accelerometerPcStream;

/**
 * Converted by mazor, student position, on 18/05/2016.
 */
public class model {


    private double [] m_mean;
    private double [][] m_memory;
    private double [][] m_transformation;

    public model(double [] mean, double [][] memory, double [][] transformation){
        m_mean = mean;
        m_memory = memory;
        m_transformation = transformation;
    }

    public model() {
    }

    public void setM_mean(double[] m_mean) {
        this.m_mean = m_mean;
    }

    public void setM_memory(double[][] m_memory) {
        this.m_memory = m_memory;
    }

    public void setM_transformation(double[][] m_transformation) {
        this.m_transformation = m_transformation;
    }

    public double[][] getM_memory() {
        return m_memory;
    }

    public double[] getM_mean() {
        return m_mean;
    }

    public double[][] getM_transformation() {
        return m_transformation;
    }

}


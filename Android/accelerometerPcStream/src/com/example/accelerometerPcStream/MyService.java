package com.example.accelerometerPcStream;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.database.sqlite.SQLiteDatabase;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.IBinder;

import java.io.IOException;
import java.util.Calendar;
import java.util.Locale;


public class MyService extends Service implements SensorEventListener {

    SQLiteDatabase sensorDB = null;

    private SensorManager mSensorManager;
    private Sensor mSensor;

    float x,y,z;
    private static final float NS2S = 1.0f / 1000000000.0f;
    private final float[] deltaRotationVector = new float[4];
    private long timestamp = 0;
    private String temptime;
    private String real_time;
    private static final float EPSILON = 0f;
    private float[] gravity = new float[3];
    private float[] linear_acceleration = new float[3];
    final float alpha = (float) 0.8;
    private boolean isOn ;
    private long sleepTime = 2000;
    int sampleCounter = 1;
    pcStream m_pcStream;

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (timestamp != 0) {
            final float dT = (event.timestamp - timestamp) * NS2S;
            // Axis of the rotation sample, not normalized yet.
            float axisX = event.values[0];
            float axisY = event.values[1];
            float axisZ = event.values[2];
            x = event.values[0];
            y = event.values[1];
            z = event.values[2];

/*

            // Isolate the force of gravity with the low-pass filter.
            gravity[0] = alpha * gravity[0] + (1 - alpha) * event.values[0];
            gravity[1] = alpha * gravity[1] + (1 - alpha) * event.values[1];
            gravity[2] = alpha * gravity[2] + (1 - alpha) * event.values[2];

            // Remove the gravity contribution with the high-pass filter.
            linear_acceleration[0] = event.values[0] - gravity[0];
            linear_acceleration[1] = event.values[1] - gravity[1];
            linear_acceleration[2] = event.values[2] - gravity[2];

            // Calculate the angular speed of the sample
            float omegaMagnitude = sqrt(axisX*axisX + axisY*axisY + axisZ*axisZ);

            // Normalize the rotation vector if it's big enough to get the axis
            // (that is, EPSILON should represent your maximum allowable margin of error)
            if (omegaMagnitude > EPSILON) {
                axisX /= omegaMagnitude;
                axisY /= omegaMagnitude;
                axisZ /= omegaMagnitude;
            }

            // Integrate around this axis with the angular speed by the timestep
            // in order to get a delta rotation from this sample over the timestep
            // We will convert this axis-angle representation of the delta rotation
            // into a quaternion before turning it into the rotation matrix.
            float thetaOverTwo = omegaMagnitude * dT / 2.0f;
            float sinThetaOverTwo = sin(thetaOverTwo);
            float cosThetaOverTwo = cos(thetaOverTwo);
            deltaRotationVector[0] = sinThetaOverTwo * axisX;
            deltaRotationVector[1] = sinThetaOverTwo * axisY;
            deltaRotationVector[2] = sinThetaOverTwo * axisZ;
            deltaRotationVector[3] = cosThetaOverTwo;
*/
            toPcStream();
            sampleCounter = sampleCounter+1;
            if(!real_time.equals(temptime)) {
                sampleCounter = 1;
                temptime = real_time;
            }
        }
        timestamp = System.currentTimeMillis();
        real_time = getDate(timestamp);

      //  float[] deltaRotationMatrix = new float[9];
      //  SensorManager.getRotationMatrixFromVector(deltaRotationMatrix, deltaRotationVector);
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {

    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();

        mSensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);

        mSensor = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);

        mSensorManager.registerListener(this, mSensor, 10000);

        m_pcStream = new pcStream(this, 0.87, 10, 0.98, 1000,"accelerometer");

        Thread t2 = new Thread(new Runnable() {
            public void run() {

                try {
                    m_pcStream.pcS();
                } catch (IOException e) {
                    e.printStackTrace();
                }

            }
        });
        t2.start();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        m_pcStream.addToQueue(null);
        mSensorManager.unregisterListener(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {


        return START_STICKY;
    }



    public void toPcStream(){
        double [] acceler = new double[3];
        acceler[0] = x;
        acceler[1] = y;
        acceler[2] = z;

        m_pcStream.addToQueue(acceler);
    }

    private String getDate(long time) {
        Calendar cal = Calendar.getInstance(Locale.ENGLISH);
        cal.setTimeInMillis(time);
        //String date = DateFormat.format("dd-MM-yyyy", cal).toString();
        String ctime = "" + cal.get(Calendar.HOUR_OF_DAY) + ":" + cal.get(Calendar.MINUTE) + ":" + cal.get(Calendar.SECOND);
        return ctime;
    }

}

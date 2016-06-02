package com.example.accelerometerPcStream;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

public class MyActivity extends Activity {
    /**
     * Called when the activity is first created.
     */
    boolean isOn = false;
    Button startButton;
    TextView sampleText;


    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        sampleText = (TextView) findViewById(R.id.sampleText);
        startButton = (Button) findViewById(R.id.button);
    }

    public void btn_click(View view) {
        if(!isOn){
            startButton.setText("Stop");
            sampleText.setText("pcStream working...");
            isOn = true;
            Intent intent = new Intent(this, MyService.class);
            this.startService(intent);
        }else{
            Intent intent = new Intent(this, MyService.class);
            this.stopService(intent);
            startButton.setText("Start");
            sampleText.setText("");
            isOn = false;
        }
    }
}

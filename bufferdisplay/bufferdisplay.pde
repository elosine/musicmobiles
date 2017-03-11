//Make into image


import oscP5.*;
import netP5.*;
OscP5 meosc;

int bufsize = 800;

float[] sampArray;

void setup() {
  size(800, 800);
  sampArray = new float[bufsize];
  for (int i=0; i<bufsize; i++) {
    sampArray[i] = 0.0;
  }

  OscProperties properties= new OscProperties();
  //properties.setRemoteAddress("127.0.0.1", 57120);  //osc send port (to sc)
  properties.setListeningPort(12321);               //osc receive port (from sc)/*
  properties.setDatagramSize(5136);  //5136 is the minimum 
  meosc= new OscP5(this, properties);
}

void draw() {
  background(255);
  for (int i=1; i<bufsize; i++) {

    /*
    fill(153, 255, 0);
     noStroke();
     rect( i, height - (sampArray[i]*height), 1, 10);
     */

    stroke(153, 255, 0);
    noFill();
    line( i-1, height - (sampArray[i-1]*height), i, height - (sampArray[i]*height));
  }
}


void oscEvent(OscMessage msg) {
  print(" addrpattern: "+msg.addrPattern());
  println(" typetag: "+msg.typetag());
  if ( msg.checkAddrPattern("/sbuf") ) {

    for (int i=0; i<bufsize; i++) {
      float val = map(msg.get(i).floatValue(), -1.0, 1.0, 0.0, 1.0);
      sampArray[i] = val;
    }
    printArray(sampArray);
  }
}
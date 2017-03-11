import netP5.*;
import oscP5.*;

OscP5 osc;
NetAddress sc;
NetAddress meosc;

int eventix = 0;

void setup() {

  size(900, 900);

  osc = new OscP5(this, 12321);
  sc = new NetAddress("127.0.0.1", 57120);
  meosc = new NetAddress("127.0.0.1", 12321);


  // OSC PLUGS //////////////////////////

  ////WINLETS //////////////////////////////
  osc.plug(winletz, "mk", "/mkwinlet");
  osc.plug(winletz, "rmv", "/rmvwinlet");
  osc.plug(winletz, "mvwin", "/mvwin");
  //////////////////////////////////////////

  //// CURSORS /////////////////////////////
  osc.plug(cursorz, "mk", "/mkcursor");
  osc.plug(cursorz, "rmv", "/rmvcursor");
  osc.plug(cursorz, "kdat", "/kdat");
  //////////////////////////////////////////

  // INITIAL ITEMS //////////////////////

  ////Make Window
  osc.send("/mkwinlet", new Object[]{0, 50.0, 50.0, 800.0, 380.0, "black"}, meosc);

  ////Make Cursor
  osc.send("/mkcursor", new Object[]{0, 0, 3, "limegreen"}, meosc);

  ///////////////////////////////////////
  //
  //
} // end setup

void draw() {

  background(25, 33, 47);

  // Winlets ///////
  winletz.drw();
  //////////////////

  // Cursors ///////
  cursorz.drw();
  /////////////////


  //
  //
}// end draw
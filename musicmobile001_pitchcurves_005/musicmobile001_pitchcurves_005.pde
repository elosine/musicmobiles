import netP5.*;
import oscP5.*;

OscP5 osc;
NetAddress sc;
NetAddress meosc;

int eventix = 0;

void setup() {

  size(900, 900);

  OscProperties oscproperties = new OscProperties();
  oscproperties.setListeningPort(12321);
  oscproperties.setDatagramSize(5136);
  osc = new OscP5(this, oscproperties);
  sc = new NetAddress("127.0.0.1", 57120);
  meosc = new NetAddress("127.0.0.1", 12321);


  // OSC PLUGS //////////////////////////

  ////WINLETS //////////////////////////////
  osc.plug(winletz, "mk", "/mkwinlet");
  osc.plug(winletz, "rmv", "/rmvwinlet");
  osc.plug(winletz, "mvwin", "/mvwin");
  osc.plug(winletz, "winw", "/winw");
  //////////////////////////////////////////

  //// CURSORS /////////////////////////////
  osc.plug(cursorz, "mk", "/mkcursor");
  osc.plug(cursorz, "rmv", "/rmvcursor");
  osc.plug(cursorz, "kdat", "/kdat");
  //////////////////////////////////////////

  //// CURVERENDERS /////////////////////////////
  osc.plug(curveRenderz, "mk", "/mkcrv");
  osc.plug(curveRenderz, "rmv", "/rmvcrv");
  osc.plug(curveRenderz, "rendercrv", "/rendercrv");
  //////////////////////////////////////////

 
  ///////////////////////////////////////
  ///////////////////////////////////////
  ///////////////////////////////////////
} // end setup

void draw() {

  background(25, 33, 47);

  // Winlets ///////
  winletz.drw();
  //////////////////

  // Curves ///////
  curveRenderz.drw();
  /////////////////

  // Cursors ///////
  cursorz.drw();
  /////////////////




  /////////////////////////////////////////////
  /////////////////////////////////////////////
}// end draw

void oscEvent(OscMessage msg) {

  //Receive Arrays for calculating curvs
  if ( msg.checkAddrPattern("/crvcoord") ) {

    int crvix = msg.get(0).intValue(); //curve number

    for (int i=curveRenderz.cset.size ()-1; i>=0; i--) {
      CurveRender inst = curveRenderz.cset.get(i);

      if (inst.ix == crvix) {

        for (int j=1; j<inst.bufsize+1; j++) { //j=1 because msg[0]=curvenumber
          float val = map(msg.get(j).floatValue(), -1.0, 1.0, 0.0, 1.0);
          inst.sampArray[j-1] = val;
        } //end for (int i=0; i<inst.bufsize; i++)

        break;
      } //end  if (inst.ix == crvix)
      //
    } //end for (int i=curvRenderz.cset.size ()-1; i>=0; i--)
    //
  } //end   if ( msg.checkAddrPattern("/crvcoord") ) {
  //
  //////////////////////////////////
  //////////////////////////////////
} //end oscEvent
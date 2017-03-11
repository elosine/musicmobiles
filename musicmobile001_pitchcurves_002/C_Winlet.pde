// DECLARE/INITIALIZE CLASS SET
WinletSet winletz = new WinletSet();

/**
 /// PUT IN SETUP ///
 osc.plug(winletz, "mk", "/mkwinlet");
 osc.plug(winletz, "rmv", "/rmvwinlet");
 
 /// PUT IN DRAW ///
 winletz.drw();
 */


class Winlet {

  // CONSTRUCTOR VARIALBES //
  int ix;
  float x, y, w, h;
  String winclr;
  // CLASS VARIABLES //
  float l, r, t, b, m, c;
  // CONSTRUCTORS //

  /// Constructor 1 ///
  Winlet(int aix, float ax, float ay, float aw, float ah, String awinclr) {
    ix = aix;
    x = ax;
    y = ay;
    w = aw;
    h = ah;
    winclr = awinclr;

    l = x;
    r = x+w;
    t = y;
    b = y+h;
    m = x+(w/2.0);
    c = y+(h/2.0);
  } //end constructor 1

  //  DRAW METHOD //
  void drw() {

    // Draw Window
    noStroke();
    fill( clr.get(winclr) );
    rect(x, y, w, h);
  } //End drw
  //
  //
}  //End class

////////////////////////////////////////////////////////////
/////////////   CLASS SET     //////////////////////////////
////////////////////////////////////////////////////////////

class WinletSet {
  ArrayList<Winlet> cset = new ArrayList<Winlet>();

  // Make Instance Method //
  void mk(int ix, float x, float y, float w, float h, String winclr) {
    cset.add( new Winlet(ix, x, y, w, h, winclr) );
  } //end mk method

  // Remove Instance Method //
  void rmv(int ix) {
    for (int i=cset.size ()-1; i>=0; i--) {
      Winlet inst = cset.get(i);
      if (inst.ix == ix) {
        cset.remove(i);
        break;
      }
    }
  } //End rmv method

  // Draw Set Method //
  void drw() {
    for (int i=cset.size ()-1; i>=0; i--) {
      Winlet inst = cset.get(i);
      inst.drw();
    }
  }//end drw method

  // Move Window Method //
  void mvwin(int ix, float x, float y) {
    for (int i=cset.size ()-1; i>=0; i--) {
      Winlet inst = cset.get(i);
      if (ix == inst.ix) {
        inst.x = x;
        inst.y = y;
        inst.l = inst.x;
        inst.r = inst.x+inst.w;
        inst.t = inst.y;
        inst.b = inst.y+inst.h;
        inst.m = inst.x+(inst.w/2.0);
        inst.c = inst.y+(inst.h/2.0);
      }
    }
  }//end move window method
  //
  //
} // END CLASS SET CLASS
// DECLARE/INITIALIZE CLASS SET
CursorSet cursorz = new CursorSet();

/**
 /// PUT IN SETUP ///
 osc.plug(cursorz, "mk", "/mkcursor");
 osc.plug(cursorz, "rmv", "/rmvcursor");
 
 /// PUT IN DRAW ///
 cursorz.drw();
 */


class Cursor {

  // CONSTRUCTOR VARIALBES //
  int ix, winix;
  int w;
  String csrclr;
  // CLASS VARIABLES //
  float x, y1, y2;
  float winw, winx;
  float xnorm=0.0;
  // CONSTRUCTORS //

  /// Constructor 1 ///
  Cursor(int aix, int awinix, int aw, String acsrclr) {
    ix = aix;
    winix = awinix;
    w = aw;
    csrclr = acsrclr;

    for (Winlet inst : winletz.cset) {
      if (inst.ix == winix) {
        x = inst.x;
        y1 = inst.t;
        y2 = inst.b;
        winw = inst.w;
      }
    }
  } //end constructor 1

  //  DRAW METHOD //
  void drw() {

    //get window coordinates for ys
    for (Winlet inst : winletz.cset) {
      if (inst.ix == winix) {
        winx = inst.x;
        y1 = inst.t;
        y2 = inst.b;
      }
    }

    //poll supercollider phasor for x
    osc.send("/getkdata", new Object[]{ix}, sc);
    //map normalized x to window cooridnates
    x = map(xnorm, 0.0, 1.0, winx, winx+winw);
    
    
    //Draw cursor
    strokeWeight(w);
    stroke( clr.get(csrclr) );
    line(x,y1, x,y2);
    
  } //End drw
  //
  //
}  //End class

////////////////////////////////////////////////////////////
/////////////   CLASS SET     //////////////////////////////
////////////////////////////////////////////////////////////

class CursorSet {
  ArrayList<Cursor> cset = new ArrayList<Cursor>();

  // Make Instance Method //
  void mk(int ix, int winix, int w, String csrclr) {
    cset.add( new Cursor(ix,winix,w,csrclr) );
  } //end mk method

  // Remove Instance Method //
  void rmv(int ix) {
    for (int i=cset.size ()-1; i>=0; i--) {
      Cursor inst = cset.get(i);
      if (inst.ix == ix) {
        cset.remove(i);
        break;
      }
    }
  } //End rmv method

  // Draw Set Method //
  void drw() {
    for (int i=cset.size ()-1; i>=0; i--) {
      Cursor inst = cset.get(i);
      inst.drw();
    }
  }//end drw method

  // Get Control value //
  void kdat(int ix, float val) {
    for (int i=cset.size ()-1; i>=0; i--) {
      Cursor inst = cset.get(i);
      if (inst.ix == ix) {
        inst.xnorm = val;
        break;
      }
    }
  } //End kval method
  //
  //
} // END CLASS SET CLASS
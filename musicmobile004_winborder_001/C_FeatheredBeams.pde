// DECLARE/INITIALIZE CLASS SET
FeatheredBeamsSet featheredBeamsz = new FeatheredBeamsSet();

/**
 *
 *
 /// PUT IN SETUP ///
 osc.plug(featheredBeamsz, "mk", "/mkfeatheredBeams");
 osc.plug(featheredBeamsz, "rmv", "/rmvfeatheredBeams");
 
 /// PUT IN DRAW ///
 featheredBeamsz.drw();
 *
 *
 */


class FeatheredBeams {

  // CONSTRUCTOR VARIALBES //
  int ix;
  // CLASS VARIABLES //

  // CONSTRUCTORS //

  /// Constructor 1 ///
  FeatheredBeams(int aix) {
    ix = aix;
  } //end constructor 1

  //  DRAW METHOD //
  void drw() {
    stroke(255);
    strokeWeight(1);
    line(55, 35, 55, 85);
    line(59, 35, 59, 85);
    line(64, 35, 64, 85);
    line(74, 35, 74, 85);
    line(89, 35, 89, 85);
    line(109, 35, 109, 85);
    // +5*i each time until width is reached make array then offscreen buffer
    // copy curve render code
  } //End drw
  //
  //
}  //End class

////////////////////////////////////////////////////////////
/////////////   CLASS SET     //////////////////////////////
////////////////////////////////////////////////////////////

class FeatheredBeamsSet {
  ArrayList<FeatheredBeams> cset = new ArrayList<FeatheredBeams>();

  // Make Instance Method //
  void mk(int ix) {
    cset.add( new FeatheredBeams(ix) );
  } //end mk method

  // Remove Instance Method //
  void rmv(int ix) {
    for (int i=cset.size ()-1; i>=0; i--) {
      FeatheredBeams inst = cset.get(i);
      if (inst.ix == ix) {
        cset.remove(i);
        break;
      }
    }
  } //End rmv method

  // Draw Set Method //
  void drw() {
    for (FeatheredBeams inst : cset) {
      inst.drw();
    }
  }//end drw method
  //
  //
} // END CLASS SET CLASS
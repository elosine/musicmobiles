// DECLARE/INITIALIZE CLASS SET
SVGSet sVGz = new SVGSet();

/**
 *
 *
 /// PUT IN SETUP ///
 osc.plug(sVGz, "mk", "/mksVG");
 osc.plug(sVGz, "rmv", "/rmvsVG");
 osc.plug(sVGz, "rmvall", "/rmvallsVG");
 
 /// PUT IN DRAW ///
 sVGz.drw();
 *
 *
 */


class SVG {

  // CONSTRUCTOR VARIALBES //
  int ix;
  // CLASS VARIABLES //

  // CONSTRUCTORS //

  /// Constructor 1 ///
  SVG(int aix) {
    ix = aix;
  } //end constructor 1

  //  DRAW METHOD //
  void drw() {
  } //End drw
  //
  //
}  //End class

////////////////////////////////////////////////////////////
/////////////   CLASS SET     //////////////////////////////
////////////////////////////////////////////////////////////

class SVGSet {
  ArrayList<SVG> cset = new ArrayList<SVG>();

  // Make Instance Method //
  void mk(int ix) {
    cset.add( new SVG(ix) );
  } //end mk method

  // Remove Instance Method //
  void rmv(int ix) {
    for (int i=cset.size ()-1; i>=0; i--) {
      SVG inst = cset.get(i);
      if (inst.ix == ix) {
        cset.remove(i);
        break;
      }
    }
  } //End rmv method

  // Draw Set Method //
  void drw() {
    for (SVG inst : cset) {
      inst.drw();
    }
  }//end drw method
  //
  //
} // END CLASS SET CLASS
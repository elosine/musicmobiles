// DECLARE/INITIALIZE CLASS SET
SVGSet sVGz = new SVGSet();

/**
 *
 *
 /// PUT IN SETUP ///
 osc.plug(sVGz, "mk", "/mksVG");
 osc.plug(sVGz, "rmv", "/rmvsVG");
 
 /// PUT IN DRAW ///
 sVGz.drw();
 *
 *
 */


class SVG {

  // CONSTRUCTOR VARIALBES //
  int ix;
  String svgname;
  float scale;
  int x,y;
  // CLASS VARIABLES //
  PShape svg;
  float w, h;
  // CONSTRUCTORS //

  /// Constructor 1 ///
  SVG(int aix, String asvgname, float ascale, int ax, int ay) {
    ix = aix;
    svgname = asvgname;
    scale = ascale;
    x = ax;
    y = ay;

    svg = loadShape(svgname);
    w = svg.width*scale;
    h = svg.height*scale;
    
  } //end constructor 1

  //  DRAW METHOD //
  void drw() {
    shape(svg, x, y, w, h);
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
  void mk(int ix, String svgname, float scale, int x, int y) {
    cset.add( new SVG(ix,svgname,scale,x,y) );
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
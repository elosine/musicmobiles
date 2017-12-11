SerialPort.listDevices
Quarks.gui
(
//Adjust Server Options before boot
s.options.numAudioBusChannels = 1000;
s.options.memSize = 163840;
s.waitForBoot{ fork{

	// GLOBAL VARIABLES

	//// Arduino gate
	var inoOn = 0;

	//// Phasorclocks
	var clkbpm = Array.newClear(0);
	var clkbpc = Array.newClear(0);

	//// Windows
	var winwidths = Array.newClear(0);

	//// Curves
	var winw = 0;
	var crvbufs = Array.newClear(0);

	//FUNCTIONS
	////  look up func
	var lookupfunc = { |array num | var return; array.do{|it ix| if(it[0] == num, { return=it[1] }) }; return; };
	////  look up ix func
	var lookupixfunc = { |array num | var return; array.do{|it ix| if(it[0] == num, { return=ix }) }; return; };

	//MISC Variables
	var bthdrs, btaction, triggernum;

	// GROUPS ///////////////////////////////////////////////
	s.sendMsg(\g_new, 1999); s.sendMsg(\g_new, 2000);
	10.do{|ix| s.sendMsg(\g_new, 2001+ix, 3, 2000+ix)};
	s.sendMsg(\g_new, 2999, 3, 2010);

	// OSC Clients ///////////////////////////////
	~proc = NetAddr("127.0.0.1", 12321);
	~sclang = NetAddr("127.0.0.1", 57120); //SClang address

	// ARDUINO /////////////////////////////////////////////////////////////////////////////////

	if(inoOn == 1, {
	~ino = ArduinoSMS("/dev/tty.wchusbserial1d160",9600);

	//////Button Headers
	bthdrs = ["b0","b1","b2","b3","b4","b5","b6","b7"];

	//////Button Actions
	btaction = [

		//0
		//control the tactus number in triggernum
		{ |val|
			if( val==1, { ~sclang.sendMsg("/mvtactus", triggernum[0], 1) }, { ~sclang.sendMsg("/mvtactus", triggernum[0], 0) } );
		}

	];

	//////Button Actions
	triggernum = [0];

	//////Arduino Action /////////////////////
	~ino.action = {
		arg msg;
		var sm = msg.split($:);
		var header = sm[0];
		var val = sm[1].asFloat;

		//Switches
		bthdrs.do{ |it ix|
			if( it==sm[0], {
				var val = sm[1].asInteger;
				btaction[ix].value(val);
			} ) //end if
		}; //end sh.do

	}; //end ino.action

	}); //end if inoOn


	// PHASOR CLOCKS /////////////////////////////////////////////////////////////////////////////////

	//// phasorclock synthdef ////////////////////////////////////////////////////////////////////////
	SynthDef(\phasorclock, {
		arg abus, kbus, trigbus, stbpm=60.0, endbpm=60.0, rampdur=0.05, bpc=16.0, t_tr=1, dir=1;
		var temporamp = EnvGen.ar( Env.new( [1.0, 0.0, 1.0], [0.0, rampdur] ), t_tr ).linexp(0.0, 1.0, stbpm, endbpm);
		var tempo = (temporamp/60.0) / (SampleRate.ir*bpc);
		var clk = Phasor.ar( In.kr(trigbus), tempo*dir);
		Out.ar(abus, clk);
		Out.kr(kbus, clk);
	}).add;

	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MAKE CURSOR / PHASORCLOCK
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	OSCdef(\mkcsr, {|msg|
		var ix = msg[1].asInteger;
		var winix = msg[2].asInteger;
		var bpm = msg[3].asFloat;
		var bpc = msg[4].asFloat;
		var wt = msg[5].asInteger;
		var clr = msg[6].asString;

		// 1) Make phasorclock
		//phasorclocks at nodes 3000-3999, group 2002, audio busses 100-199 and control busses 100-199
		//optional trigbus @ kbusses 350-399, which are tactuses
		s.sendMsg(\s_new, \phasorclock, 3000+ix, 0, 2002, \abus, 100+ix, \kbus, 100+ix, \trigbus, 350+ix, \stbpm, bpm, \endbpm, bpm, \bpc, bpc);

		// 2) Store BPM & BPC info for reading signal buffer
		clkbpm = clkbpm.add( [ix, bpm] );
		clkbpc = clkbpc.add( [ix, bpc] );

		// 2) Make Cursor
		//// "/mkcursor", ix, winix, weight, color name
		~proc.sendMsg("/mkcursor", ix, winix, wt, clr);

	}, "/mkcsr");

	OSCdef( \chgcsr, {|msg|
		var clkix = msg[1].asInteger;
		var newbpm = msg[2].asFloat;
		var newdir = msg[3].asInteger;
		var chgdur = msg[4].asFloat;

		//look up current bpm
		var currbpm;
		currbpm={var cbpm; clkbpm.do{ |it|  if(it[0]==clkix, {cbpm=it[1]}); };cbpm}.value;

		fork{
			0.05.wait;

			//phasorclocks at nodes 3000+
			s.sendMsg(\n_set, clkix+3000, \stbpm, currbpm, \endbpm, newbpm, \rampdur, chgdur, \dir, newdir, \t_tr, 1);

			//store new bpm
			clkbpm.do{ |it ixx|  if(it[0]==clkix, { clkbpm[ixx][1]=newbpm }); };

		}; //end fork


	}, "/chgcsr");


	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// OSCdefs for Sending Control Data from Control Busses to Processing
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	OSCdef( \getkdata, {
		arg msg;
		var kbus = msg[1].asInteger;
		s.sendMsg(\c_get, kbus);
	}, "/getkdata");

	OSCdef( \kdat, {
		arg msg;
		var bnum=msg[1].asInteger;
		var val=msg[2].asFloat;
		~proc.sendMsg("/kdat", bnum, val);
	}, \c_set);

	0.1.wait;
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// CURVES
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	//// Get window width
	OSCdef(\winw, {|msg|
		var winix = msg[1].asInteger;
		var winw = msg[2].asInteger;
		winwidths = winwidths.add([winix, winw]);
		winwidths.postln;
	}, "/winw");

	//// CURVE MAKER ///////////////////////////////////////////////////////////////////////////////////////
	OSCdef(\mkcrv,{ |msg|
		var ix = msg[1].asInteger;
		var winix = msg[2].asInteger;
		var crvtype = msg[3].asInteger;
		var crvwt = msg[4].asInteger;
		var crvclr = msg[5].asString;
		var winw, sig, buf, bufasarray;


		fork{

			//1) Get Winlet Width
			~proc.sendMsg("/winw", winix);

			0.1.wait;

			//1b) Look up winwidth in array and store in local variable
			winw = lookupfunc.value(winwidths, winix);
			0.1.wait;

			//2) Make Empty Curve
			~proc.sendMsg("/mkcrv", ix, winix, crvwt, crvclr);

			//3) Make Signal based on crvtype
			switch( crvtype,
				0, { sig = Signal.sineFill( winw, [1,5] ).offset(1).normalize },
				1, { sig = Signal.chebyFill( winw, [0, 1, 0, 0, 0, 1], normalize: true, zeroOffset: true) },
				2, { sig = Signal.sineFill( winw, [1,3,5,7] ) .offset(1).normalize},
				3, { sig = Signal.sineFill( winw, [1,2,3] ).offset(1).normalize },
				4, { sig = Signal.hanningWindow( winw ) },
				5, { sig = Signal.hammingWindow( winw ) },
				6, { sig = Signal.welchWindow( winw ) },
				7, { sig = Signal.fftCosTable( winw*4 ) },
				8, {
					sig = Signal.newClear(winw);
					sig.waveFill({ arg x, old, i; old * (x % 4) }, 0, 1);
				},
				9, {
					sig = Signal.newClear(winw);
					sig.waveFill({ arg x, old, i; old * sin(11 * x + 0.3) }, 0, 1);
				},
				10, {
					sig = Signal.newClear(winw);
					sig.waveFill({  arg x, old, i;  x  }, 0, 1);
				},
				11, {
					sig = Signal.newClear(winw);
					sig.waveFill({  arg x, old, i;  1-x  }, 0, 1);
				},
				12, {
					sig = Signal.newClear(winw);
					sig.waveFill({  arg x, old, i;  x.squared  }, 0, 1);
				},
				13, {
					sig = Signal.newClear(winw);
					sig.waveFill({  arg x, old, i;  1-x.squared  }, 0, 1);
				}

			);

			0.1.wait;

			//4) Add Signal to Buffer and Buffer to Buffer Array & convert buffer to float array
			buf = Buffer.alloc(s, winw, bufnum:ix); //allocate buffer

			0.1.wait;

			buf.loadCollection(sig); //add signal to buffer
			//Add Buffer to buffer array indexed by curve number
			0.1.wait;

			//CONVERT BUFFER TO FLOAT ARRAY
			buf.loadToFloatArray( action:{arg array; bufasarray = array.as(Array); "done".postln;} );

			0.1.wait;


			//Insert osc name and curve index
			bufasarray.insert(0, ix);
			bufasarray.insert(0, "/crvcoord");

			//bufasarray.postln;

			0.3.wait;

			//5) Send Curve Coordinates to Processing
			~proc.sendBundle(0.0, bufasarray);

			0.85.wait;

			//6) Render Curve
			~proc.sendMsg("/rendercrv", ix);


		}; //end fork

	}, "/mkcrv");

	0.1.wait;
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// CURVE SIGNALS
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	//// Buffer Read SynthDef for reading Curve Signals
	SynthDef(\crvsig, {
		arg clkibs, sigbuf, kobs, obs, bufsize;
		var clk = In.ar(clkibs);
		var sig = BufRd.ar(1, sigbuf, clk*bufsize , 1);
		Out.kr(kobs, sig);
		Out.ar(obs, sig);
	}).add;

	//// CURVE FOLLOWER MAKER //////////////////////////////////////////////////////////////////////////

	OSCdef(\mkcrvfollow, { |msg|
		var ix = msg[1].asInteger;
		var clkix = msg[2].asInteger;
		var crvix = msg[3].asInteger;
		var winix = msg[4].asInteger;
		var sigbuf, winw;

		fork{

			//2) Look Up Window Width
			winw = lookupfunc.value(winwidths,winix);
			0.3.wait;

			//3) //// Make Curve Signal Synth - nodes: 4000-4999, group:2003, aobs:200-299, kobs:200-299
			//// clock's audio sigs at audio busses 100-199
			s.sendMsg(\s_new, \crvsig, 4000+ix, 0, 2003, \clkibs, 100+clkix, \sigbuf, crvix, \kobs, 200+ix, \obs, 200+ix, \bufsize, winw);

			//4) Make Curve Follower in Processing
			// "mkcrvfollow", ix, clkix, crvix
			~proc.sendMsg("/mkcrvfollow", ix, clkix, crvix);

		}; //end fork

	}, "/mkcrvfollow");

	//////////////////////////////////////////////////////////////////////////////////////////////////




	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TACTUS
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	SynthDef(\tactus, {
		arg obs,kobs, tobs, atk=0.1, rel=0.25, crv= -4, gate=0;
		var sig = EnvGen.ar(Env.asr(atk,1.0,rel,crv),gate);
		var gatesig = (1-sig).floor ;
		gatesig.poll;
		Out.ar(obs,sig);
		Out.kr(kobs,sig);
		Out.kr(tobs,gatesig);
	}).add;

	// MAKE A TACTUS
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	OSCdef(\mktactus, {|msg|
		var ix = msg[1].asInteger;
		var winnum = msg[2].asInteger;
		var sz = msg[3].asInteger;
		var clr = msg[4].asString;

		//1) Make a Synth using audio/kbusses 300-349, trigobs 350-399, nodes 5000-5999, group 2003
		s.sendMsg( \s_new, \tactus, 5000+ix, 0, 2003, \obs, 300+ix, \kobs, 300+ix, \tobs, 350+ix, \atk, 0.05, \rel, 0.25, \crv, 6);

		//2) Make a Graphic
		// "/mktactus", int ix, int winix, int sz, String tclr
		~proc.sendMsg( "/mktactus", ix, winnum, sz, clr);

	}, "/mktactus");

	// Activate Tactus
	OSCdef(\mvtactus, {|msg|
		var ix = msg[1].asInteger;
		var trig = msg[2].asInteger;

		s.sendMsg(\n_set, 5000+ix, \gate, trig);
	}, "/mvtactus");

	//////////////////////////////////////////////////////////////////////////////////////////////////

}} //end waitforboot/fork
)

// "/mkwinlet", ix, x, y, w, h, clr
~proc.sendMsg("/mkwinlet", 0, 10.0, 140.0, 1000.0, 330.0, "black");


//1) //////////////////////////////////////

~sclang.sendMsg("/mkcrv", 1, 0, 1, 5, "orange");

~sclang.sendMsg("/mkcsr", 1, 0, 60.0, 8.0, 3, "yellow");

~sclang.sendMsg("/mkcrvfollow", 1, 1, 1, 0);

//////////////////////////////////////////

// 1) off
~proc.sendMsg("/rmvcrvfollow", 1);
~proc.sendMsg("/rmvcursor", 1);
~proc.sendMsg("/rmvcrv", 1);

//////////////////////////////////////////

// 2) Fluid change

~sclang.sendMsg("/mkcrv", 2, 0, 3, 3, "pink");

~sclang.sendMsg("/mkcsr", 2, 0, 150.0, 8.0, 3, "yellow");

~sclang.sendMsg("/mkcrvfollow", 2, 2, 2, 0);


//motives
(
~proc.sendMsg("/mkwinlet", 10, 50.0, 30.0, 150.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 11, 265.0, 30.0, 150.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 12, 480.0, 30.0, 160.0, 90.0, "white");
)

~proc.sendMsg("/winbdr", 10, 1, 13, "violetred");
~proc.sendMsg("/winbdr", 10, 0, 13, "violetred");

~proc.sendMsg("/winbdr", 11, 1, 13, "yellow");
~proc.sendMsg("/winbdr", 11, 0, 13, "yellow");

~proc.sendMsg("/winbdr", 12, 1, 13, "limegreen");
~proc.sendMsg("/winbdr", 12, 0, 13, "limegreen");

Gliss
Bow Pressure
Noise Content
Tremelo/Tonguing

//multiple curves
~proc.sendMsg("/mkwinlet", 1, 10.0, 490.0, 1000.0, 330.0, "black");

~sclang.sendMsg("/mkcrv", 1, 1, 4, 3, "purple");
~sclang.sendMsg("/mkcsr", 1, 1, 90.0, 8.0, 3, "green");
~sclang.sendMsg("/mkcrvfollow", 1, 1, 1, 1);

//multiple tempos

~sclang.sendMsg("/mkcsr", 3, 0, 125.0, 8.0, 3, "dodgerblue");

~sclang.sendMsg("/mkcrvfollow", 3, 3, 2, 0);
// "/mkcrvfollow, ix, clkix, crvix, winix

////////////////////////////////////////////////

//3 Spectral Envelopes

(
~proc.sendMsg("/rmvcrvfollow", 1);
~proc.sendMsg("/rmvcrvfollow", 2);
~proc.sendMsg("/rmvcrvfollow", 3);
)
(
~proc.sendMsg("/rmvcursor", 1);
~proc.sendMsg("/rmvcursor", 2);
~proc.sendMsg("/rmvcursor", 3);
)
(
~proc.sendMsg("/rmvcrv", 1);
~proc.sendMsg("/rmvcrv", 2);
)
(
~proc.sendMsg("/rmvwinlet", 0);
~proc.sendMsg("/rmvwinlet", 1);
)

(
~proc.sendMsg("/mkwinlet", 0, 10.0, 140.0, 1000.0, 700.0, "black");
~proc.sendMsg("/mkwinlet", 1, 250.0, 160.0, 300.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 2, 350.0, 260.0, 230.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 3, 250.0, 360.0, 100.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 4, 300.0, 460.0, 200.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 5, 400.0, 560.0, 150.0, 90.0, "white");
~sclang.sendMsg("/mkcsr", 0, 0, 80.0, 8.0, 3, "turquoiseblue");
)

~sclang.sendMsg("/mkcrv", 0, 1, 10, 3, "goldenrod");
~proc.sendMsg("/rmvcrv", 0);

4,5, 6

10, , , 6











4 Long Gradients

5 Formal Elements
Density w/demo
Orchestration
Pitch
Pulsed to non-pulsed
Number Voices

6 Xenakis
curves in addition to straight lines
long gradual/minute change - Scelsi
very accurate timing and coordination
real-time stochatistic distribution




// Motive Windows
// "/mkwinlet", ix, x, y, w, h, clr
~proc.sendMsg("/mkwinlet", 1, 50.0, 30.0, 150.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 2, 265.0, 30.0, 150.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 3, 480.0, 30.0, 160.0, 90.0, "white");
~proc.sendMsg("/mkwinlet", 4, 695.0, 30.0, 150.0, 90.0, "white");
~proc.sendMsg("/rmvwinlet", 3);

// Make Window
// "/mkwinlet", ix, x, y, w, h, clr
~proc.sendMsg("/mkwinlet", 0, 10.0, 140.0, 1000.0, 330.0, "black");
//border
~proc.sendMsg("/winbdr", 0, 1, 7, "violetred");
~proc.sendMsg("/winbdr", 0, 0, 7, "yellow");
//highlight
~proc.sendMsg("/winhl", 0, 1, "violetred", 50);
~proc.sendMsg("/winhl", 0, 0, "violetred", 50);

// Make Cursor
// "/mkcsr, ix, clkix, bpm, bpc, wt, clr
~sclang.sendMsg("/mkcsr", 0, 0, 60.0, 8.0, 3, "yellow");

// "/mkcrv", ix, winix, crvtype, crvwt, crvclr
~sclang.sendMsg("/mkcrv", 0, 0, 0, 3, "seagreen");
~sclang.sendMsg("/mkcrv", 1, 0, 1, 5, "orange");
~sclang.sendMsg("/mkcrv", 2, 0, 2, 3, "dodgerblue");
~sclang.sendMsg("/mkcrv", 3, 0, 3, 3, "pink");
~sclang.sendMsg("/mkcrv", 4, 0, 4, 3, "mint");
~sclang.sendMsg("/mkcrv", 5, 0, 5, 3, "yellow");
~sclang.sendMsg("/mkcrv", 6, 0, 6, 3, "purple");
~sclang.sendMsg("/mkcrv", 7, 0, 7, 3, "indigo");
~sclang.sendMsg("/mkcrv", 8, 0, 8, 3, "plum"); //no work
~sclang.sendMsg("/mkcrv", 9, 0, 9, 3, "green"); //no work
~sclang.sendMsg("/mkcrv", 10, 0, 10, 3, "magenta");
~sclang.sendMsg("/mkcrv", 11, 0, 11, 3, "turquoiseblue");
~sclang.sendMsg("/mkcrv", 12, 0, 12, 3, "goldenrod");
~sclang.sendMsg("/mkcrv", 13, 0, 13, 3, "red");

// "/mkcrvfollow, ix, clkix, crvix, winix
~sclang.sendMsg("/mkcrvfollow", 0, 0, 0, 0);
~sclang.sendMsg("/mkcrvfollow", 1, 0, 1, 0);
~sclang.sendMsg("/mkcrvfollow", 2, 0, 2, 0);
~sclang.sendMsg("/mkcrvfollow", 3, 0, 3, 0);
~sclang.sendMsg("/mkcrvfollow", 4, 0, 4, 0);
~sclang.sendMsg("/mkcrvfollow", 5, 0, 5, 0);
~sclang.sendMsg("/mkcrvfollow", 6, 0, 6, 0);
~sclang.sendMsg("/mkcrvfollow", 7, 0, 7, 0);
~sclang.sendMsg("/mkcrvfollow", 8, 0, 8, 0);//no work
~sclang.sendMsg("/mkcrvfollow", 9, 0, 9, 0);//no work
~sclang.sendMsg("/mkcrvfollow", 10, 0, 10, 0);
~sclang.sendMsg("/mkcrvfollow", 11, 0, 11, 0);
~sclang.sendMsg("/mkcrvfollow", 12, 0, 12, 0);
~sclang.sendMsg("/mkcrvfollow", 13, 0, 13, 0);

// "/chgcsr", clkix, newbpm, newdir, chgdur
~sclang.sendMsg("/chgcsr", 0, 40, -1, 15);

// Make Window
// "/mkwinlet", ix, x, y, w, h, clr
~proc.sendMsg("/mkwinlet", 1, 150.0, 500.0, 60.0, 320.0, "yellow");

// Make Tactus
// "/mktactus", ix, winnum, sz, clr
~sclang.sendMsg("/mktactus", 0, 1, 20.0, "limegreen");

//Move Tactus
~sclang.sendMsg("/mvtactus", 0, 1);
~sclang.sendMsg("/mvtactus", 0, 0);

 clrs.set("TranquilBlue", "25 33 47");
    clrs.set("orange", "255 128 0");
    clrs.set("red", "255 0 0");
    clrs.set("green", "0 255 0");
    clrs.set("blue", "0 0 255");
    clrs.set("black", "0 0 0");
    clrs.set("white", "255 255 255");
    clrs.set("violetred", "208 32 144"); //7
    clrs.set("springgreen", "0 255 127");
    clrs.set("turquoiseblue", "0 199 140");//9
    clrs.set("seagreen", "67 205 128");
    clrs.set("mint", "189 252 201");
    clrs.set("yellow", "255 255 0");
    clrs.set("goldenrod", "218 165 32");//13
    clrs.set("darkorange", "238 118 0");
    clrs.set("chocolate", "139 69 19");
    clrs.set("slateblue", "113 113 198");//16
    clrs.set("indigo", "75 0 130");
    clrs.set("purple", "128 0 128");
    clrs.set("magenta", "255 0 255");
    clrs.set("plum", "221 160 221");
    clrs.set("maroon", "139 10 80"); //21
    clrs.set("pink", "255 105 180"); //22
    clrs.set("royalblue", "72 118 255");
    clrs.set("dodgerblue", "30 144 255");
    clrs.set("grey", "119 136 153"); //25
    clrs.set("nicegreen", "138 216 20");
    clrs.set("pine", "64 129 64");
    clrs.set("papaya", "255 164 142");
    clrs.set("beet", "157 84 156");
    clrs.set("slate", "117 119 123"); //30
    clrs.set("peacock", "0 130 137");
    clrs.set("fig", "128 84 98");
    clrs.set("sunshine", "255 234 100");
    clrs.set("limegreen", "153 255 0"); //34


s.sendMsg(\n_set, 5000, \atk, 0.05, \rel, 0.25, \crv, 6);

// Amplitude Modulation using curve
SynthDef(\am, {
	arg obs=0, ibs, kibs, freqlo=1, freqhi=80;
	var car = In.ar(ibs);
	var lfo =  In.kr(kibs).linexp(-1.0, 1.0, freqlo, freqhi);
	var mod = SinOsc.kr(lfo).range(0.0, 1.0);
	var sig = mod*car;
	Out.ar(obs, sig);
}).add;

// PitchShift using curve
SynthDef(\ps, {
	arg obs=0, ibs, kibs, pitchratiolo=0.25, pitchratiohi=4;
	var in = In.ar(ibs);
	var lfo =  In.kr(kibs).linlin(-1.0, 1.0, pitchratiolo, pitchratiohi);
	var sig = PitchShift.ar(in,0.2, lfo);
	Out.ar(obs, sig);
}).add;

//Test Signal
SynthDef(\tsaw, {Out.ar(10, Saw.ar(220) )}).add
s.sendMsg(\s_new, \tsaw, 10000, 0, 2004);

//Modulate test signal (am) using curve 0 coming from kbus 200
s.sendMsg(\s_new, \am, 10001, 0, 2006, \ibs, 10, \kibs, 201);
s.sendMsg(\n_set, 10001, \freqlo, 1, \freqhi, 35, \ibs, 11);
//set am to curve 2 at kibs 2001
s.sendMsg(\n_set, 10001, \freqlo, 1, \freqhi, 15, \kibs, 201);

//Modulate test signal (pitchshift) using curve 0 coming from kbus 200
s.sendMsg(\s_new, \ps, 10002, 0, 2005, \ibs, 10, \kibs, 202);
s.sendMsg(\n_set, 10002, \pitchratiolo, 0.1, \pitchratiohi, 4, \obs, 11);
//set am to curve 2 at kibs 2001
s.sendMsg(\n_set, 10002, \freqlo, 1, \freqhi, 15, \kibs, 201);


//Take out the neg -1 in processing and normalize other curves

//Identify Curve by Number
//New Live Processing with curves & box

//curve follower in Processing

//NOTES
//Hook up foot button to tactus
//Envelope based curves (triggered) for accel/decel
//// More Curves
//// Hook Up to AM & Pitch Shifter
//// Employ in Feedback/Audio Processing Setup
////// Add Warp

////speed and direction of cursor

/*
fix curves
make motives
use footpedal to choose different menu items
bouncy ball highlight curve
count off ball



*/










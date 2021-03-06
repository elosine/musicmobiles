(
//Adjust Server Options before boot
s.options.numAudioBusChannels = 1000;
s.options.memSize = 163840;
s.waitForBoot{ fork{

	// GLOBAL VARIABLES

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

	// GROUPS ///////////////////////////////////////////////
	s.sendMsg(\g_new, 1999); s.sendMsg(\g_new, 2000);
	10.do{|ix| s.sendMsg(\g_new, 2001+ix, 3, 2000+ix)};
	s.sendMsg(\g_new, 2999, 3, 2010);

	// OSC Clients ///////////////////////////////
	~proc = NetAddr("127.0.0.1", 12321);
	~sclang = NetAddr("127.0.0.1", 57120); //SClang address


	// PHASOR CLOCKS /////////////////////////////////////////////////////////////////////////////////

	//// phasorclock synthdef ////////////////////////////////////////////////////////////////////////
	SynthDef(\phasorclock, {
		arg abus, kbus, stbpm=60.0, endbpm=60.0, rampdur=0.05, bpc=16.0, t_tr=1, dir=1;
		var temporamp = EnvGen.ar( Env.new( [1.0, 0.0, 1.0], [0.0, rampdur] ), t_tr ).linexp(0.0, 1.0, stbpm, endbpm);
		var tempo = (temporamp/60.0) / (SampleRate.ir*bpc);
		var clk = Phasor.ar(0, tempo*dir);
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
		s.sendMsg(\s_new, \phasorclock, 3000+ix, 0, 2002, \abus, 100+ix, \kbus, 100+ix, \stbpm, bpm, \endbpm, bpm, \bpc, bpc);

		// 2) Store BPM & BPC info for reading signal buffer
		clkbpm = clkbpm.add( [ix, bpm] );
		clkbpc = clkbpc.add( [ix, bpc] );

		// 2) Make Cursor
		//// "/mkcursor", ix, winix, weight, color name
		~proc.sendMsg("/mkcursor", ix, winix, wt, clr);

	}, "/mkcsr");

	OSCdef( \chgcsr, {|msg|
		var ix = msg[1].asInteger;
		var newbpm = msg[2].asFloat;
		var newdir = msg[3].asInteger;
		var chgdur = msg[4].asFloat;

		var currbpm = clkbpm.do{|it ix| if


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

			//2) Make Empty Curve
			~proc.sendMsg("/mkcrv", ix, winix, crvwt, crvclr);

			//3) Make Signal based on crvtype
			switch( crvtype,
				0, { sig = Signal.sineFill( winw, [1,3] ) },
				1, { sig = Signal.chebyFill( winw, [0, 1, 0, 0, 0, 1], normalize: true, zeroOffset: false) },
				2, { sig = Signal.sineFill( winw, [1,3,5,7] ) }
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

			0.1.wait;

			//5) Send Curve Coordinates to Processing
			~proc.sendBundle(0.0, bufasarray);

			0.25.wait;

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
			0.1.wait;

			//3) //// Make Curve Signal Synth - nodes: 4000-4999, group:2003, aobs:200-299, kobs:200-299
			//// clock's audio sigs at audio busses 100-199
			s.sendMsg(\s_new, \crvsig, 4000+ix, 0, 2003, \clkibs, 100+clkix, \sigbuf, ix, \kobs, 200+ix, \obs, 200+ix, \bufsize, winw);

			//4) Make Curve Follower in Processing
			// "mkcrvfollow", ix, clkix, crvix
			~proc.sendMsg("/mkcrvfollow", ix, clkix, crvix);

		}; //end fork

	}, "/mkcrvfollow");

	//////////////////////////////////////////////////////////////////////////////////////////////////

}} //end waitforboot/fork
)


// Make Window
// "/mkwinlet", ix, x, y, w, h, clr
~proc.sendMsg("/mkwinlet", 0, 50.0, 50.0, 800.0, 380.0, "black");

// Make Cursor
// "/mkcsr, ix, clkix, bpm, bpc, wt, clr
~sclang.sendMsg("/mkcsr", 0, 0, 60.0, 8.0, 3, "yellow");

// "/mkcrv", ix, winix, crvtype, crvwt, crvclr
~sclang.sendMsg("/mkcrv", 0, 0, 1, 5, "orange");
~sclang.sendMsg("/mkcrv", 1, 0, 0, 3, "seagreen");
~sclang.sendMsg("/mkcrv", 2, 0, 2, 3, "dodgerblue");

// "/mkcrvfollow, ix, clkix, crvix, winix
~sclang.sendMsg("/mkcrvfollow", 0, 0, 0, 0);
~sclang.sendMsg("/mkcrvfollow", 1, 0, 1, 0);
~sclang.sendMsg("/mkcrvfollow", 2, 0, 2, 0);


//curve follower in Processing

//NOTES
//// More Curves
//// Hook Up to AM & Pitch Shifter
//// Employ in Feedback/Audio Processing Setup
////// Add Warp

////speed and direction of cursor


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













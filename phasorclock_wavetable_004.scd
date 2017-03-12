(
//Adjust Server Options before boot
s.options.numAudioBusChannels = 1000;
s.options.memSize = 163840;
s.waitForBoot{ fork{

	// GLOBAL VARIABLES
	//// Curves
	var winw = 0;
	var crvbufs = Array.newClear(0);

	//FUNCTIONS
	//// Signal Buffer Lookup Function
	var sigbuflookupfunc = { |array num | var return; array.do{|it ix| if(it[0] == num, { return=it[1] }) }; return; };


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
		var wt = msg[4].asInteger;
		var clr = msg[5].asString;

		// 1) Make phasorclock
		//phasorclocks at nodes 3000-3999, group 2002, audio busses 100-199 and control busses 100-199
		s.sendMsg(\s_new, \phasorclock, 3000+ix, 0, 2002, \abus, 100+ix, \kbus, 100+ix, \stbpm, bpm, \endbpm, bpm, \bpc, 8.0);

		// 2) Make Cursor
		//// "/mkcursor", ix, winix, weight, color name
		~proc.sendMsg("/mkcursor", ix, winix, wt, clr);

	}, "/mkcsr");


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
		var bnum=msg[1].asInteger - 100; //using control busses 100-199 need to -100 to get cursor ix
		var val=msg[2].asFloat;
		~proc.sendMsg("/kdat", bnum, val);
	}, \c_set);

	0.1.wait;
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// CURVES
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	//// Get window width
	OSCdef(\winw, {|msg| ~winw = msg[1].asInteger}, "/winw");

	//// CURVE MAKER ///////////////////////////////////////////////////////////////////////////////////////
	OSCdef(\mkcrv,{ |msg|
		var ix = msg[1].asInteger;
		var winix = msg[2].asInteger;
		var crvtype = msg[3].asInteger;
		var crvwt = msg[4].asInteger;
		var crvclr = msg[5].asString;
		var sig, buf, bufasarray;


		fork{

			//1) Get Winlet Width
			~proc.sendMsg("/winw", winix);

			0.1.wait;
			~winw.postln;

			//2) Make Empty Curve
			~proc.sendMsg("/mkcrv", ix, winix, crvwt, crvclr);

			//3) Make Signal based on crvtype
			switch( crvtype,
				0, { sig = Signal.sineFill( ~winw, [1,3] ) },
				1, { sig = Signal.chebyFill( ~winw, [0, 1, 0, 0, 0, 1], normalize: true, zeroOffset: false) }
			);

			0.1.wait;

			//4) Add Signal to Buffer and Buffer to Buffer Array & convert buffer to float array
			buf = Buffer.alloc(s, ~winw); //allocate buffer

			0.1.wait;

			buf.loadCollection(sig); //add signal to buffer
			//Add Buffer to buffer array indexed by curve number
			~crvbufs = ~crvbufs.add([ix, buf]);

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
		arg clkibs, sigbuf, kobs, obs;
		var clk = In.ar(clkibs);
		var sig = BufRd.ar(1, sigbuf, clk, 1);
		Out.kr(kobs, sig);
		Out.ar(obs, sig);
	}).add;

	//// CURVE FOLLOWER MAKER //////////////////////////////////////////////////////////////////////////

	OSCdef(\mkcrvfollow, { |msg|
		var ix = msg[1].asInteger;
		var clkix = msg[2].asInteger;
		var crvix = msg[3].asInteger;
		var sigbuf;

		fork{

			//1) Make Signal Buffer
			//// look up Curve Signal Buffer
			sigbuf = sigbuflookupfunc.value(crvbufs, crvix);

			//2) //// Make Curve Signal Synth - nodes: 4000-4999, group:2003, aobs:200-299, kobs:200-299
			//// clock's audio sigs at audio busses 100-199
			s.sendMsg(\s_new, \crvsig, 4000+ix, 0, 2003, \clkibs, 100+clkix, \sigbuf, sigbuf, \kobs, 200+ix, \obs, 200+ix);

		}; //end fork

	});


	//////////////////////////////////////////////////////////////////////////////////////////////////




}} //end waitforboot/fork
)


// Make Window
~proc.sendMsg("/mkwinlet", 0, 50.0, 50.0, 800.0, 380.0, "black");

// Make Cursor
~sclang.sendMsg("/mkcsr", 0, 0, 60.0, 5, "yellow");

// "/mkcrv", ix, winix, crvtype, crvwt, crvclr
~sclang.sendMsg("/mkcrv", 0, 0, 1, 5, "orange");
~sclang.sendMsg("/mkcrv", 1, 0, 0, 3, "seagreen");




//curve follower (oscdefs);













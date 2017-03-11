(
~proc = NetAddr("127.0.0.1", 12321); //Processing address
~sclang = NetAddr("127.0.0.1", 57120); //SClang address
~winw=0;
~crvbufs = Array.newClear(0);

OSCdef(\winw, {|msg| ~winw = msg[1].asInteger}, "/winw");

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

)

// "/mkcrv", ix, winix, crvtype, crvwt, crvclr
~sclang.sendMsg("/mkcrv", 0, 0, 1, 5, "orange");
~sclang.sendMsg("/mkcrv", 1, 0, 0, 3, "seagreen");



~sig.plot
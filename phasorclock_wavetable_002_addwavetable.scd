(
//Adjust Server Options before boot
s.options.numAudioBusChannels = 3000;
s.options.memSize = 163840;
s.waitForBoot{ fork{

	// GROUPS ///////////////////////////////////////////////
	s.sendMsg(\g_new, 1999); s.sendMsg(\g_new, 2000);
	10.do{|ix| s.sendMsg(\g_new, 2001+ix, 3, 2000+ix)};
	s.sendMsg(\g_new, 2999, 3, 2010);

	// Processing OSC Client ///////////////////////////////
	~proc = NetAddr("127.0.0.1", 12321);

	// phasorclock synthdef //////////////////////////////////////////////////////////////////////////////////////////
	SynthDef(\phasorclock, {
		arg abus, kbus, stbpm=60.0, endbpm=60.0, rampdur=0.05, bpc=16.0, t_tr=1, dir=1;
		var temporamp = EnvGen.ar( Env.new( [1.0, 0.0, 1.0], [0.0, rampdur] ), t_tr ).linexp(0.0, 1.0, stbpm, endbpm);
		var tempo = (temporamp/60.0) / (SampleRate.ir*bpc);
		var clk = Phasor.ar(0, tempo*dir);
		Out.ar(abus, clk);
		Out.kr(kbus, clk);
	}).add;

	// OSCdefs for Sending Control Data from Control Busses to Processing
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

	s.sendMsg(\s_new, \phasorclock, 3000, 0, 2002, \abus, 100, \kbus, 0, \stbpm, 60.0, \endbpm, 60.0, \bpc, 8.0);

}} //end waitforboot/fork
)
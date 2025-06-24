s.options.numInputBusChannels = 0;
s.reboot;

~samplePaths = "/Users/scheiba/supercollider/Creative Kicks/";

(
~samples = [];
PathName(~samplePaths).filesDo({|file|

	~samples = ~samples.add(
		// mono
		Buffer.readChannel(
			server: s,
			path: file.asAbsolutePath,
			channels: 0,
		);
	);
});

~samples.size;
)

~dataset = FluidDataSet(server: s);

(
fork {
	var spectralBuf = Buffer.alloc(server: s, numFrames: 1);
	var statBuf = Buffer.alloc(server: s, numFrames: 1);
	var flattenBuf = Buffer.alloc(server: s, numFrames: 1);

	~samples.do({|sample|
		"Processing sample %".format(sample.bufnum).postln;

		FluidBufSpectralShape.process(
			server: s,
			source: sample,
			// numFrames: 0.2*48000,
			features: spectralBuf, // e.g. n_windows x n_features
		);
		s.sync;

		// reduce time
		FluidBufStats.process(
			server: s,
			source: spectralBuf,
			// select: [\mid, \low, \high],
			select: [\mean, \std],
			stats: statBuf, // n_stat x n_features
		);
		s.sync;

		FluidBufFlatten.process(
			server: s,
			source: statBuf,
			destination: flattenBuf,
		);
		s.sync;

		~dataset.addPoint(
			identifier: sample.bufnum,
			buffer: flattenBuf,
		);
	});

	[spectralBuf, statBuf, flattenBuf].do({|b| b.free});

	"finished".postln;
}
)

~dataset.print;


~datasetNormalized = FluidDataSet(server: s);
~standardize = FluidStandardize(server: s);
~standardize.fitTransform(sourceDataSet: ~dataset, destDataSet: ~datasetNormalized);


~pca = FluidPCA(server: s, numDimensions: 4);
~pca.fit(dataSet: ~datasetNormalized);

~datasetNormalized.print;


(
Ndef.ar(\sig, 1);
)

Ndef(\sig).gui;

(
Ndef(\sig, {
	VarSaw.ar(VarSaw.ar(LFDNoise3.kr(10.5).exprange(100, 1000), width: LFDNoise3.kr(10.5)).exprange(200, LFDNoise3.kr(0.5).exprange(1000, 2000)), width: LFDNoise3.kr(0.5)) * (LFDNoise3.kr(0.5!4).sum) * 0.4;
});
)

~buffer = Buffer.read(s, "/Users/scheiba/supercollider/Creative Kicks/Analog Kicks/Analog Kick 08.wav")

~buffer = Buffer.read(s, "/Users/scheiba/samples/amen.wav");

(
Ndef(\sig, {
	PlayBuf.ar(numChannels: 1, bufnum: ~buffer, loop: 1.0, rate: \rate.kr(1.0))
}).gui;
)

Ndef(\sig, {SinOscFB.ar(100.0, SinOsc.kr(0.15).exprange(0.1, 1.3))*0.5})

Ndef(\sig, {Ndef.ar(\sound, 1) + (LFDNoise3.kr(0.5)*0.1)})

Ndef(\sig).scope;

(
Ndef(\sound, {
	var sig = Ndef.ar(\sig, numChannels: 1);
	var standardBuf = LocalBuf(14);
	var pcaInBuf = LocalBuf(14);
	var pcaOutBuf = LocalBuf(4);
	var trig = Impulse.kr(1000.0);

	var spectral = FluidSpectralShape.kr(
		in: sig,
	);
	var stats = FluidStats.kr(spectral, history: 4).flatten;

	var latent;

	FluidKrToBuf.kr(stats, buffer: standardBuf);

	~standardize.kr(
		trig: trig,
		inputBuffer: standardBuf,
		outputBuffer: pcaInBuf,
	);
	~pca.kr(
		trig: Impulse.kr(10.0),
		inputBuffer: pcaInBuf,
		outputBuffer: pcaOutBuf,
		numDimensions: 4,
	);
	latent = FluidBufToKr.kr(pcaOutBuf);
	// stats.poll(trig: 1.0, label: \stats);

	sig = PMOsc.ar(
		carfreq: latent[0].linexp(-10.0, 10.0, 100, 10).poll(1.0, \car),
		modfreq: latent[1].linexp(-10.0, 10.0, 100, 1000).poll(1.0, \mod),
		pmindex: latent[2].poll(1.0, \pm) * [1.0, 2.0],
		modphase: latent[3].lag(0.1).poll(1.0, \mod),
	) * 0.5; // * Amplitude.ar(sig, releaseTime: 0.1);

	JPverb.ar(sig) * 0.2;
}).play;
)

Ndef(\sound).clear;

Ndef.clear;
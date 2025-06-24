// hello <3

Platform.userExtensionDir.openOS;

FluidAmpFeature;

Fluid

s.boot;

().play;

// check dataset for samplerate

~samplePaths = "/Users/scheiba/supercollider/Creative Kicks/";

(
PathName(~samplePaths).filesDo({|file|
	file.postln;
});
)


[4, 6, 9].do({|value| (value*2).postln})



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
)

// alternative - use glob via pathMatch
"/Users/scheiba/supercollider/Creative Kicks/Processed Kicks/*/*.wav".pathMatch

~samples.choose.play;

// e.g. filter out stuff
~samples = ~samples.select({|buffer| buffer.numChannels == 1});

~samples.size

// optional: normalize samples
~samples.do({|sample| sample.normalize;});

// still check if files are not "kaputt"
~samples.choose.play;


// create a buffer to store the results of the analysis
~features = Buffer.alloc(server: s, numFrames: 1);

(
~sample = ~samples.choose;
~sample.play;

FluidBufSpectralShape.process(
	server: s,
	source: ~sample,
	features: ~features, // windows(t) X spec_features(7)  // n_w x n_s
);
)

~features

~features.loadToFloatArray(action: {|array| ~array = array});

~array.clump(7).flop.plot;
// Search docs for "J concepts in SC"

~sample.play;

~sample.plot;


~stats = Buffer.alloc(server: s, numFrames: 1);


Ndef(\x, {SinOsc.ar(200.0!2) * 0.2}).play;

(
fork {
	var features = Buffer.alloc(server: s, numFrames: 1);
	var stats = Buffer.alloc(server: s, numFrames: 1);

	~sample = ~samples.choose;
	// ~sample.play;

	FluidBufSpectralShape.process(
		server: s,
		source: ~sample,
		numFrames: 0.2*48000,
		features: features, // e.g. n_windows x n_features
	);
	s.sync;

	FluidBufStats.processBlocking(
		server: s,
		source: features,
		// select: [\mid, \low, \high],
		stats: stats, // n_stat x n_features
	);


	s.sync;

	stats.loadToFloatArray(action: {|a| a.size.postln});
}
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

	"finished".postln;
}
)

~dataset.dump;
~dataset.cols;

~dataset.write("foo.json")

~dataset.size

~datasetNormalized = FluidDataSet(server: s);

// make every dimension equal in range and distribution so PCA can work better
FluidStandardize(server: s).fitTransform(sourceDataSet: ~dataset, destDataSet: ~datasetNormalized);
~datasetNormalized.dump;

~datasetNormalized.cols


~datasetPca = FluidDataSet(server: s);

(
FluidPCA(server: s, numDimensions: 2).fitTransform(
	sourceDataSet: ~datasetNormalized,
	destDataSet: ~datasetPca,
)
)

CondVar

(
var clicked = Buffer.alloc(server: s, numFrames: 2);
~datasetPca.dump({|dict|
	defer {
		FluidPlotter(dict: dict, xmin: -10, xmax: 10, ymin: -10, ymax: 10, mouseMoveAction: {|view, xPos, yPos mod, button, count|
			fork {
				clicked.sendCollection(collection: [xPos, yPos]);
				s.sync;
				~datasetPca.kNearest(buffer: clicked, k: 1, action: {|i|
					~samples.select({|buf| buf.bufnum == i.asInteger}).first.postln.play;
				});
			};
		});
	};
})
)








~stats;
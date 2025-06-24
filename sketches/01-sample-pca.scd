s.reboot;

// download e.g. kicks via https://www.musicradar.com/news/sampleradar-creative-kick-drum-samples
(
~sampleBuffers = [];
PathName("/Users/scheiba/supercollider/Creative Kicks/").filesDo({|file|
	~sampleBuffers = ~sampleBuffers.add(Buffer.readChannel(
		server: s,
		path: file.asAbsolutePath,
		// only mono
		channels: 0,
	));
});
)

~sampleBuffers.choose.postln.play;





~sample = ~sampleBuffers.choose;
~sample.play;

(
fork {
	~targetBuffer = Buffer.alloc(server: s,numFrames: 1);
	FluidBufSpectralShape.processBlocking(
		server: s,
		source: ~sample,
		features: ~targetBuffer,
	);
	s.sync;
	~targetBuffer.loadToFloatArray(action: {|a|
		"Shape of ~targetBuffer is %".format(a.shape).postln;
	});
};
)


(
fork {
	~spectralBuffer = Buffer.alloc(server: s,numFrames: 1);
	~statsBuffer = Buffer.alloc(server: s, numFrames: 1);
	s.sync;
	FluidBufSpectralShape.process(
		server: s,
		source: ~sample,
		features: ~spectralBuffer,
		select: [\centroid, \spread]
	);
	s.sync;
	FluidBufStats.process(
		server: s,
		source: ~spectralBuffer,
		select: [\mean, \std],
		stats: ~statsBuffer
	);
	s.sync;
	~statsBuffer.loadToFloatArray(action: {|a|
		"Shape of ~statsBuffer is %".format(a.shape).postln;
	});
};
)



// putting it all together
(
~dataset = FluidDataSet(server: s);

fork {
	// reuse buffers accross analysis
	var spectralBuf = Buffer.alloc(server: s, numFrames: 1);
	var statsBuf = Buffer.alloc(server: s, numFrames: 1);
	var flattenBuf = Buffer.alloc(server: s, numFrames: 1);
	~sampleBuffers.do({|sampleBuffer, i|

		FluidBufSpectralShape.process(
			server: s,
			source: sampleBuffer,
			features: spectralBuf,
			select: [\centroid, \spread],
		);
		s.sync;

		FluidBufStats.process(
			server: s,
			source: spectralBuf,
			stats: statsBuf,
			select: [\mean, \std],
		);
		s.sync;

		FluidBufFlatten.process(
			server: s,
			source: statsBuf,
			destination: flattenBuf,
		);
		s.sync;

		~dataset.addPoint(
			identifier: i,
			buffer: flattenBuf,
		);
	});
	"finished processsing".postln;
};
)

().play;

~normalizedDataset = FluidDataSet(server: s);

~scaler = FluidStandardize(server: s).fit(~dataset);
~scaler.transform(sourceDataSet: ~dataset, destDataSet: ~normalizedDataset, action: {"finished".postln});

~dataset.dump

~normalizedDataset.dump

(
~pcaTranslated = FluidDataSet(server: s);

FluidPCA(server: s, numDimensions: 2).fitTransform(
	sourceDataSet: ~normalizedDataset,
	destDataSet: ~pcaTranslated,
);
)


(
~pcaTranslated.dump({|dict|
    defer{
		FluidPlotter(dict:dict, xmin: -1, ymin: -1);
	};
});
)

(
var clickPos = Buffer.alloc(server: s, numFrames: 2);

~pcaTranslated.dump({|dict|
    defer{
		FluidPlotter(dict:dict, xmin: -1, ymin: -1, mouseMoveAction: {|view, x, y, modifiers, buttonNumber, clickCount|
			var nearest;
			clickPos.sendCollection([x, y]);
			nearest = ~pcaTranslated.kNearest(clickPos, 1, {|nearestId|
				var buffer = ~sampleBuffers[nearestId.asInteger.postln];
				buffer.postln;
				if(clickCount.notNil, {buffer.play});
			});
		})
	};
});
)


~kickSamples


~pcaTranslated.dump

~normalizedDataset.dump


(
~normalizedDataset.dump({|dict|
	defer{FluidPlotter(dict: dict)};
});
)

~someBuf = Buffer.alloc(server: s, numFrames: 2);
~someBuf.loadCollection([0.3, 0.5])

~tree = FluidKDTree(s, numNeighbours: 1);
~tree.fit(dataSet: ~pcaTranslated)

~tree.kNearest(buffer: ~someBuf, k: 2, action: {|e| e.postln})

~tree.prGetParams

~pcaTranslated.dim

FluidDataSetQuery


(
~lookupDataset = FluidDataSet(s);
)

(
var playDict = Dictionary.newFrom(["cols", 1, "data", Dictionary.new]);

~pcaTranslated.dump({|d|
	d["data"].do({|k, v|
		playDict["data"][v.asString] = ~sampleBuffers[v].bufnum;
	});
	~playDataset = FluidDataSet(s).load(dict: playDict);
});
)

~playDataset.dump

~playDict[20] = ~buffers[20].bufNum;


~sampleBuffers.size

Ndef(\x).clear;
(
Ndef(\x, {
	var coordinate = LocalBuf(numFrames: 2);
	var sample = LocalBuf(numFrames: 2);
	var numSample;
	var trigger = Impulse.kr(\speed.kr(2.0));
	FluidKrToBuf.kr(
		krStream: SinOsc.kr(0.6, [0.0, pi])*10,
		buffer: coordinate,
	);
	~tree.kr(
		trig: trigger,
		inputBuffer: coordinate,
		outputBuffer: sample,
		numNeighbours: 2,
		lookupDataSet: ~playDataset
	);
	numSample = FluidBufToKr.kr(
		buffer: sample
	).poll(trig: 4.0,label: \sample);
	PlayBuf.ar(
		numChannels: 1,
		bufnum: numSample,
		trigger: trigger,
	);
}).play.gui;
)

Ndef(\x).clear;

FluidMLPClassifier


FluidPCA

~spectralBuffer

~statsBuffer

~sample.play;

~statsBuffer


FluidPlotterPoint




~targetBuffer.loadToFloatArray(action: {|a| a.shape});


Buffer
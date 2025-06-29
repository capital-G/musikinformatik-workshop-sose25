
// choose a directory of samples
~folder = "/path/to/sample/directory/";

// to avoid running out of buffers
s.options.numBuffers = 4096;
s.reboot;

// load into a buffer
~loader = FluidLoadFolder(~folder).play(s,{"done loading folder".postln});

// sum to mono (if not mono)
(
if(~loader.buffer.numChannels > 1){
	~src = Buffer(s);
	~loader.buffer.numChannels.do{
		arg chan_i;
		FluidBufCompose.processBlocking(s,
			~loader.buffer,
			startChan: chan_i,
			numChans: 1,
			gain: ~loader.buffer.numChannels.reciprocal,
			destination: ~src,
			destGain: 1,
			action:{"copied channel: %".format(chan_i).postln}
		);
	};
}{
	"loader buffer is already mono".postln;
	~src = ~loader.buffer;
};
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
optional:

(
fork{
	var indices = Buffer(s);
	var temp = Buffer(s);

	FluidBufAmpGate.processBlocking(
		server: s,
		source: ~src,
		indices:indices,
		onThreshold:-50,
		offThreshold:-55,
		minSliceLength:2400
	);
	s.sync;

	indices.loadToFloatArray(action:{ |fa|
		var curr = 0;
		fa.clump(2).do({ |arr,index|
			var start = arr[0];
			var num = arr[1] - start;
			FluidBufCompose.processBlocking(server: s,
				source: ~src,
				startFrame: start,
				numFrames: num,
				destination: temp,
				destStartFrame: curr
			);
			curr = curr + num;
			s.sync;
			"% / %\n".postf(index+1,(fa.size / 2).asInteger);
		});
		indices.free;
	});
	"Done stripping % samples!\n".postf(~src.numFrames - temp.numFrames);
	~src.free;
	~src = temp;
}
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
not optional:


// slice the buffer in non real-time
(
~indices = Buffer(s);
FluidBufOnsetSlice.processBlocking(s,
	source: ~src,
	metric: 2,
	threshold: 0.2,
	minSliceLength: 4,
	windowSize: 512,
	indices: ~indices,
	action:{
		"found % slice points".format(~indices.numFrames).postln;
		"average duration per slice: %".format(~src.duration / (~indices.numFrames+1)).postln;
});
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
optional:

(
~waveset = WavesetsEvent.new;
~waveset.setBuffer(~src, minLength:30);
)


(
var arr;
var newIndices;

~indices.loadToFloatArray(action: {|fa|
	defer {
		arr = fa.collect{|frame|
			var i = ~waveset.wavesets.nextStartCrossingIndex(frame);
			~waveset.wavesets.xings.clipAt(i-1);
		};

		arr = arr.keep(1) ++ arr.select{|x,i|
			var prev = arr.clipAt(i-1);
			(x != prev) && (x > prev)
		};

		fork {
			newIndices = Buffer.sendCollection(s, arr);
			s.sync;
			~indices.free;
			~indices = newIndices;
			s.sync;
		};
		arr[..9].do(_.postln);
	}
})
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
not optional:

// analyze buffer in non real-time
(
~dataset = FluidDataSet(s);

~indices.loadToFloatArray( action: { |fa|
	fa.doAdjacentPairs{ |start, end, i|
		var featuresBuffer = Buffer(s);
		var flatBuffer = Buffer(s);
        var meanMFCC = Buffer(s);

		// Extract MFCCs for this segment
		FluidBufMFCC.processBlocking(s,
			// source: ~src,
			source: ~src,
			startFrame: start,
			numFrames: end - start,
			features: featuresBuffer,
			numCoeffs: 13,
			startCoeff: 1,
			minFreq: 30,
			maxFreq: 16000,
			windowSize: 512,
		);

		// Convert MFCCs to a single feature vector (mean across frames)
		FluidBufStats.processBlocking(
			server: s,
			source: featuresBuffer,
			select: [\mean],
			stats: meanMFCC,
		);
		FluidBufFlatten.processBlocking(
			server: s,
			source: meanMFCC,
			destination: flatBuffer,
		);

        // add this point to the dataset
		~dataset.addPoint(i,flatBuffer);

        // free the buffers
		featuresBuffer.free;
		flatBuffer.free;
		meanMFCC.free;

		"% / %\n".postf(i+1, fa.size);
        // if you get warnings in the output,
        // you can decrease this number to sync more often
		if(i%5==0) {s.sync}
	};
	s.sync;
	~dataset.print;
});
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
optional:
skip to L.274 if you dont want / need backups

// Back up analysis data
(
var version = "0";
var folderName = PathName(~folder).folderName;
var parent = PathName(~folder).parentPath;
var dataPath = parent ++ folderName ++ "_data/";
var datasetPath = PathName(dataPath ++ "dataset_" ++ folderName ++ "_" ++ version ++ ".json").fullPath;
var sourcePath = PathName(dataPath ++ "source_" ++ folderName ++ "_" ++ version ++ ".wav").fullPath;
var indicesPath = PathName(dataPath ++ "indices_" ++ folderName ++ "_" ++ version ++ ".wav").fullPath;

// create directory
if(dataPath.pathExists == \folder) {
	"dataPath exists".postln;
} { dataPath.makeDir; "dataPath created".postln };

// back up dataset
if(datasetPath.pathExists == \file) {
	"this version of the dataset file already exists! Skipping …".postln;
} {
    ~dataset.write(datasetPath, action: { "Backup of ~dataset created!".postln; });
};

// back up soundfile
if(sourcePath.pathExists == \file) {
	"this version of the source file already exists! Skipping …".postln;
} {
    ~src.write(sourcePath, "wav", completionMessage: { "Backup of ~src created!".postln; })
};

// back up index array
if(indicesPath.pathExists == \file) {
	"this version of the indices file already exists! Skipping …".postln;
} {
    ~indices.write(indicesPath, "wav", completionMessage: { "Backup of ~indices created!".postln; })
};
)

// in the future you can start from here:
~folder = "/path/to/sample/directory_data/";

// to avoid running out of buffers
s.options.numBuffers = 4096;
s.boot;

(
// load data
var file, version = "0";
var dataPath = PathName(~folder).fullPath;
var folderName = PathName(~folder).folderName.split($_).first;
var datasetPath = PathName(dataPath ++ "dataset_" ++ folderName ++ "_v" ++ version ++ ".json").fullPath;
var sourcePath = PathName(dataPath ++ "source_" ++ folderName ++ "_v" ++ version ++ ".wav").fullPath;
var indicesPath = PathName(dataPath ++ "indices_" ++ folderName ++ "_v" ++ version ++ ".wav").fullPath;

if(dataPath.pathExists == \folder) {
	~dataset = FluidDataSet(s).read(datasetPath, action: { "dataset loaded!".postln; });
	~src = Buffer.read(s, sourcePath, action: { "Backup of ~src loaded!".postln; });
	~indices = Buffer.read(s, indicesPath, action: { "Backup of ~indices loaded!".postln; });
} {
	"This dataPath doesn't exist.".postln;
	"You need to back up an analysis for this ~folder first!".postln;
};
)

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
not optional:

// fit a kdtree
~kdtree = FluidKDTree(s);
~kdtree.fit(~dataset, action: { "KDTree ready!".postln; });

// create a dictionary
q = q ? ();

// store some different envelopes
(
Routine.run({
	q.perc = Buffer.sendCollection(s, Env.perc(0.001, curve: 0).discretize);
	s.sync;
	q.full = Buffer.sendCollection(s, Env.new([1,1,0],[1,0]).discretize);
	s.sync;
	q.sine = Buffer.sendCollection(s, Env.sine.discretize);
	s.sync;
	q.fitted = Buffer.sendCollection(s, Env.new([0,1,1,0],[0.01,0.98,0.01]).discretize);
});
)

(
// The Synth that will play the segment of the ~src buffer
SynthDef(\play_slice, {
    arg index, buf, idxBuf, envBuf=(-1),
    rate=1, repeats=1, amp=1, pos=0, out;

	var startsamp = Index.kr(idxBuf,index);
	var stopsamp = Index.kr(idxBuf,index+1);
	var phs = Phasor.ar(0,BufRateScale.ir(buf) * rate,startsamp,stopsamp);
	var sig = BufRd.ar(1,buf,phs);
	var dursecs = (stopsamp - startsamp) / BufSampleRate.ir(buf) / rate.abs * repeats;
	var env = BufRd.ar(1, envBuf, Line.ar(0, BufFrames.ir(envBuf) - 1, dursecs, doneAction: 2), loop:0);

	OffsetOut.ar(0, Pan2.ar(sig * env * amp, pos));
}).add;
)

(
// The Synth that will play the segment of the ~src buffer with a fixed duration
SynthDef(\play_slice_fixed_dur, {
    arg index, buf, idxBuf, envBuf=(-1),
    rate=1, repeats=1, amp=1, pos=0, dur, out;

	var startsamp = Index.kr(idxBuf,index);
	var stopsamp = Index.kr(idxBuf,index+1);
	var phs = Phasor.ar(0,BufRateScale.ir(buf) * rate,startsamp,stopsamp);
	var sig = BufRd.ar(1,buf,phs);
	var env = BufRd.ar(1, envBuf, Line.ar(0, BufFrames.ir(envBuf) - 1, dur, doneAction: 2), loop:0);

	OffsetOut.ar(0, Pan2.ar(sig * env * amp, pos));
}).add;
)


(
var nmfccs = 13;
var winSize = 512;
// var trate = s.sampleRate / winSize / 0.5;
var trate = 40;
var mfccBuf = Buffer.alloc(s,nmfccs);

// choose any of the newly created envelopes …
~env = ~env ? q.full;
// … an amplitude …
~amp = ~amp ? 0.5;
// … the number of neighbours in the kdtree to return
~numNeighbors = ~numNeighbors ? 1;

// just making sure that we free the buffer when we do Cmd+Period
CmdPeriod.doOnce({ mfccBuf.free });

~predict = { |continuous=0,out=0|
	{
		var sig = HPF.ar(SoundIn.ar(0), 30);
		var mfccs = FluidMFCC.kr(
			in: sig,
			startCoeff: 1,
			numCoeffs: nmfccs,
			minFreq: 30,
			maxFreq: 16000,
			windowSize: winSize
		);
		var loudness = FluidLoudness.kr(sig)[0];
		// You can adjust either this parameter or your input gain.
		// unfortunately this parameter cannot me set from the outside
		var thresh = -45;
		var isPredicting = (loudness >= thresh);
		// var trig = Select.kr(continuous, [DC.kr(1), Impulse.kr(40)]);
		var trig = Select.kr(continuous, [DC.kr(1), Impulse.kr(trate)]);
        // store the result into a buffer
		FluidKrToBuf.kr(mfccs, mfccBuf);
        // trigger the OSCdef when a trigger happens:
		SendReply.kr(isPredicting * trig, "/predict");
		// uncomment if you also want to hear the input (sig)
		Out.ar(out, Pan2.ar(sig, 1));
	}.play;
};

OSCdef(\predictions, { |msg|

	~kdtree.kNearest(mfccBuf, ~numNeighbors, { |indices|
		// indices need to be an array!
		// No matter if ~numNeighbours > 1 or not
		indices = indices.asInteger.bubble.flat;
		indices.postln; // uncomment if you want to see
		if(indices.size > 0) {
			indices.do{|index,i|
				Synth.grain(\play_slice, [
					\buf, ~src,
					\envBuf, ~env,
					\idxBuf, ~indices,
					\index, index,
					// for use with \play_slice_fixed_dur:
					// \dur, trate.reciprocal * 2,
					\pos, { 0.75.rand2 },
					\amp, ~amp / indices.size,
				])
			}
		}
	})
},"/predict");
)

~predict.(continuous:1, out:0);

~amp = 0.25;
~numNeighbors = 1;
~env = q.full;
~env.plot;


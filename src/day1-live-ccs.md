# Day 1 - Realtime CCS

The methods shown here are one way of realizing [real-time *corpus based concatenative synthesis*](https://www.ircam.fr/projects/pages/synthese-concatenative-par-corpus) in SuperCollider using the [FluCoMa](https://www.flucoma.org/) Toolchain.  

The Code shown here is mostly frankensteined from Todd Moores YouTube Tutorials on the [FluCoMa YT Channel](https://www.youtube.com/@FluidCorpusManipulation):  

- [2D Corpus Explorer (SuperCollider)](https://www.youtube.com/watch?v=9yoAGbs2eJ8&t=36s)  


<iframe width="560" height="315"  src="https://www.youtube.com/embed/9yoAGbs2eJ8" title="2D Corpus Explorer (SuperCollider) Part 1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


- [Classifying Sounds using a Neural Network in SuperCollider](https://www.youtube.com/watch?v=Y1cHmtbQPSk)


<iframe width="560" height="315"  src="https://www.youtube.com/embed/Y1cHmtbQPSk" title="Classifying Sounds using a Neural Network in SuperCollider" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
Motivation and inspiration was drawn from these examples aswell:  
- [Sound Into Sound](https://learn.flucoma.org/explore/constanzo/)
- [Corpus-Based Sampler Performance](https://www.youtube.com/watch?v=WMGHqyyn1TE)

<iframe width="560" height="315"  src="https://www.youtube.com/embed/WMGHqyyn1TE" title="Corpus-Based Sampler Performance" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


Audio material was mainly sourced from [Musicradar](https://www.musicradar.com/news/tech/free-music-samples-royalty-free-loops-hits-and-multis-to-download-sampleradar).

(prepare_sample)=
## 1. Sample library preparation

First we have to choose a folder of samples that we will use as reference material. This directory `~folder` (and it's sub-direcotries) should contain a variety of qualitatively different audio material in the same samplerate.  

```{note} 
`FluidBufCompose` does not interpolate, when writing the audio into a buffer consecutively. Non-matching samplerates will lead to a deviation in playback-rate and thus pitch and length.
```

In the next step, this material is summed to mono and written to a single Buffer `~src` which will first be segmented by onset detection and then analysed for certain spectral features.   

It makes sense to use a single buffer in this specific use case. If you are working with a library of files that each contain single percussive hits, a different approach is needed.   

```supercollider
// choose a directory of samples
~folder = "/path/to/sample/directory/";

// to avoid running out of buffers 
s.options.numBuffers = 4096;
s.boot;

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
```

(segment)=
### Segmentation
Next we will segment the newly created audiobuffer `~src` by onset detection and save the result in another buffer `~indices`.  
Confusion can arise  here because to SuperCollider users, buffers are commonly used for storing audio data only. Here we start using them for storing analysis data instead.  

The parameters of `FluidBufOnsetSlice` used here are tweaked to my library and read the [FluCoMa documentation for Onset Slicing](https://learn.flucoma.org/reference/onsetslice/)  for a better understanding of the different metrics.  
```supercollider
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
```

I have tweaked these values here to achieve an`average duration per slice` of about 0.2 Seconds and so that the number of slice points strongly exceeds the number of samples provided. This depends on the desired result of course.  
*My output*: 
```
found 2840 slice points
average duration per slice: 0.22336125043999
```

(strip)=
### Stripping silence (optional)
Depending on the material, it could be advantageous to remove silence (or rather "very low amplitude noise") from the buffer, as it will alter the spectral analysis aswell as the (optional) wavesets analysis.  

```supercollider
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
```

(wavesets)=
### Wavesets (optional) 
This can surely be improved upon, but note that `FluidBufOnsetSlice` doesn't care about zero-crossings. This can later lead to clicks and pops when playing a segment of the buffer `~src` without an envelope.  
Wavesets introduces a whole new set of options for the playback of audio buffers aswell, which will be explored in later projects.  

```{note} highpass
The quality of a wavesets analysis can be improved by applying a highpass-filter to your audio source material (see [*ffmpeg*](ffmpeg)) and stripping silence (see [*Stripping silence*](strip)).
```

```supercollider
/*
// install WavesetsEvent if you haven't already  
Quarks.install("WavesetsEvent");
*/
(
~waveset = WavesetsEvent.new;
~waveset.setBuffer(~src, minLength:10);
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
```

(spectral)=
## 2. Spectral analysis

Now that we have segmented the `~src` we will analyze it slice by slice for MFCC features and then perform some statistical analysis on these features:  
```supercollider
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
```

```{error} running out of buffers
When you're running out of buffers during this process, you need to reboot the server with a higher number of `s.options.numBuffers` (see [Sample library preparation](prepare_sample)) and repeat all previous steps.
```

Now that we have created our `~dataset`, we need to fit a  `FluidKDTree`:  
```supercollider
~kdtree = FluidKDTree(s);
~kdtree.fit(~dataset, action: { "KDTree ready!".postln; });
```

(backup)=
## 3. Backup (optional)

Now it could make sense to create a backup of our `~dataset` and the buffers `~src` and `~indices`.  

(save)=
### Saving
```supercollider
// Back up analysis data
(
var version = "0";
var folderName = PathName(~folder).folderName;
var parent = PathName(~folder).parentPath;
var dataPath = parent ++ folderName ++ "_data/";
var datasetPath = PathName(dataPath ++ "dataset_" ++ folderName ++ "_v" ++ version ++ ".json").fullPath;
var sourcePath = PathName(dataPath ++ "source_" ++ folderName ++ "_v" ++ version ++ ".wav").fullPath;
var indicesPath = PathName(dataPath ++ "indices_" ++ folderName ++ "_v" ++ version ++ ".wav").fullPath;

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
```

(load)=
### Loading
From now on, our newly created backup can be loaded as follows:
```supercollider
// in the future you can start from here:
~folder = "/path/to/sample/directory_data/";

(
// load data
var file, version = "0";
var dataPath = PathName(~folder).fullPath;
var folderName = PathName(~folder).folderName.split($_).first;
var datasetPath = PathName(dataPath ++ "dataset_" ++ folderName ++ "_" ++ version ++ ".json").fullPath;
var sourcePath = PathName(dataPath ++ "source_" ++ folderName ++ "_" ++ version ++ ".wav").fullPath;
var indicesPath = PathName(dataPath ++ "indices_" ++ folderName ++ "_" ++ version ++ ".wav").fullPath;

if(dataPath.pathExists == \folder) {
	~dataset = FluidDataSet(s).read(datasetPath, action: { "dataset loaded!".postln; });
	~src = Buffer.read(s, sourcePath, action: { "Backup of ~src loaded!".postln; });
	~indices = Buffer.read(s, indicesPath, action: { "Backup of ~indices loaded!".postln; });
} {
	"This dataPath doesn't exist.".postln;
	"You need to back up an analysis for this ~folder first!".postln;
};
)
```

After you've made sure the backup process works, you can basically delete the files that you've converted and collected, assuming they are a copy of an original.  

```{note} discussion
Some will say that writing backup files like this is not preferable. Instead we should have separate SuperCollider code for each analysis result we want to come back to, in order to keep things stateless. This implies that we will have to repeat the whole analysis each time before we can start making music. 
```

(prepare synth)=
## 4. Synthesis preparations

(env)=
### Envelopes
Creating a dictionary `q` to store some different envelopes:  

```supercollider 
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
```

(synth)=
### Synths
A `SynthDef` for playing a single segment:  
```supercollider 
(
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
```

This `Synth` will play a single segment of the `~src` buffer with a fixed duration:

```supercollider
(
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

```

(analyse)=
### realtime analysis functions
A `Synth` (or function) `~predict` that continuously analyses live-input for 13 MFCC bands and stores the result into a buffer.  
The buffer data is then compared with our `~dataset` which contains the average of the same 13 bands over the time span of each segment of `~src` respectively.   
It is important that the size of this mfcc buffer matches with `~dataset.cols`.  

`~predict.(continuous:0)` would trigger the prediction only once, when an input trigger occurs. This is more suitable for percussive audio input.  

Note that you have to re-evaluate this code block after every Cmd+Period, because the `OSCdef` is not persistent.  
```supercollider
(
var nmfccs = 13;
var winSize = 512;
// trig-rate according to the analysis window size:
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
		// indices need to be an array,
		// no matter if ~numNeighbours > 1 or not
		indices = indices.asInteger.bubble.flat;
		// indices.postln; // uncomment if you want to see
		if(indices.size > 0) {  
			indices.do{ |index|
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
```

(live)=
## 5. Live

Now we can play the function `~predict` and change some parameters on the fly:  
```supercollider
// continuous triggers:
~predict.(continuous:1);

// single triggers:
~predict.(continuous:0);

// the amplitude
~amp = 0.5;
// the number of nearest segments to return:
~numNeighbors = 1;
~numNeighbors = 3;
// the envelope:
~env = q.full;
~env = q.sine;
~env = q.fitted;
```

(ffmpeg)=
## 6. ffmpeg (optional)

These steps can be performed on our folder of samples before loading it into SuperCollider.  
### Easy ffmpeg sample rate conversion:   
```
cd /path/to/sample/directory
mkdir ../conv 
for i in *.wav 
do ffmpeg -i "$i" -ar 48000 "../conv/${i%.*}.wav" 
done
```

### … with hiphpass filter:
```
cd /path/to/sample/directory
mkdir ../conv
for i in *.wav 
do ffmpeg -i "$i" -af highpass=30 -ar 48000 "../conv/${i%.*}.wav" 
done
```
### … and normalization:
```
cd /path/to/sample/directory
mkdir ../conv
for i in *.wav 
do ffmpeg-normalize "$i" -prf highpass=f=30 -ar 48000 -of "../conv/${i%.*}.wav" 
done
```
   

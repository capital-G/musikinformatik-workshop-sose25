// using some object prototyping in order to make pca training a 2 liner
// and allow multiple PCA instances exist next to each other

// s.options.device = "BlackHole 16ch";
s.options.numInputBusChannels = 0;
s.boot;

().play;

(
~buildPca = {|samplesPath, numDims|
	(
		// members
		\numDims: numDims,
		\samplesPath: samplesPath,

		\samples: [],
		\dataset: FluidDataSet(server: Server.default),

		\datasetStandardized: FluidDataSet(server: Server.default),
		\standardizer: FluidStandardize(server: Server.default),

		\datasetPca: FluidDataSet(server: Server.default),
		\pca: FluidPCA(server: Server.default, numDimensions: numDims),

		\kdtree: FluidKDTree(server: s, numNeighbours: 1),

		// methods
		\analyze: {|self|
			// comeback of the JS callbackhell <3
			self.prLoadSamples({
				self.prBuildDataset({
					self.prTrainPCA({
						"GO FOR IT!".postln;
					})
				})
			});
		},

		save: {|self, path|
			"NOT IMPLEMENTED YET".postln;
		},

		restore: {|self, path|
			"NOT IMPLEMENTED YET".postln;
		}

		// private methods
		\prLoadSamples: {|self, callback|
			fork {
				PathName(self.samplesPath).filesDo({|file|
					self.samples = self.samples.add(
						// mono
						Buffer.readChannel(
							server: s,
							path: file.asAbsolutePath,
							channels: 0,
						);
					);
				});
				s.sync;
				"Loaded % samples".format(self.samples.size).postln;
				callback.value();
			}
		},
		\prBuildDataset: {|self, callback|
			fork {
				var spectralBuf = Buffer.alloc(server: Server.default, numFrames: 1);
				var statBuf = Buffer.alloc(server: Server.default, numFrames: 1);
				var flattenBuf = Buffer.alloc(server: Server.default, numFrames: 1);

				self.samples.do({|sample, i|
					"Processing sample (%/%): %".format(i, self.samples.size, sample.bufnum).postln;

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

					self.dataset.addPoint(
						identifier: sample.bufnum,
						buffer: flattenBuf,
					);
				});

				[spectralBuf, statBuf, flattenBuf].do({|b| b.free});

				s.sync;

				self[\prStandardizeDataset].value(self, callback);

			}
		},
		\prStandardizeDataset: {|self, callback|
			"Start standardizing dataset".postln;
			self[\standardizer].fitTransform(
				sourceDataSet: self[\dataset],
				destDataSet: self[\datasetStandardized],
				action: {
					"finished standardizing".postln;
					callback.value();
				},
			);
		},
		\prTrainPCA: {|self, callback|
			"Start training PCA".postln;
			self.pca.fitTransform(
				sourceDataSet: self.datasetStandardized,
				destDataSet: self.datasetPca,
				// function is not evaluated properly? :?
				action: callback,
			)
		}
	);
};
)

// no kwargs in 3.13 - but in 3.14 <3
~pca = ~buildPca.("/Users/scheiba/Downloads/doom3/sound/player/", 2);
~pca.analyze()
~pca.dataset;

// the PCA trained on the dataset reduced to two dimensions
~pca.pca;


// now use the prototype function to instantiate another PCA on a different dataset
~kicks = ~buildPca.("/Users/scheiba/supercollider/Creative Kicks/Analog Kicks/", 2);
~kicks.analyze();

~kicks.pca

/*
ToDo:

* Train kdtree as well
* maybe add a `.kr` method so the pca can be used within an ndef
* add a save and restore method which saves and restores all trained models (i.e. datasets, pca, kdtree, standardizer)
* What is a good way/pattern to expose more dataset pre-processing config to the user?
* Use this pattern to create a pipeline for dataset pre-processing
*/

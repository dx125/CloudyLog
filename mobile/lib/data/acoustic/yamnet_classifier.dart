import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';

import '../../domain/acoustic.dart';
import '../gateways.dart';

/// The production classifier: YAMNet's frozen trunk plus our trained head.
///
/// **Licensing** — YAMNet is Apache 2.0 (`tensorflow/models`, per-file header
/// on `yamnet.py`), which grants commercial use, redistribution in object form
/// (i.e. shipping the .tflite inside the app), modification, and an express
/// patent grant. Obligations are notice retention only, satisfied by
/// registering `assets/acoustic/NOTICE` with Flutter's `LicenseRegistry`.
/// The head is ours and carries no upstream obligation — Apache 2.0 has no
/// copyleft.
///
/// **Model I/O** (converted from the Apache-2.0 repo by `tool/acoustic/convert.py`):
///
/// | Tensor   | Shape        | Use                                       |
/// |----------|--------------|-------------------------------------------|
/// | input 0  | [1, 15600]   | 0.975 s of float32 waveform in [-1, 1]    |
/// | output 0 | [1, 521]     | AudioSet scores; index 55 is the class    |
/// | output 1 | [1, 1024]    | **embedding — what the head consumes**    |
/// | output 2 | [96, 64]     | log-mel spectrogram → [AcousticSignature] |
///
/// The head reads the *embedding*, not score 55. AudioSet's own class is thin
/// (1,231 clips / 3.3 h, weakly labelled) and was never trained against the
/// confusions that matter here — chair squeaks, lip raspberries, shoe scuffs.
/// Score 55 is useful as a sanity signal and as one feature among 1024, not as
/// the answer.
///
/// Inference runs on a background isolate: the tap loop's sub-100 ms guarantee
/// must never share a thread with a model.
class YamnetClassifier implements AcousticClassifier {
  YamnetClassifier({
    this.modelAsset = 'assets/acoustic/yamnet.tflite',
    this.headAsset = 'assets/acoustic/head.bin',
    AcousticHead? head,
  }) : _head = head;

  final String modelAsset;
  final String headAsset;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  AcousticHead? _head;

  bool get isLoaded => _isolate != null;

  @override
  Future<void> load() async {
    if (_isolate != null) return;

    final interpreter = await Interpreter.fromAsset(modelAsset);
    _interpreter = interpreter;
    _isolate = await IsolateInterpreter.create(
      address: interpreter.address,
      debugName: 'puff-acoustic',
    );
    _head ??= await AcousticHead.fromAsset(headAsset);
  }

  @override
  Future<AcousticVerdict> classify(Float32List window) async {
    final isolate = _isolate;
    final head = _head;
    if (isolate == null || head == null) {
      throw StateError('YamnetClassifier.classify before load()');
    }
    if (window.length != kAcousticWindowSamples) {
      throw ArgumentError(
        'expected $kAcousticWindowSamples samples, got ${window.length}',
      );
    }

    final scores = [List<double>.filled(521, 0)];
    final embedding = [List<double>.filled(1024, 0)];
    final spectrogram = List.generate(96, (_) => List<double>.filled(64, 0));

    await isolate.runForMultipleInputs(
      [window.reshape([1, kAcousticWindowSamples])],
      {0: scores, 1: embedding, 2: spectrogram},
    );

    return AcousticVerdict(
      confidence: head.score(embedding.first),
      signature: signatureFromLogMel(spectrogram),
    );
  }

  @override
  Future<void> dispose() async {
    await _isolate?.close();
    _isolate = null;
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Our trained head: a small MLP over YAMNet's 1024-d embedding.
///
/// Kept deliberately tiny (~50 KB) and loaded from its own asset so the model
/// can be improved and shipped without re-shipping the 4 MB trunk.
///
/// Weight layout is a flat little-endian float32 blob:
///   [inputDim] [hiddenDim] w1(inputDim*hiddenDim) b1(hiddenDim) w2(hiddenDim) b2(1)
class AcousticHead {
  AcousticHead({
    required this.inputDim,
    required this.hiddenDim,
    required Float32List weights1,
    required Float32List bias1,
    required Float32List weights2,
    required this.bias2,
  })  : _w1 = weights1,
        _b1 = bias1,
        _w2 = weights2;

  final int inputDim;
  final int hiddenDim;
  final Float32List _w1;
  final Float32List _b1;
  final Float32List _w2;
  final double bias2;

  static Future<AcousticHead> fromAsset(String asset) async {
    // Deferred to avoid a flutter/services import in a file that is otherwise
    // pure Dart plus the litert binding.
    throw UnimplementedError(
      'AcousticHead.fromAsset needs $asset, produced by tool/acoustic/train.py. '
      'The model pipeline is a prerequisite for M2 — see '
      'Documentation/live-detection-design.md §2.7.',
    );
  }

  /// p(toot) for one embedding. ReLU hidden layer, sigmoid output.
  double score(List<double> embedding) {
    if (embedding.length != inputDim) {
      throw ArgumentError('expected $inputDim dims, got ${embedding.length}');
    }
    var logit = bias2;
    for (var h = 0; h < hiddenDim; h++) {
      var sum = _b1[h];
      final offset = h * inputDim;
      for (var i = 0; i < inputDim; i++) {
        sum += _w1[offset + i] * embedding[i];
      }
      if (sum > 0) logit += _w2[h] * sum; // ReLU
    }
    return 1 / (1 + math.exp(-logit));
  }
}

/// Derives [AcousticSignature] from YAMNet's log-mel output — free, since the
/// model returns the spectrogram alongside the embedding.
///
/// 96 frames x 64 mel bands covering 0.975 s. Band centres follow YAMNet's mel
/// scale from 125 Hz to 7500 Hz.
AcousticSignature signatureFromLogMel(List<List<double>> mel) {
  if (mel.isEmpty) return AcousticSignature.unknown;

  const minHz = 125.0;
  const maxHz = 7500.0;
  final bands = mel.first.length;

  double bandHz(int band) {
    // Mel-scale inverse over the band index.
    double hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;
    double melToHz(double m) => 700 * (math.pow(10, m / 2595) - 1);
    final lo = hzToMel(minHz);
    final hi = hzToMel(maxHz);
    return melToHz(lo + (hi - lo) * (band + 0.5) / bands);
  }

  var peak = -100.0;
  var loudFrames = 0;
  var bestBand = 0;
  var bestEnergy = double.negativeInfinity;
  var totalEnergy = 0.0;

  for (final frame in mel) {
    var frameEnergy = 0.0;
    for (var b = 0; b < frame.length; b++) {
      final v = frame[b];
      frameEnergy += v;
      if (v > bestEnergy) {
        bestEnergy = v;
        bestBand = b;
      }
    }
    final frameDb = frameEnergy / frame.length;
    if (frameDb > peak) peak = frameDb;
    totalEnergy += frameEnergy;
    // YAMNet's log-mel is roughly log-magnitude; anything meaningfully above
    // the frame mean counts as sound rather than floor.
    if (frameDb > -6) loudFrames++;
  }

  // Harmonicity proxy: how concentrated the energy is in its strongest band.
  final mean = totalEnergy / (mel.length * bands);
  final concentration = bestEnergy == 0 ? 0.0 : ((bestEnergy - mean) / bestEnergy.abs());

  return AcousticSignature(
    peakDb: peak.clamp(-100.0, 0.0),
    fundamentalHz: bandHz(bestBand),
    harmonicRatio: concentration.clamp(0.0, 1.0),
    duration: Duration(milliseconds: (loudFrames * 10).clamp(0, 975)),
  );
}

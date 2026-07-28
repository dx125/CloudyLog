import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:puff/data/acoustic/heuristic_classifier.dart';
import 'package:puff/domain/acoustic.dart';

/// The heuristic classifier is a development stand-in, but it is real DSP and
/// the spike's baseline, so it gets real tests. These check it behaves sanely
/// on synthetic signals — not that it's accurate, which it isn't and can't be.
void main() {
  Float32List tone(double hz, {double amplitude = 0.5, int? samples}) {
    final n = samples ?? kAcousticWindowSamples;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = amplitude * math.sin(2 * math.pi * hz * i / kAcousticSampleRate);
    }
    return out;
  }

  Float32List noise({double amplitude = 0.5}) {
    final rng = math.Random(42);
    final out = Float32List(kAcousticWindowSamples);
    for (var i = 0; i < out.length; i++) {
      out[i] = amplitude * (rng.nextDouble() * 2 - 1);
    }
    return out;
  }

  late HeuristicClassifier classifier;

  setUp(() => classifier = HeuristicClassifier());

  test('silence is not a detection', () async {
    final verdict = await classifier.classify(
      Float32List(kAcousticWindowSamples),
    );
    expect(verdict.confidence, 0);
  });

  test('a near-silent window is rejected before scoring', () async {
    final verdict = await classifier.classify(tone(120, amplitude: 0.001));
    expect(verdict.confidence, 0);
  });

  test('an empty window is handled', () async {
    final verdict = await classifier.classify(Float32List(0));
    expect(verdict.confidence, 0);
  });

  test('estimates the pitch of a pure tone', () async {
    final verdict = await classifier.classify(tone(120));
    expect(verdict.signature.fundamentalHz, closeTo(120, 6));
    expect(verdict.signature.harmonicRatio, greaterThan(0.5));
  });

  test('estimates pitch across the plausible range', () async {
    for (final hz in const [80.0, 150.0, 220.0, 300.0]) {
      final verdict = await classifier.classify(tone(hz));
      expect(verdict.signature.fundamentalHz, closeTo(hz, hz * 0.08),
          reason: 'failed at $hz Hz');
    }
  });

  test('noise reads as inharmonic', () async {
    final verdict = await classifier.classify(noise());
    expect(verdict.signature.harmonicRatio, lessThan(0.5));
  });

  test('a loud low tone scores above the detection threshold', () async {
    final verdict = await classifier.classify(tone(110, amplitude: 0.8));
    expect(verdict.confidence, greaterThanOrEqualTo(kAcousticThreshold));
  });

  test('a very high tone scores below it', () async {
    final verdict = await classifier.classify(tone(3000, amplitude: 0.8));
    expect(verdict.confidence, lessThan(kAcousticThreshold));
  });

  test('never claims certainty', () async {
    for (final hz in const [90.0, 110.0, 130.0, 200.0]) {
      final verdict = await classifier.classify(tone(hz, amplitude: 0.95));
      expect(verdict.confidence, lessThanOrEqualTo(classifier.maxConfidence));
      expect(verdict.confidence, lessThan(1.0));
    }
  });

  test('peakDb tracks amplitude', () async {
    final loud = await classifier.classify(tone(120, amplitude: 0.9));
    final quiet = await classifier.classify(tone(120, amplitude: 0.05));
    expect(loud.signature.peakDb, greaterThan(quiet.signature.peakDb));
    expect(loud.signature.peakDb, lessThanOrEqualTo(0));
  });

  test('duration reflects how much of the window is loud', () async {
    final full = await classifier.classify(tone(120, amplitude: 0.6));
    expect(full.signature.duration.inMilliseconds, greaterThan(500));

    // A short burst padded with silence.
    final burst = Float32List(kAcousticWindowSamples);
    final source = tone(120, amplitude: 0.6, samples: 3200); // 200 ms
    burst.setRange(0, source.length, source);
    final short = await classifier.classify(burst);
    expect(short.signature.duration.inMilliseconds, lessThan(400));
  });
}

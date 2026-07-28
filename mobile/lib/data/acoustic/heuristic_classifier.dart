import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/acoustic.dart';
import '../gateways.dart';

/// A model-free classifier built from plain DSP.
///
/// **This is a development stand-in, not the production detector.** It exists
/// because [YamnetClassifier] needs a trained head, and that head needs the
/// spike plus a labelled corpus (live-detection-design.md §2.7) — so without
/// this, Listen mode and tag assist can't be exercised on a real device at all.
///
/// It is *deliberately* the approach the analysis rejected. Energy, pitch and
/// harmonicity cannot separate a toot from a chair squeak or a lip raspberry:
/// they share the same coarse spectral envelope. Expect roughly 60–75%
/// precision in a quiet room and considerably worse anywhere real. Shipping it
/// as the detector would produce exactly the phantom-detection-in-a-quiet-room
/// failure the whole design is organised to avoid.
///
/// Guardrails:
///  * selected only under `--dart-define=PUFF_ACOUSTIC_HEURISTIC=true`;
///    production builds get [YamnetClassifier].
///  * [maxConfidence] caps its output below certainty, so it reads as a guess.
///
/// It does have one lasting use: it is the baseline the spike measures the real
/// model against. If the trained head can't beat this, the head isn't ready.
class HeuristicClassifier implements AcousticClassifier {
  HeuristicClassifier({this.maxConfidence = 0.92});

  /// Ceiling on reported confidence — this method never earns certainty.
  final double maxConfidence;

  /// Plausible fundamental range, in Hz. Bounds the autocorrelation search.
  static const _minHz = 60.0;
  static const _maxHz = 400.0;

  @override
  Future<void> load() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<AcousticVerdict> classify(Float32List window) async {
    if (window.isEmpty) return AcousticVerdict.silence;

    final signature = _analyse(window);

    // Crude plausibility score. Rewards the things a toot tends to be —
    // low-ish pitch, meaningful energy, non-trivial duration — and penalises
    // the obviously-not: silence, very high pitch, single clicks.
    if (signature.peakDb < -40) return AcousticVerdict.silence;

    var score = 0.0;
    if (signature.fundamentalHz >= 60 && signature.fundamentalHz <= 300) {
      score += 0.45;
    } else if (signature.fundamentalHz > 0) {
      score += 0.15;
    }
    if (signature.peakDb > -25) score += 0.25;
    if (signature.duration.inMilliseconds > 150) score += 0.2;
    if (signature.harmonicRatio > 0.2 && signature.harmonicRatio < 0.9) {
      score += 0.1;
    }

    return AcousticVerdict(
      confidence: math.min(score, maxConfidence),
      signature: signature,
    );
  }

  AcousticSignature _analyse(Float32List w) {
    var peak = 0.0;
    for (final s in w) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    if (peak <= 1e-5) return AcousticSignature.unknown;

    // Duration: contiguous run of frames above a fraction of peak.
    const frame = 160; // 10 ms at 16 kHz
    final gate = peak * 0.15;
    var loudFrames = 0;
    for (var start = 0; start + frame <= w.length; start += frame) {
      var frameMax = 0.0;
      for (var i = start; i < start + frame; i++) {
        final a = w[i].abs();
        if (a > frameMax) frameMax = a;
      }
      if (frameMax > gate) loudFrames++;
    }

    final (f0, harmonicity) = _autocorrelationPitch(w);

    return AcousticSignature(
      peakDb: amplitudeToDb(peak),
      fundamentalHz: f0,
      harmonicRatio: harmonicity,
      duration: Duration(milliseconds: loudFrames * 10),
    );
  }

  /// Autocorrelation pitch estimate. Returns (fundamentalHz, harmonicity),
  /// with 0 Hz when nothing periodic stands out.
  (double, double) _autocorrelationPitch(Float32List w) {
    final minLag = (kAcousticSampleRate / _maxHz).floor();
    final maxLag = (kAcousticSampleRate / _minHz).ceil();
    if (w.length <= maxLag) return (0, 0);

    // Energy at zero lag normalises the correlation into 0..1.
    var energy = 0.0;
    for (final s in w) {
      energy += s * s;
    }
    if (energy <= 1e-9) return (0, 0);

    var bestLag = 0;
    var bestCorr = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var corr = 0.0;
      for (var i = 0; i + lag < w.length; i += 2) {
        corr += w[i] * w[i + lag];
      }
      corr = corr * 2 / energy; // *2 compensates the stride-2 sampling
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag == 0 || bestCorr < 0.15) return (0, bestCorr.clamp(0.0, 1.0));
    return (kAcousticSampleRate / bestLag, bestCorr.clamp(0.0, 1.0));
  }
}

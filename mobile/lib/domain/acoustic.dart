import 'dart:math' as math;

/// Acoustic detection domain — pure Dart, no plugins, no model, no I/O.
///
/// The pipeline this describes (Design Book / live-detection-design.md §2) is a
/// cascade: a cheap energy gate runs on every frame, and only an onset wakes the
/// expensive classifier. That ordering is what makes continuous listening
/// affordable — in a quiet room the model never runs at all.

/// Everything downstream assumes 16 kHz mono, because that's YAMNet's input.
const int kAcousticSampleRate = 16000;

/// YAMNet's window: 0.975 s at 16 kHz. The classifier takes exactly this many
/// samples, so the ring buffer is sized to always be able to produce one.
const int kAcousticWindowSamples = 15600;

/// How far back the ring buffer reaches before an onset. A toot's attack is the
/// most informative part of it, so the window must start *before* the gate
/// noticed anything — otherwise every clip is missing its own beginning.
const Duration kAcousticLookback = Duration(milliseconds: 480);

/// Minimum gap between two detections. Below this they're echoes of one event,
/// not two events — and a runaway detector is worse than a quiet one.
const Duration kAcousticRefractory = Duration(milliseconds: 1200);

/// Confidence a verdict must clear to become a detection.
///
/// Deliberately high. The analysis is explicit that precision beats recall
/// here: a missed toot is a shrug ("didn't catch that one?"), while a phantom
/// one in a quiet room full of friends is a screenshot and a one-star review.
const double kAcousticThreshold = 0.80;

/// What the acoustics say about one detected sound.
///
/// These come out of the classifier's log-mel output, which YAMNet hands back
/// for free alongside the embedding — so the tag features cost no extra
/// inference.
class AcousticSignature {
  const AcousticSignature({
    required this.peakDb,
    required this.fundamentalHz,
    required this.harmonicRatio,
    required this.duration,
  });

  /// Peak level in dBFS (-100..0). Loudness is the main thing separating a
  /// thunder from a squeak, which is why capture must run with automatic gain
  /// control *off* — AGC would flatten exactly this.
  final double peakDb;

  /// Estimated fundamental, or 0 when the sound is inharmonic.
  final double fundamentalHz;

  /// 0..1 — how tonal versus noisy the sound is.
  final double harmonicRatio;

  final Duration duration;

  static const AcousticSignature unknown = AcousticSignature(
    peakDb: -100,
    fundamentalHz: 0,
    harmonicRatio: 0,
    duration: Duration.zero,
  );
}

/// The classifier's answer for one window.
class AcousticVerdict {
  const AcousticVerdict({
    required this.confidence,
    required this.signature,
  });

  /// 0..1 from our trained head — *not* YAMNet's raw class-55 score.
  final double confidence;
  final AcousticSignature signature;

  static const AcousticVerdict silence = AcousticVerdict(
    confidence: 0,
    signature: AcousticSignature.unknown,
  );
}

/// One confirmed detection: a verdict that cleared the threshold and the
/// refractory window.
class AcousticDetection {
  const AcousticDetection({
    required this.id,
    required this.at,
    required this.confidence,
    required this.signature,
  });

  /// The id of the [PuffEvent] this wrote, so the UI can offer undo.
  final String id;
  final DateTime at;
  final double confidence;
  final AcousticSignature signature;

  /// The quick tag this sound looks like, or null. See [suggestedTag].
  String? get tag => suggestedTag(signature);
}

/// Maps acoustics onto the design book's tag vocabulary.
///
/// This is the whole of Design A's intelligence, and it is deliberately a pure
/// function over four numbers so it can be tuned against the eval set rather
/// than guessed at in a widget.
///
/// Returns null when nothing reads clearly — a suggestion is never forced, and
/// "no idea" is an honest answer that costs the user nothing.
///
/// **`silent` and `sbd` are never returned.** They are, by definition,
/// acoustically undetectable; claiming to hear one would be the product lying
/// about itself.
String? suggestedTag(AcousticSignature s) {
  if (s.duration == Duration.zero) return null;

  final ms = s.duration.inMilliseconds;

  // Low, loud and long — the unmistakable one.
  if (s.peakDb > -12 && s.fundamentalHz > 0 && s.fundamentalHz < 120 && ms > 800) {
    return 'thunder';
  }
  // High and tonal.
  if (s.fundamentalHz > 180 && s.harmonicRatio > 0.5) {
    return 'squeaky';
  }
  // Mostly turbulence, no pitch to speak of.
  if (s.harmonicRatio < 0.3) {
    return 'windy';
  }
  return null;
}

/// The cascade's first stage: a cheap, adaptive energy gate.
///
/// Tracks a rolling noise floor and reports a rising edge when the signal
/// sustains [thresholdRatio] above it for [minFrames] consecutive frames.
///
/// Floor adaptation is the subtle part, and it has to satisfy two opposing
/// requirements:
///
///  * A loud *event* must not raise the floor, or the detector deafens itself
///    for the seconds after every sound it hears.
///  * A loud *room* must raise it, or the detector fires once on entering a
///    café and then goes permanently deaf — worse than useless, because it
///    looks like it's working.
///
/// The discriminator is duration: nothing we're listening for lasts more than
/// about three seconds. So the floor adapts while quiet, freezes during a
/// plausible event, and resumes once loudness outlasts [sustainedFrames] —
/// at which point it isn't an event, it's the room.
class OnsetDetector {
  OnsetDetector({
    this.thresholdRatio = 3.0,
    this.minFrames = 2,
    this.floorAdaptation = 0.05,
    this.sustainedFrames = 150,
    double initialFloor = 0.005,
  }) : _floor = initialFloor;

  /// How far above the noise floor counts as an onset.
  final double thresholdRatio;

  /// Consecutive loud frames required — rejects single-frame clicks and pops.
  final int minFrames;

  /// How fast the floor tracks the room, per adapting frame (0..1).
  final double floorAdaptation;

  /// Loud frames after which the level is treated as the room rather than an
  /// event. Defaults to ~3 s of 20 ms frames.
  final int sustainedFrames;

  double _floor;
  int _loudFrames = 0;
  bool _armed = true;

  double get noiseFloor => _floor;

  /// Feeds one frame's RMS. Returns true exactly once per rising edge.
  bool accept(double rms) {
    final loud = rms > _floor * thresholdRatio;

    if (!loud) {
      _loudFrames = 0;
      _armed = true;
      _adapt(rms);
      return false;
    }

    _loudFrames++;

    // Outlasted any plausible event — this is the room, so let the floor climb.
    if (_loudFrames > sustainedFrames) {
      _armed = false;
      _adapt(rms);
      return false;
    }

    if (_armed && _loudFrames >= minFrames) {
      _armed = false; // one edge per burst
      return true;
    }
    return false;
  }

  void _adapt(double rms) {
    _floor = _floor * (1 - floorAdaptation) + rms * floorAdaptation;
    if (_floor < 1e-6) _floor = 1e-6;
  }

  void reset() {
    _loudFrames = 0;
    _armed = true;
  }
}

/// Root-mean-square of one PCM16 frame, normalised to 0..1.
double frameRms(List<int> pcm16) {
  if (pcm16.isEmpty) return 0;
  var sum = 0.0;
  for (final sample in pcm16) {
    final v = sample / 32768.0;
    sum += v * v;
  }
  return math.sqrt(sum / pcm16.length);
}

/// Converts a 0..1 amplitude to dBFS, floored at -100.
double amplitudeToDb(double amplitude) {
  if (amplitude <= 1e-5) return -100;
  return 20 * (math.log(amplitude) / math.ln10);
}

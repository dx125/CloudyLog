import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/acoustic.dart';

void main() {
  AcousticSignature sig({
    double peakDb = -20,
    double fundamentalHz = 150,
    double harmonicRatio = 0.4,
    int ms = 500,
  }) =>
      AcousticSignature(
        peakDb: peakDb,
        fundamentalHz: fundamentalHz,
        harmonicRatio: harmonicRatio,
        duration: Duration(milliseconds: ms),
      );

  group('suggestedTag', () {
    test('low, loud and long reads as thunder', () {
      expect(
        suggestedTag(sig(peakDb: -8, fundamentalHz: 90, ms: 1200)),
        'thunder',
      );
    });

    test('high and tonal reads as squeaky', () {
      expect(
        suggestedTag(sig(fundamentalHz: 240, harmonicRatio: 0.7)),
        'squeaky',
      );
    });

    test('inharmonic reads as windy', () {
      expect(suggestedTag(sig(harmonicRatio: 0.1)), 'windy');
    });

    test('ambiguous returns null rather than guessing', () {
      expect(suggestedTag(sig(fundamentalHz: 150, harmonicRatio: 0.4)), isNull);
    });

    test('a zero-duration signature returns null', () {
      expect(suggestedTag(AcousticSignature.unknown), isNull);
    });

    // The product must not claim to hear what is by definition inaudible.
    test('never suggests silent or sbd', () {
      final samples = [
        for (var db = -60.0; db <= 0; db += 5)
          for (var hz = 0.0; hz <= 400; hz += 20)
            for (var hr = 0.0; hr <= 1.0; hr += 0.1)
              for (final ms in const [50, 300, 900, 2500])
                sig(peakDb: db, fundamentalHz: hz, harmonicRatio: hr, ms: ms),
      ];
      for (final s in samples) {
        final tag = suggestedTag(s);
        expect(tag, isNot('silent'));
        expect(tag, isNot('sbd'));
      }
    });

    test('only ever returns a known tag or null', () {
      const known = {'thunder', 'squeaky', 'windy'};
      for (var hz = 0.0; hz <= 400; hz += 10) {
        for (var hr = 0.0; hr <= 1.0; hr += 0.1) {
          final tag = suggestedTag(sig(fundamentalHz: hz, harmonicRatio: hr));
          if (tag != null) expect(known, contains(tag));
        }
      }
    });
  });

  group('OnsetDetector', () {
    test('fires once on a rising edge, not once per loud frame', () {
      final detector = OnsetDetector(minFrames: 2);
      for (var i = 0; i < 40; i++) {
        detector.accept(0.005);
      }

      var edges = 0;
      for (var i = 0; i < 10; i++) {
        if (detector.accept(0.5)) edges++;
      }
      expect(edges, 1);
    });

    test('re-arms after the sound stops', () {
      final detector = OnsetDetector(minFrames: 2);
      for (var i = 0; i < 40; i++) {
        detector.accept(0.005);
      }

      var edges = 0;
      for (var i = 0; i < 5; i++) {
        if (detector.accept(0.5)) edges++;
      }
      for (var i = 0; i < 20; i++) {
        detector.accept(0.005);
      }
      for (var i = 0; i < 5; i++) {
        if (detector.accept(0.5)) edges++;
      }
      expect(edges, 2);
    });

    test('a single loud frame is rejected as a click', () {
      final detector = OnsetDetector(minFrames: 2);
      for (var i = 0; i < 40; i++) {
        detector.accept(0.005);
      }
      expect(detector.accept(0.9), isFalse);
      expect(detector.accept(0.001), isFalse);
    });

    // Walking into a café: the level rises and stays risen. The floor has to
    // follow, or the gate fires once and is then deaf for the whole visit.
    test('adapts to a persistently loud room instead of going deaf', () {
      final detector = OnsetDetector(minFrames: 2, sustainedFrames: 150);
      for (var i = 0; i < 800; i++) {
        detector.accept(0.05);
      }
      expect(detector.noiseFloor, greaterThan(0.01),
          reason: 'the floor should have risen toward the room level');
      expect(detector.accept(0.06), isFalse,
          reason: 'ambient level must not read as an onset');
    });

    // A toot is short. Nothing about hearing one should move the floor, or the
    // detector spends the next few seconds unable to hear the next one.
    test('an event-length burst does not drag the floor up behind it', () {
      final detector = OnsetDetector(minFrames: 2, sustainedFrames: 150);
      for (var i = 0; i < 40; i++) {
        detector.accept(0.005);
      }
      final floorBefore = detector.noiseFloor;
      for (var i = 0; i < 100; i++) {
        detector.accept(0.8); // ~2 s — a long toot, still an event
      }
      expect(detector.noiseFloor, closeTo(floorBefore, 1e-9));
    });

    test('the gate still hears a second sound after a loud burst', () {
      final detector = OnsetDetector(minFrames: 2, sustainedFrames: 150);
      for (var i = 0; i < 40; i++) {
        detector.accept(0.005);
      }
      for (var i = 0; i < 100; i++) {
        detector.accept(0.8);
      }
      for (var i = 0; i < 10; i++) {
        detector.accept(0.005);
      }

      var fired = false;
      for (var i = 0; i < 5; i++) {
        if (detector.accept(0.5)) fired = true;
      }
      expect(fired, isTrue);
    });
  });

  group('frame helpers', () {
    test('frameRms of silence is zero', () {
      expect(frameRms(List.filled(320, 0)), 0);
    });

    test('frameRms of a constant frame is its amplitude', () {
      expect(frameRms(List.filled(320, 16384)), closeTo(0.5, 0.001));
    });

    test('frameRms of an empty frame is zero', () {
      expect(frameRms(const []), 0);
    });

    test('amplitudeToDb floors at -100', () {
      expect(amplitudeToDb(0), -100);
      expect(amplitudeToDb(1.0), closeTo(0, 0.001));
      expect(amplitudeToDb(0.5), closeTo(-6.02, 0.05));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/acoustic.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/listen_service.dart';
import 'package:puff/services/tap_service.dart';

import 'fakes.dart';

void main() {
  late InMemoryEventStore store;
  late FakeAudioCaptureGateway capture;
  late FakeAcousticClassifier classifier;
  late TapService tap;
  late DateTime now;
  late List<String> recorded;

  /// Frames sized so the ring fills quickly: 15600 samples / 1560 = 10 frames.
  const frameSamples = 1560;

  ListenService build({bool isPro = false}) => ListenService(
        capture,
        classifier,
        tap,
        isPro: () => isPro,
        clock: () => now,
        onError: (source, error, stack) => recorded.add(source),
      );

  /// Quiet frames settle the noise floor *and* fill the ring buffer, which is
  /// what the real cascade needs before it can classify anything.
  Future<void> warmUp() => capture.emitQuiet(40, samples: frameSamples);

  /// A burst loud enough to clear the gate's 3x threshold.
  Future<void> burst(ListenService service) async {
    await capture.emit(0.5, samples: frameSamples);
    await capture.emit(0.5, samples: frameSamples);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    store = InMemoryEventStore();
    capture = FakeAudioCaptureGateway();
    classifier = FakeAcousticClassifier();
    now = DateTime(2026, 7, 20, 12);
    recorded = [];
    tap = TapService(store, deviceId: 'dev-1', clock: () => now);
    await tap.load();
  });

  tearDown(() => capture.close());

  group('permission', () {
    test('a denied mic leaves the service in permissionDenied', () async {
      capture.permitted = false;
      final service = build();

      await service.start();

      expect(service.state, ListenState.permissionDenied);
      expect(capture.permissionAsked, isTrue);
      expect(capture.started, isFalse);
    });

    test('denial does not break the tap loop', () async {
      capture.permitted = false;
      final service = build();
      await service.start();

      await tap.tap();
      expect(tap.todayCount, 1);
    });
  });

  group('detection cascade', () {
    test('a confident verdict becomes a logged heard event', () async {
      final service = build();
      classifier.enqueue(0.95);
      await service.start();
      await warmUp();
      await burst(service);

      expect(service.sessionCount, 1);
      expect(tap.todayHeardCount, 1);
      expect(tap.todayCount, 0, reason: 'heard must not touch the tap count');

      final event = store.events.values.single;
      expect(event.source, EventSource.heard);
    });

    test('a verdict below the threshold is discarded', () async {
      final service = build();
      classifier.enqueue(0.4);
      await service.start();
      await warmUp();
      await burst(service);

      expect(service.sessionCount, 0);
      expect(store.events, isEmpty);
      expect(classifier.classifyCalls, 1,
          reason: 'the model still ran; only its answer was rejected');
    });

    test('quiet never wakes the classifier', () async {
      final service = build();
      await service.start();
      await capture.emitQuiet(60, samples: frameSamples);

      expect(classifier.classifyCalls, 0,
          reason: 'the gate must keep the model asleep in a quiet room');
      expect(service.sessionCount, 0);
    });

    test('the refractory window collapses one sound heard twice', () async {
      final service = build();
      classifier
        ..enqueue(0.95)
        ..enqueue(0.95);
      await service.start();
      await warmUp();

      await burst(service);
      await capture.emitQuiet(5, samples: frameSamples);
      now = now.add(const Duration(milliseconds: 300)); // inside refractory
      await burst(service);

      expect(service.sessionCount, 1);
    });

    test('a second sound after the refractory window is its own event',
        () async {
      final service = build();
      classifier
        ..enqueue(0.95)
        ..enqueue(0.95);
      await service.start();
      await warmUp();

      await burst(service);
      await capture.emitQuiet(5, samples: frameSamples);
      now = now.add(const Duration(seconds: 3));
      await burst(service);

      expect(service.sessionCount, 2);
      expect(tap.todayHeardCount, 2);
    });

    test('a detected tag rides along onto the event', () async {
      final service = build();
      classifier.enqueue(
        0.95,
        signature: const AcousticSignature(
          peakDb: -8,
          fundamentalHz: 90,
          harmonicRatio: 0.4,
          duration: Duration(milliseconds: 1200),
        ),
      );
      await service.start();
      await warmUp();
      await burst(service);

      expect(store.events.values.single.tags, ['thunder']);
    });
  });

  group('assist mode', () {
    test('writes nothing but still reports a recent detection', () async {
      final service = build();
      classifier.enqueue(0.95);
      await service.start(mode: ListenMode.assist);
      await warmUp();
      await burst(service);

      expect(store.events, isEmpty,
          reason: 'assist must never write — a wrong tag would corrupt the log');
      expect(tap.todayHeardCount, 0);
      expect(service.recentDetection(), isNotNull);
    });

    test('a stale detection is not offered as a suggestion', () async {
      final service = build();
      classifier.enqueue(0.95);
      await service.start(mode: ListenMode.assist);
      await warmUp();
      await burst(service);

      now = now.add(const Duration(seconds: 30));
      expect(service.recentDetection(), isNull);
    });
  });

  group('free-tier budget', () {
    test('a free session ends when the budget runs out', () async {
      final service = build();
      await service.start();
      expect(service.remaining, const Duration(minutes: 5));

      now = now.add(const Duration(minutes: 6));
      await capture.emit(0.001, samples: frameSamples);

      expect(service.budgetExhausted, isTrue);
      expect(service.state, ListenState.idle);
      expect(capture.stopped, isTrue);
    });

    test('Pro has no budget at all', () async {
      final service = build(isPro: true);
      await service.start();
      expect(service.remaining, isNull);

      now = now.add(const Duration(hours: 2));
      await capture.emit(0.001, samples: frameSamples);

      expect(service.budgetExhausted, isFalse);
      expect(service.state, ListenState.listening);
    });
  });

  group('undo', () {
    test('undo deletes the event and drops it from the session', () async {
      final service = build();
      classifier.enqueue(0.95);
      await service.start();
      await warmUp();
      await burst(service);

      final id = service.detections.single.id;
      await service.undo(id);

      expect(service.sessionCount, 0);
      expect(store.events, isEmpty);
      expect(tap.todayHeardCount, 0);
    });
  });

  group('failures are recorded, never swallowed', () {
    test('a classifier failure is recorded and the session survives', () async {
      classifier.failOnClassify = true;
      final service = build();
      await service.start();
      await warmUp();
      await burst(service);

      expect(recorded, contains('listen.classify'));
      expect(service.state, ListenState.listening,
          reason: 'one bad window must not dump the user out of the screen');
    });
  });

  group('lifecycle', () {
    test('stop releases the microphone', () async {
      final service = build();
      await service.start();
      await service.stop();

      expect(capture.stopped, isTrue);
      expect(service.state, ListenState.idle);
      expect(service.level, 0);
    });

    test('starting twice does not open a second capture', () async {
      final service = build();
      await service.start();
      capture.started = false;
      await service.start();

      expect(capture.started, isFalse);
    });

    test('a new session clears the previous one', () async {
      final service = build();
      classifier.enqueue(0.95);
      await service.start();
      await warmUp();
      await burst(service);
      expect(service.sessionCount, 1);

      await service.stop();
      await service.start();
      expect(service.sessionCount, 0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:puff/l10n/generated/app_localizations.dart';
import 'package:puff/presentation/screens/listen_screen.dart';
import 'package:puff/services/entitlement_service.dart';
import 'package:puff/services/listen_service.dart';
import 'package:puff/services/tap_service.dart';
import 'package:puff/theme/puff_theme.dart';

import 'fakes.dart';

void main() {
  late InMemoryEventStore store;
  late FakeAudioCaptureGateway capture;
  late FakeAcousticClassifier classifier;
  late InMemorySettingsRepository settings;
  late TapService tap;
  late ListenService listen;
  late EntitlementService entitlement;
  late DateTime now;

  const frameSamples = 1560;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ListenService>.value(value: listen),
          ChangeNotifierProvider<EntitlementService>.value(value: entitlement),
          ChangeNotifierProvider<TapService>.value(value: tap),
        ],
        child: MaterialApp(
          theme: puffTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ListenScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    store = InMemoryEventStore();
    capture = FakeAudioCaptureGateway();
    classifier = FakeAcousticClassifier();
    settings = InMemorySettingsRepository();
    now = DateTime(2026, 7, 20, 12);
    tap = TapService(store, deviceId: 'dev-1', clock: () => now);
    await tap.load();
    entitlement = EntitlementService(settings, FakePurchaseGateway());
    await entitlement.load();
    listen = ListenService(
      capture,
      classifier,
      tap,
      isPro: () => entitlement.isPro,
      clock: () => now,
    );
  });

  tearDown(() => capture.close());

  testWidgets('starts listening on open', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(capture.started, isTrue);
    expect(listen.state, ListenState.listening);
  });

  testWidgets('a denied mic explains itself instead of failing silently',
      (tester) async {
    capture.permitted = false;
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    final strings = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(strings.listenDeniedTitle), findsOneWidget);
  });

  testWidgets('shows the empty state before anything is heard', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    final strings = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(strings.listenEmpty), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('a detection appears in the list with an undo', (tester) async {
    classifier.enqueue(0.95);
    await pumpScreen(tester);
    await tester.pump();

    await capture.emitQuiet(40, samples: frameSamples);
    await capture.emit(0.5, samples: frameSamples);
    await capture.emit(0.5, samples: frameSamples);
    await tester.pumpAndSettle();

    final strings = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('1'), findsOneWidget);
    expect(find.text(strings.listenUndo), findsOneWidget);
  });

  testWidgets('undo removes the detection and the event', (tester) async {
    classifier.enqueue(0.95);
    await pumpScreen(tester);
    await tester.pump();

    await capture.emitQuiet(40, samples: frameSamples);
    await capture.emit(0.5, samples: frameSamples);
    await capture.emit(0.5, samples: frameSamples);
    await tester.pumpAndSettle();

    final strings = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(strings.listenUndo));
    await tester.pumpAndSettle();

    expect(listen.sessionCount, 0);
    expect(store.events, isEmpty);
  });

  testWidgets('free tier sees a countdown, Pro does not', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('s left'), findsOneWidget);
  });

  testWidgets('leaving the screen releases the microphone', (tester) async {
    await pumpScreen(tester);
    await tester.pump();
    expect(capture.started, isTrue);

    await tester.pumpWidget(const SizedBox());
    // dispose() can't await its stop(), and StreamSubscription.cancel()
    // completes on a real event-loop turn — which the fake clock inside
    // testWidgets never delivers. runAsync steps out to real async so the
    // cancellation can actually land.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(capture.stopped, isTrue);
  });
}

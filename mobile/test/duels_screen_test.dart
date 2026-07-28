import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:puff/domain/duel.dart';
import 'package:puff/l10n/generated/app_localizations.dart';
import 'package:puff/presentation/screens/duels_screen.dart';
import 'package:puff/services/duel_service.dart';
import 'package:puff/services/entitlement_service.dart';
import 'package:puff/theme/puff_theme.dart';

import 'fakes.dart';

void main() {
  late InMemoryEventStore store;
  late FakeDuelGateway gateway;
  late InMemorySettingsRepository settings;
  late DuelService duels;
  late EntitlementService entitlement;

  Future<AppLocalizations> strings() =>
      AppLocalizations.delegate.load(const Locale('en'));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DuelService>.value(value: duels),
          ChangeNotifierProvider<EntitlementService>.value(value: entitlement),
        ],
        child: MaterialApp(
          theme: puffTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DuelsScreen()),
        ),
      ),
    );
    // Not pumpAndSettle: the empty state's FloatingGust bobs forever, so
    // "settled" never arrives.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    store = InMemoryEventStore();
    gateway = FakeDuelGateway();
    settings = InMemorySettingsRepository();
    duels = DuelService(gateway, store);
    entitlement = EntitlementService(settings, FakePurchaseGateway());
    await entitlement.load();
  });

  testWidgets('empty state invites a first duel', (tester) async {
    await pump(tester);
    final s = await strings();
    expect(find.text(s.duelsEmptyTitle), findsOneWidget);
  });

  testWidgets('joining is always offered, Pro or not', (tester) async {
    await pump(tester);
    final s = await strings();
    // The invited person is the acquisition — a join must never hit a paywall.
    expect(find.text(s.duelJoin), findsOneWidget);
  });

  testWidgets('a free user is told creating is Pro', (tester) async {
    await pump(tester);
    final s = await strings();
    expect(find.text(s.duelProOnly), findsOneWidget);
  });

  testWidgets('duels appear with their curated name', (tester) async {
    await duels.create(kind: DuelKind.async);
    await duels.refresh();
    await pump(tester);

    expect(find.text(duelName(0, 0)), findsOneWidget);
  });

  testWidgets('a duel with one member reads as waiting', (tester) async {
    await duels.create(kind: DuelKind.async);
    await duels.refresh();
    await pump(tester);

    final s = await strings();
    expect(find.text(s.duelWaiting), findsOneWidget);
  });

  testWidgets('live duels are badged differently from weeks', (tester) async {
    await duels.create(kind: DuelKind.live);
    await duels.refresh();
    await pump(tester);

    final s = await strings();
    expect(find.text(s.duelKindLive), findsOneWidget);
    expect(find.text(s.duelKindAsync), findsNothing);
  });

  group('standing lines', () {
    final now = DateTime(2026, 7, 20, 12);

    Duel duelWith(List<DuelScore> scores) => Duel(
          id: 'd',
          code: 'ABC234',
          kind: DuelKind.async,
          nameAdjective: 0,
          nameNoun: 0,
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(const Duration(days: 6)),
          status: DuelStatus.open,
          scores: scores,
        );

    testWidgets('names the leader when someone is ahead', (tester) async {
      final s = await strings();
      final line = duelStandingLine(
        s,
        duelWith(const [
          DuelScore(userId: 'a', handle: 0, tapped: 9),
          DuelScore(userId: 'b', handle: 1, tapped: 2),
        ]),
      );
      expect(line, s.duelLeading(duelHandle(0)));
    });

    testWidgets('says tied when level', (tester) async {
      final s = await strings();
      final line = duelStandingLine(
        s,
        duelWith(const [
          DuelScore(userId: 'a', handle: 0, tapped: 3),
          DuelScore(userId: 'b', handle: 1, tapped: 3),
        ]),
      );
      expect(line, s.duelTied);
    });
  });

  group('time lines', () {
    final now = DateTime(2026, 7, 20, 12);

    Duel ending(Duration fromNow) => Duel(
          id: 'd',
          code: 'ABC234',
          kind: DuelKind.async,
          nameAdjective: 0,
          nameNoun: 0,
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(fromNow),
          status: DuelStatus.open,
        );

    testWidgets('picks the coarsest useful unit', (tester) async {
      final s = await strings();
      expect(duelTimeLine(s, ending(const Duration(days: 3)), now),
          s.duelTimeLeftDays(3));
      expect(duelTimeLine(s, ending(const Duration(hours: 5)), now),
          s.duelTimeLeftHours(5));
      expect(duelTimeLine(s, ending(const Duration(minutes: 90)), now),
          s.duelTimeLeftHours(1));
      expect(duelTimeLine(s, ending(const Duration(minutes: 2)), now),
          s.duelTimeLeftMinutes(2));
    });

    testWidgets('an ended duel says so', (tester) async {
      final s = await strings();
      expect(duelTimeLine(s, ending(const Duration(hours: -1)), now),
          s.duelOver);
    });
  });
}

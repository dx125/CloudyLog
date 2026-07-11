import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:puff/l10n/generated/app_localizations.dart';
import 'package:puff/presentation/screens/splash_screen.dart';
import 'package:puff/theme/puff_theme.dart';

void main() {
  // Keep font loading off the network so the splash renders synchronously with
  // a fallback face and leaves no pending fetches.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const homeKey = Key('home');

  Future<void> pumpGate(
    WidgetTester tester,
    Future<void> init, {
    Duration skipThreshold = const Duration(milliseconds: 300),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: puffTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashGate(
          initialization: init,
          skipThreshold: skipThreshold,
          child: const SizedBox(key: homeKey),
        ),
      ),
    );
    await tester.pump(); // let localizations resolve
  }

  testWidgets('shows the splash while initialization is pending', (
    tester,
  ) async {
    final completer = Completer<void>();
    await pumpGate(tester, completer.future);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('fast init cuts straight to home with no exit animation', (
    tester,
  ) async {
    // Real elapsed time in a test is far under the 300 ms threshold, so the
    // completed future takes the skip path.
    final completer = Completer<void>();
    await pumpGate(tester, completer.future);

    completer.complete();
    await tester.pump(); // run .then → _onReady
    await tester.pump(); // rebuild to the done phase

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(homeKey), findsOneWidget);
  });

  testWidgets('slow init plays the float-up exit, then reveals home', (
    tester,
  ) async {
    final completer = Completer<void>();
    // Threshold zero forces the exit-transition path deterministically.
    await pumpGate(tester, completer.future, skipThreshold: Duration.zero);

    completer.complete();
    await tester.pump(); // _onReady → exiting, controller.forward()
    await tester.pump(); // build the exiting stack

    // Home is cross-fading in beneath the still-present splash.
    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350)); // finish exit
    await tester.pump(); // whenComplete → done

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(homeKey), findsOneWidget);
  });

  testWidgets('a rejected initialization future still hands off to home', (
    tester,
  ) async {
    final completer = Completer<void>();
    await pumpGate(tester, completer.future);

    completer.completeError(Exception('init failed'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(homeKey), findsOneWidget);
  });
}

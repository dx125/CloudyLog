import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puff/l10n/generated/app_localizations.dart';
import 'package:puff/presentation/widgets/quick_tags_row.dart';
import 'package:puff/theme/puff_theme.dart';

/// Design A's contract, as seen from the UI: the microphone may *mark* a chip,
/// and that is the entirety of its authority. It never selects, never writes.
void main() {
  const tags = [
    TagOption(id: 'silent', label: 'Silent'),
    TagOption(id: 'squeaky', label: 'Squeaky'),
    TagOption(id: 'thunder', label: 'Thunder'),
    TagOption(id: 'sbd', label: 'SBD'),
  ];

  Widget host({
    String? suggested,
    Set<String> selected = const {},
    bool enabled = true,
    ValueChanged<String>? onToggle,
  }) =>
      MaterialApp(
        theme: puffTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickTagsRow(
            tags: tags,
            selected: selected,
            enabled: enabled,
            suggested: suggested,
            onToggle: onToggle ?? (_) {},
          ),
        ),
      );

  testWidgets('no suggestion means no mic marker', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });

  testWidgets('a suggestion marks exactly one chip', (tester) async {
    await tester.pumpWidget(host(suggested: 'thunder'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('the suggestion does not select the chip', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      host(suggested: 'thunder', onToggle: (_) => toggles++),
    );
    await tester.pumpAndSettle();

    expect(toggles, 0,
        reason: 'marking a chip must never stand in for the user tapping it');
  });

  testWidgets('tapping a suggested chip still goes through onToggle',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(suggested: 'thunder', onToggle: tapped.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thunder'));

    expect(tapped, ['thunder']);
  });

  testWidgets('an already-selected chip is not also marked', (tester) async {
    await tester.pumpWidget(
      host(suggested: 'thunder', selected: {'thunder'}),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing,
        reason: 'a suggestion on a chosen chip is noise');
  });

  testWidgets('no marker outside the quick-tag window', (tester) async {
    await tester.pumpWidget(host(suggested: 'thunder', enabled: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing,
        reason: 'there is nothing to tag once the window has closed');
  });

  testWidgets('an unknown suggestion marks nothing', (tester) async {
    await tester.pumpWidget(host(suggested: 'not-a-tag'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });
}

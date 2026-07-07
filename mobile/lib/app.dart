import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/duels_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/stats_screen.dart';
import 'presentation/screens/you_screen.dart';
import 'services/settings_service.dart';
import 'services/tap_service.dart';
import 'theme/puff_theme.dart';

class PuffApp extends StatelessWidget {
  const PuffApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: puffTheme(Brightness.light),
      darkTheme: puffTheme(Brightness.dark),
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _PuffShell(),
    );
  }
}

/// Bottom-nav shell: Home / Stats / Duels / You. IndexedStack keeps screens
/// alive so returning to Home never delays a tap.
class _PuffShell extends StatefulWidget {
  const _PuffShell();

  @override
  State<_PuffShell> createState() => _PuffShellState();
}

class _PuffShellState extends State<_PuffShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final puff = context.puff;
    final tap = context.watch<TapService>();

    if (!tap.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          StatsScreen(),
          DuelsScreen(),
          YouScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: puff.surface,
          border: Border(top: BorderSide(color: puff.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 6),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.cloud_outlined,
                  label: strings.navHome,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.insert_chart_outlined,
                  label: strings.navStats,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: strings.navDuels,
                  selected: _index == 2,
                  proDot: true,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: strings.navYou,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.proDot = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The rationed coral Pro marker (Duels only on this bar).
  final bool proDot;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final color = selected ? puff.action : puff.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PuffRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  if (proDot)
                    Positioned(
                      top: -6,
                      right: -20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: puff.pro,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.proChip,
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w800,
                            color: puff.onPro,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

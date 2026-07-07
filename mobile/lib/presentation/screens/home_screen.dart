import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/percentile.dart';
import '../../domain/puff_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/entitlement_service.dart';
import '../../services/settings_service.dart';
import '../../services/stats_service.dart';
import '../../services/tap_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/quick_tags_row.dart';
import '../widgets/tap_button.dart';
import '../widgets/week_chart.dart';

/// The home screen has one job: make logging instant and satisfying.
/// Count on top, giant button in the middle, one quick-tag row, one
/// glanceable week chart. Everything else lives behind the nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<StatsSnapshot> _statsFuture;
  TapService? _tapService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tap = context.read<TapService>();
    if (tap != _tapService) {
      _tapService?.removeListener(_reloadStats);
      _tapService = tap..addListener(_reloadStats);
      _statsFuture = context.read<StatsService>().snapshot();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapService?.removeListener(_reloadStats);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TapService>().refreshIfStale();
    }
  }

  void _reloadStats() {
    if (!mounted) return;
    setState(() {
      _statsFuture = context.read<StatsService>().snapshot();
    });
  }

  Future<void> _addCustomTag() async {
    final strings = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final settings = context.read<SettingsService>();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.addTagTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: InputDecoration(hintText: strings.addTagHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(strings.addButton),
          ),
        ],
      ),
    );
    if (added != null) await settings.addCustomTag(added);
    controller.dispose();
  }

  String _worldLine(AppLocalizations strings, int count) =>
      switch (worldPaceFor(count)) {
        WorldPace.quiet => strings.worldAvgQuiet,
        WorldPace.onPace => strings.worldAvgOnPace,
        WorldPace.breezy => strings.worldAvgBreezy,
      };

  String _tagLabel(AppLocalizations strings, String id) => switch (id) {
        'silent' => strings.tagSilent,
        'squeaky' => strings.tagSqueaky,
        'thunder' => strings.tagThunder,
        'sbd' => strings.tagSbd,
        'windy' => strings.tagWindy,
        'oops' => strings.tagOops,
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final tap = context.watch<TapService>();
    final settings = context.watch<SettingsService>();
    final isPro = context.watch<EntitlementService>().isPro;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    final tagOptions = [
      for (final id in kClassicTags)
        TagOption(id: id, label: _tagLabel(strings, id)),
      if (isPro) ...[
        for (final id in kProTags)
          TagOption(id: id, label: _tagLabel(strings, id)),
        for (final custom in settings.customTags)
          TagOption(id: custom, label: custom),
      ],
    ];

    return SafeArea(
      child: Column(
        children: [
          // App bar: wordmark left, streak pill right.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.appTitle,
                  style: theme.textTheme.headlineMedium!.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: puff.action,
                  ),
                ),
                FutureBuilder<StatsSnapshot>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    final streak = snapshot.data?.currentStreak ?? 0;
                    if (streak < 1) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: puff.streakBg,
                        borderRadius: BorderRadius.circular(PuffRadius.pill),
                      ),
                      child: Text(
                        strings.streakPill(streak),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: puff.streakFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat.MMMEd(localeTag).format(tap.today).toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          // The counter rolls on change.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '${tap.todayCount}',
              key: ValueKey(tap.todayCount),
              style: theme.textTheme.displayLarge,
            ),
          ),
          Text(
            strings.tootsToday,
            style: theme.textTheme.bodyMedium!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            _worldLine(strings, tap.todayCount),
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          TapButton(
            onLog: () => context.read<TapService>().tap(),
            playSound: settings.soundEnabled,
            semanticsLabel: strings.tapSemantics(tap.todayCount),
          ),
          const SizedBox(height: 10),
          Text(
            strings.tapHint,
            style: theme.textTheme.bodySmall!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: QuickTagsRow(
              tags: tagOptions,
              selected: tap.lastEventTags.toSet(),
              enabled: tap.canTagLastEvent,
              onToggle: (id) =>
                  context.read<TapService>().toggleTagOnLastEvent(id),
              onAddCustom: isPro ? _addCustomTag : null,
              addLabel: strings.addTagButton,
            ),
          ),
          const Spacer(),
          // Glanceable week chart.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
              decoration: BoxDecoration(
                color: puff.surface,
                borderRadius: BorderRadius.circular(PuffRadius.md),
                border: Border.all(color: puff.hairline),
              ),
              child: FutureBuilder<StatsSnapshot>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final week = snapshot.data?.weekCounts ??
                      List<int>.filled(7, 0);
                  final total = snapshot.data?.weekTotal ?? 0;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.thisWeek.toUpperCase(),
                            style: theme.textTheme.labelSmall!
                                .copyWith(fontSize: 11.5),
                          ),
                          Text(
                            strings.weekTotal(total).toUpperCase(),
                            style: theme.textTheme.labelSmall!.copyWith(
                              fontSize: 11.5,
                              color: puff.action,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      WeekChart(counts: week),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
